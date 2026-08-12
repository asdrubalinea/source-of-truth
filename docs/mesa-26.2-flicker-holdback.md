# Held back: mesa 26.2.0 redraw flicker (tempest)

**Status: flake.lock held back — check this before running `nix flake update`.**

## Symptom

After the 2026-08-09 flake update (commit `9342cdb`), GPU-compositing clients
flashed stale/black blocks on every redraw under niri ("sfarfallio" while
typing or scrolling). Worst offenders: zed and wezterm (both Vulkan via RADV —
blade and WebGpu). Chromium/Electron and Qt6 apps (Chrome, Telegram) flickered
too; plain-EGL clients (alacritty, Firefox/Zen) were always clean.

## Root cause

**mesa 26.2.0** (released 2026-08-05, entered nixos-unstable by the 2026-08-07
rev). The client-side driver delivers buffers whose explicit-sync fences the
compositor cannot rely on, so niri samples stale content. Evidence:

- Started exactly when the system nixpkgs moved 2026-08-01 → 2026-08-07
  (mesa 26.1.6 → 26.2.0); no toolkit or app versions changed.
- Survived two unrelated niri builds (v25.08 and unstable 2026-08-02), so it
  is not a niri regression.
- niri's `debug.wait-for-frame-completion-before-queueing` flag only papered
  over the EGL/Chromium clients — it makes niri wait for *its own* composited
  frame, which cannot help when the *client's* fences are wrong — and costs
  latency (serializes render → queue; at 165 Hz the ~6 ms budget makes that
  droppable frames).
- Confirmed by A/B: pinning only `hardware.graphics.package` to mesa 26.1.6
  (nixpkgs `3a971fa2`) killed the flicker with everything else unchanged.
- Not the kernel: zero amdgpu/DRM errors in the journal across the whole
  period. (`Atomic Test failed` bursts in niri's log are dock hotplug noise,
  ~1 minute, unrelated.)

No specific upstream mesa issue was pinned down; the 26.2.0 release notes
already list other RADV regressions. Nothing was reported upstream by us.

## Current state (2026-08-13)

Instead of carrying a mesa pin, `flake.lock` was rolled back to the
pre-update revs for the platform inputs:

| input | held rev | date |
|---|---|---|
| `nixpkgs` | `148bab9c1c` | 2026-08-01 |
| `nixpkgs-home` | `148bab9c1c` | 2026-08-01 |
| `nix-cachyos-kernel` | `4f3c8ca048` | 2026-07-31 |

Everything else (niri, claude-code, zen-browser, stylix, …) stays current.
**niri deliberately kept its 2026-08-04 rev**: its nixpkgs is pinned to
niri-flake's CI rev for cachix hits — rolling it back re-triggers the ~277 MB
local Rust build (see the niri-prebuilt notes in `flake.nix`).

The debug flag was removed from `rices/niri/niri.nix`; the temporary
`nixpkgs-mesa` pin input was removed from `flake.nix` and
`hosts/tempest/hardware.nix`.

⚠️ `update-home` (tempest) bumps `nixpkgs-home` and therefore re-imports
mesa 26.2.0 into the HM closure — don't run it either until this is resolved.

## Before the next `nix flake update` — is it fixed yet?

1. What mesa does nixos-unstable ship now? (NixHub/nixhub.io or
   `nix eval github:nixos/nixpkgs/nixos-unstable#mesa.version`.)
   Still 26.2.0 → don't update `nixpkgs`/`nixpkgs-home`.
2. A 26.2.1+ exists → skim its release notes
   (https://docs.mesa3d.org/relnotes/) for RADV/WSI/explicit-sync fixes.
   No smoking gun in the notes is *not* proof it's unfixed — the definitive
   test is local:
3. Update, `nh os switch && nh home switch -b backup`, **logout/login**
   (drivers are loaded per-process; the whole niri session must restart),
   then type/scroll in zed and wezterm for a minute.
4. Flicker back → roll back: restore the three held revs above in
   `flake.lock` (git has them in this commit) and re-switch. If unstable has
   meanwhile moved past what the held rev can support, fall back to the
   surgical pin: `hardware.graphics.package`/`package32` from a nixpkgs rev
   carrying mesa ≤ 26.1.6 (e.g. `3a971fa2`) — that variant is in git history
   too (2026-08-13).

Once a fixed mesa is confirmed, delete this file.
