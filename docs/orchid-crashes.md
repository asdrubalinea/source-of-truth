# orchid crashes and power-offs (Oct–Nov 2026)

**Status 2026-11-12 23:50: first readable crash.** At 23:49:38, ~7 min into
Cyberpunk on the RM850x's own cord (case horizontal), it powered off; turned on
with the case button, the CPU logged reset reason **`0x00200a00`: "internal CPU
thermal limit was tripped"** (bit 9, THERMTRIP; normal off is `0x00200800`). So
the CPU itself cut power: not a PSU cut, not the cord or socket. Sensors 15 s
before were unremarkable (Tctl 86–87, CPU 60 W, GPU 180–500 W swings, junction
92, RAM 61.5, board 50), with no climb. A real THERMTRIP needs ~115 °C, so
either a hot spot Tctl doesn't show (weak cooler / poor mount), a faulty CPU
sensor, or a BIOS/AGESA or power-delivery glitch the CPU reads as over-temp.
Suspects now: **CPU + cooler mount**, BIOS, motherboard. Earlier history: RAM
corruption of early October fixed (fan-control); RM750e was thought behind the
frequent game deaths, now doubtful: the RM850x died after ~17 min of real
Cyberpunk, about the same rate (the 3 h survival was memtest, a steadier load); earlier power-offs had no readable reason.

## Hardware

| Part | Model | Notes |
|---|---|---|
| CPU | Ryzen 7 7800X3D | Tjmax 89 °C; sits at Tctl 89–90 under all-core load |
| Cooler | be quiet! Pure Rock Slim 3 | undersized; NH-D12L (145 mm) fits the 150 mm limit |
| Board | ASRock B650 Pro RS | BIOS 4.60 (flashed 11-02 from 3.16); Super I/O NCT6799 |
| RAM | 2×32 GB Corsair CMH64GX5M2B6000Z30 | EXPO 6000, no ECC; spd5118 sensors |
| GPU | Gigabyte RX 9070 XT (VBIOS 113-R907XTGOL) | **refurbished**, bought ~Oct 2026, 1-year warranty = refund only; power_cap 297 W, 0 mV |
| PSU | Corsair RM850x (RMx, CWT) since 2026-11-11 | own modular cables; old unit: RM750e (HEC), bought on Amazon.it, RMA not done |
| Case | Tempest Compact Shade RGB (ATX) | cheap; two motherboard standoffs broke and were removed |
| Storage | 2× NVMe (990 Pro, Crucial P5), ZFS on LUKS | scrubs clean, SMART clean |

Settings that stay: Curve Optimizer all 0 (`co` in `hosts/orchid/hardware.nix`),
GPU `voltage_offset = 0`, no undervolts ever. BIOS: EXPO on, Power Supply Idle
Control = Typical Current Idle (since 11-06), restore on AC power loss = on (the
PC was powered on from the PSU switch until 11-12).

History: before the move to the Canary Islands, in a different case, with the
same BIOS settings, orchid never crashed. The move, the new case and the
refurbished 9070 XT all arrived around late September.

## Timeline

### Phase 1: RAM corruption under the Strata LLM load (10-01 – 10-09), fixed

Crashes, a ZFS checksum error (10-07) and a slab GPF (10-09) during hours of
50 GB memory-bound load. Root cause found 10-09: **stressapptest gave 117
miscompares with the DIMMs at 72 °C**; the same 4 h test passed at 57 °C with
the fans at 100 %. The BIOS fan curve followed the CPU while the DIMMs cooked.
Fix: `hosts/orchid/system/fan-control.{nix,py}` drives every case fan from
max(DIMM curve 50→62 °C, CPU curve 65→88 °C), 35 % floor. Keep DIMMs < 60 °C.
Curve Optimizer and GPU undervolt were red herrings (both zeroed anyway).

### Phase 2: silent hangs (10-19 – 11-02), type mostly unknown

| When | Doing | Notes |
|---|---|---|
| 10-19 10:38 | idle | no kernel line, no MCE, empty pstore |
| 10-22 18:07 | macOS VM with xHCI passthrough + nix builds | same |
| 11-01 22:12 | win11 VM with the 9070 XT passed through | same |
| 11-02 01:28 | Cyberpunk on the host | GPU 63–418 W swings |
| 11-02 21:45 | nix build, GPU idle | **freeze, fans kept spinning**; first with hardlockup_panic=1, still no trace, no self-reboot → platform-level freeze |
| 11-02 23:42 | user pushing the EPS cable live | reset, reason "internal CPU shutdown event"; excluded |

Back then every recovery was a smart-plug AC cycle, so whether each one froze
or powered off was never seen.

### Phase 3: power-offs (11-04 onward)

Fans and LEDs stop, the screen goes black, and the PC stays off. The board's
underglow goes dark too, but it **also goes dark after a normal shutdown**
(corrected 11-12), so it says nothing about standby power. The 11-05 "the PSU
dies completely" conclusion leaned on the opposite belief. Readings are the max
over the 90 s before death, from Prometheus; temperatures in °C.

| When | PSU | Doing | Board (SYSTIN) | CPUTIN | Tctl | RAM | SSD | GPU hot | CPU W | GPU W |
|---|---|---|---|---|---|---|---|---|---|---|
| 11-04 22:04 | RM750e | Cyberpunk, ~21 min in | 52 | 55 | 87 | 56 | 61 | 95 | 57 | 319 |
| 11-04 23:40 | RM750e | Cyberpunk, ~57 min in | 51 | 55 | 86 | 56 | 60 | 94 | 56 | 417 |
| 11-05 01:27 | RM750e | Cyberpunk at the 231 W GPU cap | 46 | 50 | 90 | 54 | 57 | 76 | 65 | 299 |
| 11-06 21:56 | RM750e | nix build just starting, near idle | 38 | 42 | 58 | 47 | 47 | 45 | 27 | 19 |
| 11-06 23:46 | RM750e | nix build, 10 min of all-core | 36 | 42 | 91 | 50 | 52 | 43 | 81 | 25 |
| 11-12 05:34 | **RM850x** | stress-ng all-core, 14 min in (after 2 h RAM test) | 36 | 41 | 90 | 45 | 44 | 34 | 74 | 8 |

(11-02 01:28 fits the same shape: SYSTIN 53, GPU 399 W.) Room was 28–29 °C every
time. No kernel line, no MCE/AER, empty pstore, no reset reason (wiped by the
AC cycle), no Prometheus precursor at 15 s resolution (Vcore, NCT6799 rails,
temperatures all flat). After 11-12 05:34 the PC stayed off for 4 h, so it was
not a panic-and-reboot.

Heavy-load exposure, counting minutes with CPU > 45 W or GPU > 150 W:

| | GPU-heavy (games) | CPU-heavy only |
|---|---|---|
| RM750e, 11-01 – 11-11 | 4 deaths in 142 min (~1 per 35 min) | 2 deaths in ~180 min (~1 per 90 min) |
| RM850x, from 11-11 | 0 deaths in 180 min (11-12 crash test, CPU loaded too) | 1 death in 244 min |

At the RM750e's rate, 3 h of game-level load without a death would happen by
luck ~0.6 % of the time, so the RM750e was very likely behind the game deaths.
Caveat: memtest_vulkan is a steadier load than a game's 60–420 W swings, so a
few real Cyberpunk sessions are still the final check. What remains is a rarer
fault (1 death in ~7 heavy hours on the RM850x so far) that load doesn't
explain.

The RM750e's 57 h clean run (11-09 – 11-11) had zero heavy minutes, and so
proves nothing.

## What has been ruled out, and why

| Suspect | Verdict | Evidence |
|---|---|---|
| RAM heat corruption | fixed | stressapptest 2 h PASS on 11-12 at 62–63 °C; 4 h PASS at 57 °C on 10-10 |
| Curve Optimizer / GPU undervolt | no | both at 0 since 10-09; crashes continued |
| BIOS/AGESA | no | 3.16 → 4.60 on 11-02 didn't help |
| Smart plug | no | removed; crashes continued |
| House mains | unlikely | Tapo: 227–233 V, flat up to every crash; on 11-12 05:34 tempest's Wi-Fi and internet stayed up |
| Time of day, room temperature | no | room ~28 °C at all hours; the evening pattern is just when games and big builds happen |
| CPU temperature | no | 11-06 21:56 died at Tctl 58 |
| Heat inside the case | no | CPU-load deaths with the board at 36–38 °C; the 11-12 crash test held the board at 51 °C without dying |
| Amount of load | no | deaths from ~50 W to ~450 W system draw |
| Power cables / board connectors | unlikely | RM850x on its own new cables; board-side connectors showed no browning at the swap |
| Short via the case | unlikely | kicking it, plugging cables at the back and running it horizontally never crashed it; a short needs something that moves |
| RM750e | probably behind the game deaths | it died on light bursts too; confirm with game-level load on the RM850x |
| GPU | less likely for the CPU-load deaths | idle and cool at those; no amdgpu or PCIe error in any boot since 09-29; memtest_vulkan clean |

**Still open:** motherboard (internal fault or a board-initiated shutdown), the
power cord / wall socket, the GPU (a short at idle), the case.

**Not known yet: PSU cut or board shutdown.** Both clues that seemed to point
at the PSU were artifacts. The underglow is dark after any shutdown, and the "it
needs ~15 s without AC" was just how the PC was powered on without a button:
the old RM750e's capacitors kept standby alive, so a short switch-off didn't
register as an AC loss. A board-initiated shutdown (thermal trip, VRM fault,
PS_ON dropped) fits every power-off so far. Only the next one, recovered with
the power button, can settle it.

## Next crash: what to do

1. Press **only the case power button** (wired since 11-12). Don't touch the
   PSU switch. If nothing happens, wait ~10 s and press again before cycling the switch.
2. Read the reason: `journalctl -b -k | grep 'reset reason'`.

| Outcome | Meaning | Next step |
|---|---|---|
| Boots, with a reason | board or CPU shut it down | the reason names the part |
| Boots, no reason | board turned off without saying why | motherboard is the lead |
| Won't boot until the PSU switch is cycled | PSU cut out, standby lost | short or AC path: swap cord/socket, then run without the 9070 XT |

Known reset-reason values: `0x00200800` "ACPI power state transition" (normal
shutdown), `0x00080800` "software wrote 0x6 to reset control register 0xCF9"
(reboot), "internal CPU shutdown event" (11-02 live EPS touch).

Planned order of tests, one change at a time: game-level load on the RM850x
(same cord and socket) → the RM850x's own power cord in a different wall socket
→ the power-button result → without the 9070 XT on the iGPU, over several
nights → motherboard (warranty claim first).

Done so far: game-level load survived 3 h (11-12 morning). 11-12 ~15:00: switched
to the RM850x's own power cord (same wall socket), and the case now lies horizontal.
Since then, to 11-12 22:48: ~4.3 heavy hours (4 h stress-ng + ~16 min), GPU never
above 145 W, 0 crashes (21:00 and 21:03 restarts were clean shutdowns).
23:08–23:17: first Cyberpunk on the new cord, ~10 min, GPU peak 385 W, no crash.

## Investigating a crash

- Boots and how they ended: `journalctl --list-boots`; last lines of a boot:
  `journalctl -b -1 -n 40`.
- Prometheus keeps everything (retention 100y since `d2f1449`, data from
  10-05), scrape 15 s, at `localhost:9901`. Useful series:
  - CPU package power: `rate(node_rapl_package_joules_total[1m])`
  - GPU power: `node_hwmon_power_average_watt{chip="0000:02:00_0_0000:03:00_0"}`;
    GPU temps on the same chip: temp1 edge, temp2 junction, temp3 memory
  - board: `node_hwmon_temp_celsius{chip="platform_nct6775_656"}`, temp1
    SYSTIN, temp2 CPUTIN (temp9 AUXTIN5 reads a bogus 103); fans fan2/fan4/fan7
  - DIMMs: `node_hwmon_temp_celsius * on(chip) group_left node_hwmon_chip_names{chip_name="spd5118"}`
  - room: `govee_temperature_celsius`; wall power: `tapo_power_watts`, `tapo_voltage_volts` (until 11-05)
- Crash capture already armed (`hosts/orchid/system/boot.nix`):
  `kernel.hardlockup_panic=1`, `panic=10`, NMI watchdog, `efi_pstore`. None of
  them has ever fired, which points at power loss or a platform freeze, not the kernel.
- Alerts: `hosts/orchid/system/hw-alerts.nix` (RamHot > 60 °C, near-thermal-limit,
  NVMe SMART, ZFS errors), shown as desktop notifications.
- The amdgpu sensors answer EBUSY while the 9070 XT is runtime-suspended at idle.

## Tests and results

| When | Test | Result |
|---|---|---|
| 11-11 22:10 | 20 min all-core + 40 min idle→load steps (RM850x) | pass |
| 11-12 03:20 | overnight battery `~/overnight/overnight.sh` | RAM stressapptest 2 h **PASS**; died 14 min into the all-core phase (05:34) |
| 11-12 10:35 | `~/crashtest/crashtest.sh`: stress-ng 15 threads + memtest_vulkan on the 9070 XT, 3 h | **survived 3 h** (RM850x, same cord and socket): GPU avg 296 W (max 370), Tctl 89–90, RAM 58, board 51; stress-ng 15/15 passed; VRAM 225,000 rounds, 0 errors; no kernel errors |
| 11-12 15:06 | stress-ng all 16 threads at idle priority while working, 4 h (RM850x's own cord, same socket, case horizontal) | **survived 4 h**: 16/16 passed, no kernel errors |
| 11-13 22:44 | same all-core stress-ng, 25 min, after repasting + retightening the Pure Rock Slim 3 and turning its fan to blow toward the rear exhaust (it had been blowing at the RAM) | **passed**, no kernel errors. Tctl 88.3 at 79.9 W vs 90.2 at 73.1 W before (room 27.9 vs 28.4): ~0.76 vs 0.85 °C/W over room, ~11 % better. The repaste alone (6 min, old orientation) was noise: 90.3 at 76.0 W. Still pinned at the ~89 °C limit, so the cooler stays undersized |
| 11-13 23:14 | same stress-ng, 8 min, after setting BIOS Platform Thermal Throttle Limit = 80 °C | **passed**. Tctl holds 81.2 (max 81.5) at 72.2 W, vs 88.3 at 79.9 W without the limit: ~10 % less power for 7 °C less. Case fans 1660 vs 1980 rpm (fan-control's CPU line eases off below 88) |

Horizontal vs vertical, same all-core load and fan speeds (avg of 11-12
15:16–19:05 vs 11-11 23:59–00:21, room 28.3 vs 28.1): RAM 43.6 vs 50.6, SSD 40.7
vs 50.6, board 33.8 vs 36.0, socket 39.0 vs 42.0, Tctl 90.3 both (at limit,
72.5 vs 77.3 W).

Logs sit next to each script in `~/overnight/` and `~/crashtest/`. No GPU
stressor works without a desktop session except memtest_vulkan (`nixpkgs#memtest_vulkan`):
FurMark core-dumps on headless weston, clpeak finds no OpenCL ICD, vkmark barely
loads the card.

### Baseline for the two new top fans

The fans are a 120 mm intake over the RAM and a rear-top exhaust. Numbers from
before they were installed, room 28 °C:

| Load | RAM | Tctl | SSD | Fans (fan4) |
|---|---|---|---|---|
| stressapptest, 16 threads, 45 GB | 62–63 (avg 62) | 63 | 39 | ~1970 rpm |
| stress-ng all-core | 44–54 | 90 at 74 W, 4.58 GHz avg | 39 | ~1970 |
| crash test, CPU + GPU 290 W | 58 | 90 | 57–62 | ~1990 |

The crash test also held the board at 51 °C, GPU junction at 91 °C and GPU memory
at 90 °C. Rerun `~/overnight/overnight.sh` after installing the fans. fan-control
changes fan speed with temperature, so also compare 30 min of stressapptest with
the fans pinned at a fixed duty, before and after.

## If the motherboard has to go

1. **Warranty first.** Spain's legal guarantee is 3 years for goods bought since
   2022 (the seller repairs or replaces), plus ASRock's own warranty. Find the
   purchase date.
2. Requirements: AM5, DDR5, ATX, at least 2 M.2 slots, and fan control from
   Linux (`fan-control.py` drives the NCT PWM headers).

| Brand | Fan control from Linux |
|---|---|
| ASUS B650 / X670 | yes: in the 6.18 nct6775 ASUS-WMI board list |
| ASUS X870 / X870E | yes, but only in kernels newer than 6.18 (mainline has them); needs a newer kernel or a one-line kernel patch |
| ASUS B850 | no: not in the list, even in mainline |
| ASRock | yes: NCT6799 probed directly |
| Gigabyte | no: ITE chip needs the out-of-tree it87 driver |
| MSI | no: NCT6687, readable but no PWM control in mainline |

Picks:
- Sensible replacement: ASUS **TUF GAMING B650-PLUS WIFI**, or the ROG STRIX
  B650-A GAMING WIFI as a step up.
- Future-proof: ASUS **TUF GAMING X870-PLUS WIFI**, which adds USB4, Wi-Fi 7 and
  PCIe 5.0. ROG STRIX X870-A GAMING WIFI is the step up; ProArt X870E-CREATOR
  WIFI only if 10 GbE and many M.2 slots would be used.
- Why not ASRock again: in 2025 there were many reports of X3D CPUs dying in
  ASRock AM5 boards, with BIOS fixes released. Not proof against this board.

Any board works with future AM5 CPUs after a BIOS update; X870 adds features,
not speed. After a swap, `fan-control.py`'s header mapping needs updating.

## Other references

- PSU shortlist page from 11-05: https://claude.ai/artifact/WijCN5f7GitSNujT6otXiM
- Strata LLM trial (the phase 1 workload): `docs/strata-trial.md`, `/persist/strata/JOURNAL.md`

## Case + cooler upgrade shortlist (Black Friday 2026, PcComponentes, prices 11-13)

Constraints: ATX board, 44 mm RAM, 288 mm GPU, 160 mm PSU, six Arctic P12 Pro PST to reuse
(front 3 / top 2 / rear 1), compact (≤ ~45 L), calima dust.

| Combo | Case | Cooler | Price now | BF target |
|---|---|---|---|---|
| Best overall | Fractal Meshify 2 Compact Black Solid (39 L, 169 mm, filters front/top/bottom) | Noctua NH-U12A (158 mm, no RAM overhang) | 132 + 123 € | ≤ 115 + ≤ 105 € |
| Best looking | Fractal North TG (glass side; mesh side + bracket limits cooler to 145 mm; top unfiltered) | be quiet! Dark Rock 5 (161 mm) | 136 + 69 € | ≤ 125 + ≤ 60 € |
| Value | Fractal Pop 2 Air Black TG (44 L, 170 mm) | Arctic Freezer 36 (159 mm, RAM clearance tight) | 91 + 25–29 € | ≤ 80 + ≤ 25 € |

Thermalright, Jonsbo, Lian Li are marketplace-only at PcComponentes (overpriced, may not ship
to Canarias). AIO gains only ~2–5 °C on a 7800X3D; top air preferred.

**Picked 11-14, for Zen 6 headroom** (both sold by PcComponentes, read 11-14):
- Fractal North TG Charcoal Black, refurbished "como nuevo", 119 €, 3-year warranty:
  https://www.pccomponentes.com/torre-pc-fractal-design-north-tg-atx-mid-tower-cristal-templado-usb-3-2-charcoal-black?refurbished=like-new
- Arctic Liquid Freezer III Pro 360 (black, VRM fan), 84.99 €, 6-year warranty, AM5, radiator 38 mm
  (front mount → GPU limit 355 − 38 = 317 mm ≥ 288): https://www.pccomponentes.com/refrigeracion-liquida-arctic-liquid-freezer-iii-pro-360mm-3-ventiladores-vrm-integrado
- Big air ruled out: NH-D15 G2 needs its front fan raised for 44 mm RAM → ~180 mm > the North's 170 mm.
