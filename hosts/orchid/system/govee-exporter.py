#!/usr/bin/env python3
"""Publish Govee H5075 thermometer readings as Prometheus text for the node-exporter textfile collector.

The H5075 broadcasts its reading every ~2 s in a BLE advertisement, unpaired and unencrypted:
manufacturer data under company ID 0xEC88, six bytes laid out as

    00 | tt tt tt | bb | 00

where tttttt is one big-endian 24-bit number holding both readings (temperature in
0.1 °C times 1000, plus humidity in 0.1 % in the last three decimal digits; bit 23 is the
sign) and bb is the battery percentage. Decoding follows Bluetooth-Devices/govee-ble.

Scanning is passive (a BlueZ AdvertisementMonitor; needs bluetoothd's experimental
interfaces, which hardware/bluetooth.nix enables): orchid never sends scan requests, so
the radio it shares with headphones and controllers is only listening. Every H5075 in
range is published, labelled by MAC and its advertised name (GVH5075_XXXX, the last four
hex digits of the MAC); no pairing or configuration.

A device that has not been heard for --stale seconds drops out of the file, so its
readings go stale in Prometheus instead of flat-lining at the last value;
govee_last_seen_timestamp_seconds stays for every device heard since the exporter started.
"""

import argparse
import asyncio
import math
import os
import sys
import tempfile
import time

from bleak import BleakScanner
from bleak.args.bluez import BlueZScannerArgs, OrPattern
from bleak.assigned_numbers import AdvertisementDataType

GOVEE = 0xEC88


def esc(s):
    return str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def decode(data):
    """(temperature °C, humidity %, battery %) from the 0xEC88 payload, or None."""
    if len(data) != 6:
        return None
    raw = int.from_bytes(data[1:4], "big")
    value = raw & 0x7FFFFF
    temp = int(value / 1000) / 10.0
    if raw & 0x800000:
        temp = -temp
    humid = (value % 1000) / 10.0
    if humid > 100:  # the sensor's error frame
        return None
    return temp, humid, data[4]


def dew_point(t, rh):
    """Magnus formula (Sonntag 1990 constants), good to ~0.1 °C from -45 to 60 °C."""
    if rh <= 0:
        return None
    a, b = (17.62, 243.12) if t >= 0 else (22.46, 272.62)
    g = math.log(rh / 100) + a * t / (b + t)
    return b * g / (a - g)


def absolute_humidity(t, rh):
    """Water vapour density in g/m³ from the Magnus saturation pressure."""
    es = 6.112 * math.exp(17.62 * t / (243.12 + t))  # hPa
    return 216.7 * (rh / 100 * es) / (273.15 + t)


SERIES = [
    ("govee_temperature_celsius", "Air temperature"),
    ("govee_humidity_percent", "Relative humidity"),
    ("govee_dew_point_celsius", "Dew point, derived from temperature and humidity"),
    ("govee_absolute_humidity_grams_per_cubic_meter", "Water vapour density, derived from temperature and humidity"),
    ("govee_battery_percent", "Battery level, as the thermometer reports it"),
    ("govee_rssi_dbm", "Signal strength of the last advertisement heard"),
    ("govee_last_seen_timestamp_seconds", "Unix time the last advertisement was heard"),
]


def render(devices, stale):
    now = time.time()
    rows = {name: [] for name, _ in SERIES}
    for mac, d in sorted(devices.items()):
        lab = f'{{mac="{esc(mac)}",name="{esc(d["name"])}"}}'
        rows["govee_last_seen_timestamp_seconds"].append(f"{lab} {d['seen']:.0f}")
        if now - d["seen"] > stale:
            continue
        t, rh = d["temp"], d["humid"]
        for name, v in [
            ("govee_temperature_celsius", t),
            ("govee_humidity_percent", rh),
            ("govee_dew_point_celsius", dew_point(t, rh)),
            ("govee_absolute_humidity_grams_per_cubic_meter", absolute_humidity(t, rh)),
            ("govee_battery_percent", d["battery"]),
            ("govee_rssi_dbm", d["rssi"]),
        ]:
            if v is not None:
                rows[name].append(f"{lab} {float(v):g}")
    out = []
    for name, help_ in SERIES:
        if rows[name]:
            out += [f"# HELP {name} {help_}", f"# TYPE {name} gauge"]
            out += [name + r for r in rows[name]]
    return "\n".join(out) + "\n"


def write_atomic(path, text):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(prefix=".govee.prom.", dir=d)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, 0o644)  # mkstemp makes 0600; node-exporter runs as another user
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


async def run(a):
    devices = {}

    def seen(dev, adv):
        data = adv.manufacturer_data.get(GOVEE)
        r = decode(data) if data is not None else None
        if r is None:
            return
        if dev.address not in devices:
            print(f"heard {adv.local_name or dev.name or '?'} ({dev.address})", file=sys.stderr, flush=True)
        prev = devices.get(dev.address, {})
        devices[dev.address] = {
            "name": adv.local_name or dev.name or prev.get("name") or "",
            "temp": r[0],
            "humid": r[1],
            "battery": r[2],
            "rssi": adv.rssi,
            "seen": time.time(),
        }

    # BlueZ matches the pattern against the raw AD structure, where the company
    # ID is the first two bytes, little-endian.
    pattern = OrPattern(0, AdvertisementDataType.MANUFACTURER_SPECIFIC_DATA, GOVEE.to_bytes(2, "little"))
    path = os.path.join(a.dir, "govee.prom")
    async with BleakScanner(seen, scanning_mode="passive", bluez=BlueZScannerArgs(or_patterns=[pattern])):
        print("listening for Govee advertisements (passive)", file=sys.stderr, flush=True)
        deadline = time.monotonic() + a.once if a.once else None
        while True:
            await asyncio.sleep(a.interval)
            try:
                write_atomic(path, render(devices, a.stale))
            except OSError as e:
                print(f"cannot write {path}: {e}", file=sys.stderr, flush=True)
            if deadline is not None and time.monotonic() >= deadline:
                sys.stdout.write(render(devices, a.stale))
                return 0 if devices else 1


def main():
    ap = argparse.ArgumentParser(description="Publish Govee H5075 readings for the node-exporter textfile collector")
    ap.add_argument("--dir", default="/var/lib/node-exporter-textfile")
    ap.add_argument("--interval", type=float, default=10.0, help="seconds between rewrites of govee.prom")
    ap.add_argument("--stale", type=float, default=600.0, help="drop a device's readings after this many silent seconds")
    ap.add_argument("--once", type=float, metavar="SECONDS", help="listen this long, print the file to stdout and exit (for testing)")
    return asyncio.run(run(ap.parse_args()))


if __name__ == "__main__":
    sys.exit(main())
