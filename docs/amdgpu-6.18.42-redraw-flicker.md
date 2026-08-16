# Redraw flicker under niri: linux-cachyos-lts 6.18.42 (tempest)

**Status: `nix-cachyos-kernel` pinned in `flake.nix`. Unpin when `release`
publishes `linux-cachyos-lts` >= 6.18.44.**

## Symptom

GPU-compositing clients flash stale/black blocks on every redraw under niri
("sfarfallio" while typing or scrolling). Worst offenders: zed and wezterm
(both Vulkan via RADV), plus Chromium/Electron and Qt6 apps. Plain-EGL clients
(alacritty, Firefox/Zen) look clean. The kernel log is **completely clean** —
no amdgpu resets, ring timeouts, page faults or DMUB errors.

## Cause

`linux-cachyos-lts` **6.18.42**. Reported upstream as an amdgpu bug and fixed
in **6.18.44** (niri-wm/niri#4433; a commenter there reports it broken on
6.18.43). niri-wm/niri#4443 is an open report of the same family.

Evidence — the surviving system generations, read with
`nix-store -qR /nix/var/nix/profiles/system-N-link | grep -oE 'mesa-[0-9.]+'`
and `readlink -f /nix/var/nix/profiles/system-N-link/kernel`:

| gen | date | kernel | mesa | flicker |
|---|---|---|---|---|
| 65 | 2026-08-11 | 6.18.42 | 26.2.0 | yes |
| 66 | 2026-08-13 | 6.18.42 | 26.1.6 | (short-lived) |
| 67 | 2026-08-13 | 6.18.40 | 26.1.6 | no |
| 68 | 2026-08-15 | 6.18.40 | 26.1.6 | no |
| 69 | 2026-08-15 | **6.18.42** | **26.1.6** | **yes** |
| 70 | 2026-08-15 | 6.18.40 | 26.1.6 | no (pin confirmed) |
| 71 | 2026-08-15 | 6.18.40 | **26.2.0** | **no** (mesa exonerated) |

6.18.42 is in every flickering generation and no clean one. Gen 71 closes the
2×2: mesa 26.2.0 on a 6.18.40 kernel is clean, so mesa was never a factor in
either direction.

## Why this was blamed on mesa 26.2.0 for two days

The 2026-08-13 rollback moved `nixpkgs` **and** `nix-cachyos-kernel` in the
same commit (`6ddcd05`), so mesa 26.2.0 and lts 6.18.42 were confounded for
the entire investigation — every "mesa" data point had a kernel riding inside
it. Gen 69 (2026-08-15) is the first generation that moved the kernel *without*
moving mesa, and it flickered on mesa 26.1.6. mesa is exonerated; both
`nixpkgs` holds were dropped the same day and the system runs mesa 26.2.0.

Lesson: roll back one input per commit, or the bisect is worthless.

The old "not the kernel: zero amdgpu/DRM errors in the journal" argument was
never valid — the niri#4433 reporter had a clean journal too, and so does this
machine while flickering.

## Wrong leads — don't re-chase

- `programs.niri.settings.debug."wait-for-frame-completion-before-queueing"`
  only papers over the EGL/Chromium clients and costs latency (serialises
  render → queue; at 165 Hz the ~6 ms budget makes frames droppable). Removed
  from `rices/ember/compositors/niri/niri.nix`.
- Not a niri regression: survived niri v25.08 and unstable 2026-08-02.
- Not VRR (`niri msg outputs` says "supported, disabled" everywhere), not
  output-specific, not fractional scaling.
- `mesa-libgbm-26.1.3` alongside `mesa-26.2.0` is just how nixpkgs splits the
  gbm output, not a version skew.
- `Atomic Test failed` bursts in niri's log are dock hotplug noise.

## Unpinning

1. Check `release`: `curl -s https://raw.githubusercontent.com/xddxdd/nix-cachyos-kernel/release/kernel-cachyos/version.json | jq -r '."linux-cachyos-lts".version'`
2. >= 6.18.44 → restore `url = "github:xddxdd/nix-cachyos-kernel/release";` in
   `flake.nix`, `nix flake update nix-cachyos-kernel`, `apply`, **reboot**
   (the driver is in the kernel; a switch alone proves nothing).
3. Type/scroll in zed and wezterm for a few minutes. Clean → delete this file.
4. Flickering → re-pin to `4f3c8ca048` (lts 6.18.40, the last known-good) and
   report the version on niri-wm/niri#4443.
