#!/usr/bin/env python3
"""Publish a Tapo P110's power reading as Prometheus text for the node-exporter textfile collector.

The P110 speaks KLAP (login v2) on port 80 and wants the Tapo cloud account's email and
password, checked locally on the plug. python-kasa does the handshake; this loop polls
the plug every few seconds and rewrites <dir>/tapo.prom atomically, so the series ride
the existing `node` scrape like strata.prom and inotify.prom do.

The credentials file holds two lines: the account email, then the password.

`tapo_up` is 0 while the plug does not answer or refuses the login, and every other
series is dropped from the file so Prometheus marks it stale. The plug's own
today/month counters are kept as gauges: they reset at local midnight and on the 1st,
which Prometheus counters can't express, so integrate tapo_power_watts for other ranges.
"""

import argparse
import asyncio
import os
import sys
import tempfile

from kasa import (
    AuthenticationError,
    Credentials,
    Device,
    DeviceConfig,
    KasaException,
    Module,
)
from kasa.deviceconfig import DeviceConnectionParameters, DeviceEncryptionType, DeviceFamily


def esc(s):
    return str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


class Out:
    def __init__(self):
        self.lines = []

    def gauge(self, name, value, labels=None, help_=None):
        if value is None:
            return
        if isinstance(value, bool):
            value = int(value)
        if help_:
            self.lines.append(f"# HELP {name} {help_}")
        self.lines.append(f"# TYPE {name} gauge")
        lab = ""
        if labels:
            lab = "{" + ",".join(f'{k}="{esc(v)}"' for k, v in labels.items()) + "}"
        self.lines.append(f"{name}{lab} {float(value):g}")

    def text(self):
        return "\n".join(self.lines) + "\n"


def render(dev):
    o = Out()
    o.gauge("tapo_up", 1, help_="1 while the plug answers and accepts the login")
    o.gauge("tapo_info", 1, {"alias": dev.alias or "", "model": dev.model, "mac": dev.mac},
            "Plug name (as set in the Tapo app), model and MAC")
    o.gauge("tapo_relay_on", dev.is_on, help_="1 while the plug's relay is closed")
    o.gauge("tapo_wifi_rssi_dbm", dev.rssi)

    e = dev.modules.get(Module.Energy)
    if e is not None:
        o.gauge("tapo_power_watts", e.current_consumption, help_="Power drawn through the plug")
        today = e.consumption_today
        o.gauge("tapo_energy_today_kwh", today, help_="Energy since local midnight, per the plug")
        month = e.consumption_this_month
        o.gauge("tapo_energy_month_kwh", month, help_="Energy since the 1st, per the plug")
        o.gauge("tapo_voltage_volts", e.voltage)
        o.gauge("tapo_current_amperes", e.current)
    return o.text()


def write_atomic(path, text):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(prefix=".tapo.prom.", dir=d)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.chmod(tmp, 0o644)  # mkstemp makes 0600; node-exporter runs as another user
        os.replace(tmp, path)
    except BaseException:
        os.unlink(tmp)
        raise


async def run(a):
    with open(a.credentials) as f:
        user, password = (f.read().splitlines() + ["", ""])[:2]
    config = DeviceConfig(
        host=a.host,
        credentials=Credentials(user.strip(), password),
        connection_type=DeviceConnectionParameters(
            DeviceFamily.SmartTapoPlug, DeviceEncryptionType.Klap, login_version=2
        ),
        timeout=5,
    )
    path = os.path.join(a.dir, "tapo.prom")
    dev = None
    was_up = None
    while True:
        delay = a.interval
        try:
            if dev is None:
                dev = await Device.connect(config=config)  # handshakes and does the first update
            else:
                await dev.update(update_children=False)
            text = render(dev)
            up = True
        except (KasaException, OSError, asyncio.TimeoutError) as e:
            text = "# TYPE tapo_up gauge\ntapo_up 0\n"
            up = False
            if was_up is not False:
                print(f"plug {a.host} not answering: {type(e).__name__}: {e}", file=sys.stderr, flush=True)
            if isinstance(e, AuthenticationError):
                delay = 60  # a wrong password won't fix itself; don't hammer the plug
            if dev is not None:
                try:
                    await dev.disconnect()
                except Exception:
                    pass
                dev = None  # start over with a fresh KLAP session
        if up and was_up is not True:
            print(f"plug {a.host} up: {dev.alias} ({dev.model})", file=sys.stderr, flush=True)
        was_up = up
        try:
            write_atomic(path, text)
        except OSError as e:
            print(f"cannot write {path}: {e}", file=sys.stderr, flush=True)
        if a.once:
            if dev is not None:
                await dev.disconnect()
            return 0 if up else 1
        await asyncio.sleep(delay)


def main():
    ap = argparse.ArgumentParser(description="Publish a Tapo P110's power for the node-exporter textfile collector")
    ap.add_argument("--host", required=True)
    ap.add_argument("--credentials", required=True, help="file: account email, newline, password")
    ap.add_argument("--dir", default="/var/lib/node-exporter-textfile")
    ap.add_argument("--interval", type=float, default=5.0)
    ap.add_argument("--once", action="store_true", help="write one file and exit (for testing)")
    return asyncio.run(run(ap.parse_args()))


if __name__ == "__main__":
    sys.exit(main())
