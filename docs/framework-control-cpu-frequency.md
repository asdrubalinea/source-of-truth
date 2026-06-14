# CPU frequency scaling on tempest (Framework 13 AMD, Ryzen AI 7 350)

_Date: 2026-06-14_

## TL;DR

The cores were misbehaving in two layered ways, and the real fix is the
**amd_pstate driver mode**, not framework-control:

1. **framework-control** (ozturkkl daemon) was driving cpufreq and conflicting
   with TLP — capping clocks at ~2 GHz under load for a week, then forcing
   `performance: max` after a kernel upgrade. It was removed (it's a convenience
   layer that overlaps TLP; never the baseline). **Correct cleanup, but it did
   not fix the scaling.**
2. After removal, cores **still** sat pinned near max at idle. That is the
   **documented, by-design behaviour of `amd_pstate=guided` + `schedutil`** —
   not a fault. The fix is to switch to **`amd_pstate=active` + `powersave`
   governor + EPP**, which gives real demand-based scaling.

Config changes applied: `amd_pstate=active` (de-duplicated), TLP
`CPU_DRIVER_OPMODE=active`, `CPU_SCALING_GOVERNOR=powersave`, EPP now effective
(`balance_performance` AC / `power` BAT).

## Timeline of symptoms

- **06/08 → 06/14 13:48 (kernel 6.18.33, framework-control running):** cores
  capped at a ~2 GHz ceiling. Heavy work never boosted; brief spikes to
  3–4.5 GHz got yanked back. (framework-control was holding the ceiling down.)
- **13:48 → 17:54 (kernel 6.18.35, framework-control running):** rebooted into a
  new kernel where framework-control's cpufreq control became effective
  (`cpufreq detected … available` → `cpufreq performance level: max`). It flipped
  to pinning every core at max — ~5 GHz Zen5 / ~3.3 GHz Zen5c.
- **17:54+ (kernel 6.18.35, framework-control removed):** still pinned near max
  at idle (load ~1.6, `/proc/cpuinfo` aperf-confirmed real, not a readout
  artifact). `scaling_min_freq` = 623 MHz (floor NOT pinned), governor schedutil,
  `amd_pstate=guided`, TLP `balanced/AC`, nothing in config forcing performance.

The Ryzen AI 7 350 (Krackan Point) is 4× Zen5 + 4× Zen5c = 8C/16T; the two flat
bands are the two core types at their own ceilings (Zen5 5.09 GHz, Zen5c ~3.5 GHz).

## Root cause (researched, citation-backed)

**`amd_pstate=guided` hands the operating-point choice to the CPU firmware.** In
guided-autonomous mode the kernel/governor only writes a min/max *band*:
schedutil's utilization value becomes `MIN_PERF`, `des_perf` is zeroed, and
`MAX_PERF` stays at max capacity. The platform then opportunistically picks *any*
frequency in `[~623 MHz floor, 5 GHz]`. So `scaling_min_freq` correctly sits at
the 623 MHz nonlinear floor while the hardware freely boosts to the top —
**schedutil cannot command a low idle frequency in guided mode**, it can only
widen/narrow the band. _(kernel.org amd-pstate docs; AMD/Wyes Karny LKML patch:
`if (cppc_state == AMD_PSTATE_GUIDED && … DYNAMIC_SWITCHING) { min_perf =
des_perf; des_perf = 0; }`. Corroborated on Ryzen 5800U: guided/passive idled
~1100 MHz, dropped to ~400 MHz only after switching to active.)_

Two corollaries that bit us:

- **EPP only exists in active mode.** Under `guided`, `scaling_driver` is
  `amd-pstate` (not `amd-pstate-epp`) and `…/cpufreq/energy_performance_preference`
  does not exist — so TLP's `CPU_ENERGY_PERF_POLICY_ON_AC/BAT` were **silently
  inert** the whole time. _(TLP docs: "passive and guided mode do not support
  EPP"; verified live on this machine.)_
- **The 623 MHz floor is intentional.** Since kernel 6.13 amd-pstate initializes
  `scaling_min_freq` to `amd_pstate_lowest_nonlinear_freq` (most efficient
  point), not the absolute minimum. Switching to active does **not** change this
  floor — it changes *who* picks the operating point above it.

## The fix: amd_pstate=active + powersave + EPP

**`amd_pstate=active`** (the `amd_pstate_epp` driver) delegates the operating
point to the CPPC firmware power algorithm via an EPP hint, and the firmware
computes the realtime frequency from workload/power/thermal — i.e. genuine demand
scaling (idle low, full boost under load). It's the kernel default since 6.5 for
full-CPPC Zen2+ parts. _(kernel.org amd-pstate docs; Arch Wiki.)_

**`powersave` governor (both AC and BAT).** Active mode exposes only
`powersave`/`performance` pseudo-governors; these do **not** pin to min/max —
they translate to an EPP hint and still scale dynamically (`powersave` ≈
schedutil-like, `performance` ≈ ondemand-like). `schedutil` pairs with
passive/guided, not active. _(Arch Wiki; TLP docs.)_

**EPP is the AC↔battery lever.** `balance_performance` on AC, `power` (or the
gentler `balance_power`) on battery. Set it explicitly — kernel EPP defaults for
Ryzen clients are a moving target (6.14 → `balance_performance`; ~2026 mainline →
`epp_default_ac=performance` / `epp_default_dc=balance_performance`), so relying
on the default is ambiguous. _(Limonciello/AMD LKML, Dec 2024.)_

**Power manager: keep TLP, keep PPD masked** (repo already does this). TLP and
power-profiles-daemon change the same tunables and overwrite each other; PPD also
has no idle-power knobs, which is exactly this machine's complaint workload.
_(TLP FAQ.)_

### Recommended settings

| Knob                | AC                    | Battery               |
|---------------------|-----------------------|-----------------------|
| amd_pstate mode     | `active`              | `active`              |
| governor            | `powersave`           | `powersave`           |
| EPP                 | `balance_performance` | `power` → `balance_power` if too aggressive |
| boost               | on (`1`)              | off (`0`)             |
| platform_profile    | `balanced`            | `low-power`           |

Kernel cmdline: single `amd_pstate=active` (the old runtime duplicate
`amd_pstate=active … amd_pstate=guided` came from framework-control injecting
`active` + boot.nix appending `guided`; with framework-control gone and boot.nix
now set to `active`, there is exactly one).

### Files changed

- `hosts/tempest/system/boot.nix` — `amd_pstate=guided` → `amd_pstate=active`.
- `hardware/framework-tlp-advanced.nix` — `CPU_DRIVER_OPMODE=active`,
  `CPU_SCALING_GOVERNOR=powersave` (was guided/schedutil); EPP values unchanged
  but now effective.

## Framework-specific caveat (medium confidence)

Per AMD's amd_pstate maintainer (via the TLP FAQ): on Framework AMD,
`platform_profile` has a kernel→BIOS→EC path that changes APU coefficients, and
EPP influences the same coefficients — driving **both** can cause contention. The
conservative Framework-clean alternative is to **empty `CPU_ENERGY_PERF_POLICY`
and drive only `PLATFORM_PROFILE`** (performance/balanced/low-power). We're using
the EPP-driven approach as primary (higher control, and what the closest
published FW13-AMD-AI-300 TLP profile uses); if odd interactions appear after the
switch, fall back to platform_profile-only. Upstream 6.12+/2026 "dynamic EPP /
platform-profile class" work exists specifically to couple these so they stop
fighting.

## After rebuild — verify

1. `cat /sys/devices/system/cpu/amd_pstate/status` → `active`;
   `…/cpu0/cpufreq/scaling_driver` → `amd-pstate-epp`.
2. `cat …/cpu0/cpufreq/scaling_available_governors` includes `powersave`.
   (Note: this CachyOS LTS kernel builds several generic governors as modules and
   today shows only `performance schedutil`; in **active** mode the
   `amd_pstate_epp` driver supplies `powersave`/`performance` itself, so this
   should appear — but confirm, since TLP setting an unavailable governor fails.)
3. `…/cpu0/cpufreq/energy_performance_preference` now exists and reads
   `balance_performance` on AC.
4. Grafana: idle should drop toward ~1 GHz (the big change) and heavy work should
   reach ~5 GHz — load-tracking, not a flat line.

## Open questions

- No Krackan-Point-specific idle measurement was found (evidence is Zen3 5800U +
  Strix-Point HX 370). The mechanism generalizes; exact AI 7 350 idle clocks are
  unverified until we see the post-switch Grafana trend.
- Whether the 6.18/CachyOS "dynamic_epp / platform-profile class" coupling is on
  by default here, which would decide if explicit EPP writes are honored or the
  platform_profile-only path is effectively in force.
- `scx_bpfland` (sched_ext, enabled in `boot.nix`) changes task placement but not
  P-state selection, so it doesn't alter this recommendation.

## Sources

kernel.org amd-pstate docs; Arch Wiki CPU frequency scaling; TLP processor /
PPD-FAQ docs (linrunner.de); AMD/Limonciello & Wyes Karny LKML patches;
community.frame.work + bbs.archlinux.org threads; connor-petri/fw13-tlp-config.
