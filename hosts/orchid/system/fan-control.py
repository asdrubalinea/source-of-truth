#!/usr/bin/env python3
"""Drive orchid's case fans from the DIMM temperature.

The BIOS fan curves follow the CPU, and a memory-bound load (Strata streaming experts, a
memory test) leaves the CPU tepid while the DDR5 modules cook: 2026-10-09, DIMMs at 72 C
with the fans at 700-1000 rpm, stressapptest failing from minute 33, the same kit clean for
four hours at 55 C with the fans at 2000 rpm. The Nuvoton NCT6799 behind the fan headers
cannot see the DIMMs; Linux can, through the spd5118 sensors on the modules.

Every few seconds: read the hottest DIMM and the CPU Tctl, map each to a duty through its
own line, take the higher duty, write it to every PWM header in manual mode. On exit put the
headers back to the BIOS's automatic mode (pwm_enable=5), so a stopped service never leaves
the fans parked. The hwmon paths are found by chip name, not hwmon number, since those move.
"""

import argparse
import glob
import signal
import sys
import time


def hwmon_by_name(name):
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        try:
            if open(h + "/name").read().strip() == name:
                yield h
        except OSError:
            pass


def read_milli(path):
    try:
        return int(open(path).read()) / 1000
    except (OSError, ValueError):
        return None


def duty(temp, low, high, floor):
    """Linear from `floor` at `low` C to 100 % at `high` C."""
    if temp is None:
        return floor
    if temp <= low:
        return floor
    if temp >= high:
        return 100
    return floor + (100 - floor) * (temp - low) / (high - low)


def main():
    ap = argparse.ArgumentParser(description="Drive the case fans from the DIMM temperature")
    ap.add_argument("--chip", default="nct6799", help="hwmon name of the fan controller")
    ap.add_argument("--floor", type=int, default=35, help="minimum duty, percent")
    ap.add_argument("--dimm-low", type=float, default=50)
    ap.add_argument("--dimm-high", type=float, default=62)
    ap.add_argument("--cpu-low", type=float, default=65)
    ap.add_argument("--cpu-high", type=float, default=88)
    ap.add_argument("--interval", type=float, default=5)
    ap.add_argument("--once", action="store_true", help="print the decision and exit")
    a = ap.parse_args()

    chips = list(hwmon_by_name(a.chip))
    if not chips:
        print(f"no hwmon named {a.chip}; is nct6775 loaded?", file=sys.stderr)
        return 1
    pwms = sorted(p for c in chips for p in glob.glob(c + "/pwm[0-9]"))
    k10 = list(hwmon_by_name("k10temp"))

    def restore(*_):
        for p in pwms:
            try:
                open(p + "_enable", "w").write("5")
            except OSError:
                pass
        print("fans back to BIOS auto", file=sys.stderr, flush=True)
        sys.exit(0)

    if not a.once:
        signal.signal(signal.SIGTERM, restore)
        signal.signal(signal.SIGINT, restore)
        for p in pwms:
            open(p + "_enable", "w").write("1")

    last = None
    while True:
        dimm = max((read_milli(h + "/temp1_input") for h in hwmon_by_name("spd5118")),
                   default=None, key=lambda t: t or -1)
        cpu = max((read_milli(h + "/temp1_input") for h in k10), default=None, key=lambda t: t or -1)
        d = max(duty(dimm, a.dimm_low, a.dimm_high, a.floor), duty(cpu, a.cpu_low, a.cpu_high, a.floor))
        val = round(255 * d / 100)
        if a.once:
            print(f"dimm {dimm} C, cpu {cpu} C -> {d:.0f} % (pwm {val}) on {len(pwms)} headers")
            return 0
        if val != last:
            for p in pwms:
                try:
                    open(p, "w").write(str(val))
                except OSError as e:
                    print(f"{p}: {e}", file=sys.stderr, flush=True)
            last = val
        time.sleep(a.interval)


if __name__ == "__main__":
    sys.exit(main())
