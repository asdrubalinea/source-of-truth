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
| 11-20 13:11 | `~/fantest/fantest.sh before`: 65 min of CPU, RAM, CPU + GPU, and CPU + GPU with the case fans held at 70 %, the baseline before the two new top fans | **passed**: stress-ng 0 failed, stressapptest PASS, memtest_vulkan PASS, no kernel errors. Numbers under *Baseline for the two new top fans* |
| 11-20 20:27 | `~/fantest/fantest.sh after`: the same test with the two new top fans in | **passed**, no errors. Under CPU + GPU load: CPU throughput +5.6 % (fan-control) and +13.6 % (fans at 70 %), RAM 9–10 °C cooler. No change under CPU-only load |
| 11-21 06:54 | `~/gputest/gputest.sh 3`: memtest_vulkan on the 9070 XT alone, 3 h, logging the hotspot delta | **passed**, 0 VRAM errors, no kernel errors. Delta 27.4 °C at 293 W, steady for 3 h; junction 95 (max 100), VRAM 92. See *GPU hotspot delta* |

Horizontal vs vertical, same all-core load and fan speeds (avg of 11-12
15:16–19:05 vs 11-11 23:59–00:21, room 28.3 vs 28.1): RAM 43.6 vs 50.6, SSD 40.7
vs 50.6, board 33.8 vs 36.0, socket 39.0 vs 42.0, Tctl 90.3 both (at limit,
72.5 vs 77.3 W).

Logs sit next to each script in `~/overnight/`, `~/crashtest/` and `~/fantest/`. No GPU
stressor works without a desktop session except memtest_vulkan (`nixpkgs#memtest_vulkan`):
FurMark core-dumps on headless weston, clpeak finds no OpenCL ICD, vkmark barely
loads the card.

### Baseline for the two new top fans

The fans are a 120 mm intake over the RAM and a rear-top exhaust.

**The test.** Run `~/fantest/fantest.sh before`, then the same with `after` once the
fans are in, then compare with
`~/fantest/summarize.sh ~/fantest/before.csv ~/fantest/after.csv`. It takes 65 min, in
five steps, with fan-control driving the fans in all but the last:

| Step | Load |
|---|---|
| idle | 5 min, nothing added (the desktop was in use) |
| cpu | 15 min, `stress-ng --cpu 16 --cpu-method matrixprod` |
| ram | 15 min, stressapptest, 16 GB, 16 threads |
| full | 15 min, stress-ng 15 threads + memtest_vulkan on the 9070 XT (~290 W) |
| pinned | 15 min, same as full, with fan-control stopped and every case fan held at 70 % (restarted at the end, even after a guard or Ctrl-C) |

Every 10 s it writes one CSV row: room temperature (Govee sensor via Prometheus),
Tctl, the hottest DIMM, the hottest NVMe, SYSTIN (board), CPUTIN, GPU edge, junction
and memory temperature and power, CPU package power (RAPL), average MHz, and every
fan header's rpm. The summary averages the last 6 min of each step, when the
temperatures have settled. It stops early at Tctl 86, DIMM 66, NVMe 78, GPU
junction 105 or VRAM 103 °C.

**How to read it.** The BIOS limit holds Tctl at ~81 °C under any load, so better
cooling will not lower Tctl. It shows instead as more CPU watts and MHz at that
limit, and in the fan-control steps as lower rpm too. The pinned step is the direct
airflow comparison, since fan-control can't hide the difference there. Compare runs
at a similar room temperature and with at least 16 GB of RAM free.

**Before**, 2026-11-20 13:11–14:17, room 27.3–28.0 °C:

| Step | Tctl | CPU W / GHz | DIMM | NVMe | Board | CPUTIN | GPU junction | GPU W | Case fans (fan4) |
|---|---|---|---|---|---|---|---|---|---|
| idle | 54 | 31 / 4.12 | 44 | 42 | 37 | 40 | 50 | 27 | 905 rpm |
| cpu | 81 | 75 / 4.64 | 41 | 38 | 34 | 39 | 42 | 23 | 1648 |
| ram | 63 | 65 / 4.59 | 59 | 40 | 35 | 39 | 44 | 27 | 1700 |
| full | 81 | 61 / 4.15 | 53 | 56 | 51 | 55 | 93 | 293 | 1628 |
| pinned (70 %) | 81 | 55 / 3.85 | 56 | 59 | 53 | 57 | 94 | 296 | 1488 |

GPU memory was 87 °C in full and 90 in pinned. The main finding: the GPU's heat in
the case costs the CPU 14–20 W at the same 81 °C (75 W alone, against 61 W in full
and 55 W in pinned). That gap is what the new fans should close. CPU throughput
(stress-ng bogo-ops/s, printed by `summarize.sh`): cpu 11,637 (16 threads), full
10,688 and pinned 9,706 (15 threads each), so the same load ran 9 % slower with the
fans at 70 % than under fan-control.

What to expect: the cooler moves ~1.4 W per °C between Tctl and the air it breathes
((81 − 27.4) / 75 W ≈ 0.71 °C/W in the cpu step). Solving for that air in the full
step gives 81 − 61 × 0.71 ≈ 38 °C, about 10 °C over the room. So each 1 °C the new
fans take off that air should give the CPU ~1.4 W more. CPU-only work should gain
little, since the air is already near room temperature there. Gaming-type load
(CPU + GPU) is where a gain should show. The pinned step can't be used for this
estimate, because the CPU cooler's own fan is held at 70 % there too. Under CPU-only load
the RAM, SSD and board run cooler than at idle, because fan-control spins the fans up.

The RAPL energy counter wraps every ~18 min at load (65.5 kJ). The before run gave
one bogus negative reading per step, so those 4 rows were corrected by adding the
range back (the uncorrected file is `~/fantest/before.raw.csv`). The script now does
this itself.

**After**, both fans in, 2026-11-20 20:27–21:33, room 27.2–27.9 °C. All passed again
(stress-ng 0 failed, stressapptest PASS, memtest_vulkan PASS, no kernel errors). Only
one new tach shows (fan1, ~1650 rpm at load); the second fan is daisy-chained or on a
splitter.

| Step | Tctl | CPU W / GHz | DIMM | NVMe | Board | CPUTIN | GPU junction | GPU W | Case fans (fan4) |
|---|---|---|---|---|---|---|---|---|---|
| idle | 51 | 26 / 3.91 | 37 | 36 | 34 | 35 | 34 | 13 | 909 rpm |
| cpu | 81 | 75 / 4.67 | 37 | 36 | 34 | 38 | 36 | 21 | 1661 |
| ram | 62 | 61 / 4.55 | 55 | 38 | 36 | 39 | 38 | 15 | 1335 |
| full | 81 | 65 / 4.35 | 44 | 54 | 49 | 51 | 91 | 289 | 1635 |
| pinned (70 %) | 81 | 63 / 4.26 | 46 | 57 | 51 | 53 | 93 | 294 | 1492 |

CPU throughput, before → after: cpu 11,637 → 11,812 (+1.5 %, noise), full 10,688 →
11,284 (**+5.6 %**), pinned 9,706 → 11,027 (**+13.6 %**). GPU memory 85 °C in full and
89 in pinned (was 87 and 90).

What changed:
- CPU + GPU, at the same fan speeds: the CPU gets +4 W / +0.2 GHz under fan-control and
  +8 W / +0.4 GHz with the fans at 70 %. By the ~1.4 W per °C estimate above, that is
  ~3 and ~6 °C cooler air reaching the CPU cooler. With the fans at 70 % the CPU now
  loses only 12 W to the GPU's heat, against 20 W before.
- RAM: 9–10 °C cooler under CPU + GPU (53 → 44, 56 → 46). In the RAM step it ran 4 °C
  cooler (59 → 55) with the fans ~20 % slower (1700 → 1335 rpm), since fan-control
  follows the DIMM temperature.
- Board, CPUTIN, SSD and GPU: 2–4 °C cooler under CPU + GPU.
- GPU performance: no change. memtest_vulkan wrote 526.7 → 526.3 GB/s (full) and 523.9 →
  524.4 (pinned), and the core clock (Prometheus `node_hwmon_freq_freq_mhz`, sclk, last
  6 min) was 3211 → 3149 MHz (full) and 3228 → 3223 (pinned), memory clock 1258 throughout.
  The card runs into its 297 W power cap, not a temperature limit (junction 91–94 against
  110), so cooler air doesn't buy it clocks; the CPU gains because its limit is a temperature.
- CPU-only load: no change, as expected (the case air was already near room temperature).
- Idle is not comparable: the after run started 2 min after a cold boot.

Older numbers from 11-12, before the repaste, the cooler-fan turn and the 80 °C limit
(not comparable with the above; room 28 °C):

| Load | RAM | Tctl | SSD | Fans (fan4) |
|---|---|---|---|---|
| stressapptest, 16 threads, 45 GB | 62–63 (avg 62) | 63 | 39 | ~1970 rpm |
| stress-ng all-core | 44–54 | 90 at 74 W, 4.58 GHz avg | 39 | ~1970 |
| crash test, CPU + GPU 290 W | 58 | 90 | 57–62 | ~1990 |

The crash test also held the board at 51 °C, GPU junction at 91 °C and GPU memory
at 90 °C.

## Long-term temperatures (Prometheus, 10-05 – 11-21)

The room stayed at 27–28 °C the whole time (the Govee sensor logs from 10-21), so these
trends come from the machine, not the weather. Everything has got cooler over the
seven weeks, and nothing is creeping up, so there is no sign of drying paste, a failing
fan or dust build-up.

| Daily figure | Early Oct | Late Oct | Mid Nov (11-15 – 11-19) | Limit |
|---|---|---|---|---|
| Tctl avg / max | 63–66 / 86–88 | 58–61 / 85–88 | 51–55 / 80–83 | 89 (Tjmax); BIOS holds 80 |
| DIMM avg / max | 49–52 / 55–73 | 46–47 / 50–54 | 42–43 / 44–56 | errors at 72 under load (10-09) |
| NVMe avg / max | 55–59 / 59–66 | 42–43 / 46–57 | 39–41 / 43–61 | 990 PRO warns at 81, P5 Plus at 79 |
| Board (SYSTIN) avg | 39–40 (from 10-10) | 36–37 | 34–36 | — |
| GPU junction max | 91–104 (Strata) | 89–95 (games) | 89–93 (games) | 110 |

Where the steps come from:
- DIMM: fan-control (10-10) ended the peaks above 60. Since then only stress tests pass 56.
- NVMe: 55 → 43 °C average between 10-21 and 10-23, when the ASPM powersave commit
  (fc2ea89) went live on 10-22. Most likely the drives now drop into low-power idle.
- Tctl: daily peaks of 86–91 until 11-13, and 80–83 since the BIOS 80 °C limit. At the
  same light use (2–5 % busy), the daily average fell from 60–64 in mid-October to
  51–55 in mid-November. That came first with EPP powersave (10-22), then the repaste
  and cooler-fan turn (11-13).

Idle nights (01–06 h, ~2 % busy), the same hours before and after the two top fans:

| Night | Room | Tctl | DIMM | NVMe | Board | CPUTIN | GPU junction | Fans (fan4) | CPU W |
|---|---|---|---|---|---|---|---|---|---|
| 11-17 | 27.5 | 50.7 | 41.4 | 38.2 | 34.0 | 36.3 | 35.6 | 905 | 25.7 |
| 11-18 | 27.1 | 49.8 | 41.3 | 38.9 | 33.9 | 36.2 | 33.7 | 915 | 25.4 |
| 11-19 | 27.4 | 49.4 | 41.6 | 38.7 | 34.1 | 36.9 | 35.8 | 906 | 26.2 |
| 11-20 | 27.7 | 52.5 | 41.2 | 37.6 | 33.8 | 36.1 | 32.5 | 946 | 26.9 |
| **11-21, fans in** | 27.7 | 52.1 | **38.8** | 38.1 | **36.0** | 36.4 | 33.4 | 946 | 27.0 |

At idle the new fans take ~2.5 °C off the RAM and leave the rest the same, except the
board sensor (SYSTIN), which reads ~2 °C warmer. That is one night only, and it may come
from where the new airflow passes the sensor. Under load the board ran 2 °C cooler (see
the fan test above).

### GPU hotspot delta (11-21)

The hotspot delta is the junction (hottest point on the die) minus the edge sensor. A
delta that is high for the power, or that grows over weeks, points at the cooler's
contact (paste pump-out, pads, mount), which matters on a refurbished card.

**Soak, 2026-11-21 06:54–09:54**: `~/gputest/gputest.sh 3`, memtest_vulkan on the 9070 XT
alone for 3 h, both top fans in, room 26.9–28.2 °C. Logs in `~/gputest/` (`gputest.csv`
every 10 s, `summary.txt` in 15-min blocks). **Passed**: memtest_vulkan found no VRAM
errors, and there were no kernel errors.

| After warm-up (min 15–180) | Average | Range |
|---|---|---|
| GPU power | 293 W (297 W cap) | 225–374 W per 10 s sample |
| Edge | 68 °C | flat at 68 (the card's fan curve holds it there) |
| Junction (hotspot) | 95.4 °C | max 100, against a 110 limit |
| **Delta** | **27.4 °C** | 20–32. The 15-min block averages stay at 27.0–27.8 for the whole 3 h |
| VRAM | 92.2 °C | max 94 |
| Core / memory clock | 3205 / 1258 MHz | |
| GPU fans | ~2380 rpm | |

The delta held steady for the whole run and barely moves with power: the 10 s samples
binned by power give 26.8–28.3 °C from 225 to 374 W.

**History**, daily delta while the card drew > 250 W (`python3 -I ~/gputest/delta_history.py
<from> <to>`, Prometheus):

| Day | Minutes > 250 W | Delta avg / max | Junction avg | Load |
|---|---|---|---|---|
| 10-07 | 30 | 26.2 / 35 | 93.3 | Strata |
| 10-09 | 102 | 25.2 / 35 | 91.7 | Strata |
| 10-10 | 103 | 26.3 / 40 | 85.4 | Strata |
| 10-17 – 10-25 (5 days) | 8–56 | 25.9–27.8 / 28–31 | 86–94 | games |
| 11-01 | 135 | 26.9 / 32 | 91.6 | games |
| 11-02 | 23 | 30.3 / 33 | 96.8 | Cyberpunk |
| 11-04 | 58 | 27.0 / 30 | 92.6 | Cyberpunk |
| 11-12 | 200 | 25.4 / 30 | 90.4 | crash test (memtest_vulkan + CPU) |
| 11-20 | 59 | 26.3 / 28 | 91.0 | fan tests |
| 11-21 | 179 | 27.3 / 30 | 95.0 | this soak |

Six weeks of heavy load hold the delta at 24–28 °C, with no upward trend since the card
arrived. Contact with the die is not getting worse. The closest like-for-like run, the 11-12
crash test (also memtest_vulkan at ~295 W), averaged 25.4, about 2 °C under today. That is
inside the day-to-day spread, but worth a rerun in a few weeks. For reference, owners and
reviews of this card (Gigabyte 9070 XT Gaming OC) report deltas of 20–30 °C and hotspots of
88–93 °C in open-bench reviews; a delta above ~35 is the usual sign of poor contact, and the
known defective card (pitted die, Igor's Lab) ran 46. So 27 is the high side of normal. Repaste
only if it climbs past ~35 or the junction nears 110, since opening a refurbished card risks
its refund-only warranty. Our junction runs ~5 °C over the reviews mostly because the room is
28 °C and the card is in a case. Today's higher junction (95 vs 90) comes mostly
from a hotter edge, not a bigger delta.

Rerun with `python3 -I ~/fantest/daily.py <from> <to>` (daily table) and
`python3 -I ~/fantest/nights.py` (edit the dates inside). In the daily table, a day's figures cover
the 24 h before the next midnight UTC (WET is UTC in winter).

<details><summary>Daily table, 10-05 – 11-20 (11-08: orchid off)</summary>

| day | room | Tctl avg/max | DIMM avg/max | NVMe avg/max | board avg/max | GPU junction avg/max | CPU busy % | up h |
|---|---|---|---|---|---|---|---|---|
| 10-05 | - | 64 / 87 | 52 / 55 | 59 / 62 | - | 54 / 91 | 27 | 18 |
| 10-06 | - | 63 / 86 | 51 / 60 | 58 / 61 | - | 54 / 64 | 3 | 24 |
| 10-07 | - | 63 / 86 | 51 / 66 | 58 / 65 | - | 55 / 104 | 50 | 12 |
| 10-08 | - | 58 / 59 | 49 / 50 | 57 / 58 | - | 46 / 47 | 71 | 7 |
| 10-09 | - | 66 / 86 | 57 / 73 | 59 / 66 | - | 55 / 101 | 33 | 23 |
| 10-10 | - | 70 / 87 | 53 / 59 | 54 / 59 | 43 / 49 | 58 / 103 | 37 | 24 |
| 10-11 | - | 64 / 88 | 49 / 54 | 56 / 59 | 40 / 50 | 52 / 93 | 5 | 24 |
| 10-12 | - | 65 / 86 | 49 / 57 | 55 / 59 | 40 / 53 | 52 / 93 | 5 | 24 |
| 10-13 | - | 63 / 81 | 49 / 50 | 55 / 57 | 39 / 45 | 49 / 92 | 2 | 24 |
| 10-14 | - | 60 / 67 | 48 / 50 | 55 / 57 | 38 / 42 | 44 / 61 | 1 | 24 |
| 10-15 | - | 62 / 86 | 48 / 50 | 55 / 57 | 39 / 42 | 45 / 61 | 5 | 24 |
| 10-16 | - | 61 / 84 | 48 / 50 | 55 / 57 | 39 / 42 | 45 / 61 | 2 | 24 |
| 10-17 | - | 63 / 86 | 48 / 57 | 55 / 60 | 39 / 53 | 48 / 97 | 4 | 24 |
| 10-18 | - | 64 / 86 | 49 / 55 | 55 / 59 | 40 / 51 | 52 / 94 | 4 | 24 |
| 10-19 | - | 64 / 86 | 50 / 52 | 56 / 58 | 40 / 49 | 53 / 93 | 2 | 24 |
| 10-20 | - | 63 / 85 | 49 / 53 | 55 / 59 | 40 / 50 | 51 / 95 | 3 | 24 |
| 10-21 | 27.3 | 64 / 87 | 49 / 54 | 55 / 58 | 40 / 50 | 52 / 94 | 4 | 24 |
| 10-22 | 27.0 | 62 / 86 | 48 / 50 | 51 / 56 | 38 / 42 | 46 / 60 | 4 | 24 |
| 10-23 | 27.0 | 59 / 86 | 46 / 52 | 43 / 57 | 36 / 52 | 41 / 61 | 5 | 24 |
| 10-24 | 27.7 | 59 / 87 | 46 / 51 | 42 / 55 | 36 / 46 | 41 / 89 | 4 | 24 |
| 10-25 | 27.8 | 61 / 88 | 47 / 54 | 43 / 56 | 37 / 50 | 42 / 95 | 3 | 24 |
| 10-26 | 28.0 | 61 / 86 | 47 / 50 | 42 / 48 | 37 / 39 | 41 / 53 | 2 | 24 |
| 10-27 | 27.5 | 60 / 85 | 47 / 50 | 42 / 46 | 36 / 39 | 39 / 53 | 4 | 24 |
| 10-28 | 27.7 | 58 / 86 | 47 / 50 | 42 / 50 | 37 / 44 | 41 / 91 | 3 | 24 |
| 10-29 | 27.8 | 58 / 85 | 47 / 51 | 42 / 47 | 37 / 40 | 40 / 55 | 2 | 24 |
| 10-30 | 27.8 | 58 / 80 | 46 / 50 | 42 / 48 | 36 / 39 | 39 / 56 | 2 | 24 |
| 10-31 | 28.2 | 64 / 87 | 48 / 54 | 44 / 53 | 37 / 48 | 45 / 87 | 10 | 24 |
| 11-01 | 28.2 | 67 / 90 | 48 / 56 | 45 / 63 | 39 / 52 | 47 / 96 | 21 | 24 |
| 11-02 | 28.2 | 59 / 91 | 47 / 56 | 43 / 60 | 37 / 53 | 43 / 100 | 28 | 22 |
| 11-03 | 28.0 | 58 / 91 | 46 / 50 | 41 / 46 | 36 / 39 | 38 / 57 | 4 | 24 |
| 11-04 | 27.9 | 62 / 91 | 47 / 56 | 43 / 60 | 38 / 52 | 44 / 96 | 9 | 24 |
| 11-05 | 28.0 | 59 / 90 | 47 / 54 | 42 / 53 | 37 / 47 | 41 / 81 | 5 | 24 |
| 11-06 | 27.9 | 58 / 91 | 46 / 51 | 42 / 54 | 36 / 40 | 38 / 54 | 4 | 24 |
| 11-07 | 27.9 | 56 / 72 | 45 / 46 | 40 / 42 | 35 / 36 | 34 / 38 | 94 | 1 |
| 11-09 | 27.8 | 54 / 82 | 44 / 44 | 39 / 39 | 34 / 35 | - | 51 | 12 |
| 11-10 | 27.8 | 54 / 82 | 44 / 46 | 39 / 48 | 35 / 35 | - | 1 | 24 |
| 11-11 | 27.8 | 55 / 91 | 44 / 51 | 39 / 43 | 35 / 37 | 35 / 36 | 9 | 23 |
| 11-12 | 28.2 | 73 / 91 | 50 / 64 | 44 / 58 | 39 / 52 | 53 / 92 | 62 | 20 |
| 11-13 | 27.7 | 61 / 90 | 47 / 51 | 43 / 51 | 37 / 42 | 42 / 64 | 8 | 24 |
| 11-14 | 27.8 | 61 / 83 | 46 / 56 | 45 / 57 | 39 / 50 | 55 / 93 | 11 | 24 |
| 11-15 | 27.7 | 53 / 82 | 43 / 56 | 41 / 61 | 36 / 53 | 43 / 92 | 4 | 24 |
| 11-16 | 27.2 | 54 / 83 | 43 / 54 | 41 / 60 | 36 / 48 | 42 / 92 | 4 | 24 |
| 11-17 | 27.5 | 55 / 81 | 43 / 52 | 41 / 55 | 35 / 46 | 40 / 89 | 5 | 24 |
| 11-18 | 27.1 | 52 / 80 | 42 / 45 | 40 / 53 | 35 / 38 | 39 / 53 | 3 | 24 |
| 11-19 | 27.5 | 51 / 80 | 42 / 44 | 39 / 43 | 34 / 37 | 36 / 49 | 2 | 24 |
| 11-20 | 27.5 | 55 / 82 | 42 / 60 | 40 / 60 | 35 / 53 | 39 / 94 | 14 | 23 |

</details>

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
