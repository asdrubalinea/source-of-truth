# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal NixOS flake configuring three hosts (`tempest`, `orchid`, `hydra`) plus Home Manager for the `irene` user. The tree lives at `/persist/source-of-truth` (the path is load-bearing — several scripts hard-code it). See `AGENTS.md` for the author-maintained repo guidelines; this file is complementary, not a replacement.

## Common commands

Rebuilds are done from the flake root against `.#<host>`:

- `nixos-rebuild switch --flake '.#tempest' --sudo` — apply a host config. Wrapped as `config-apply` / `system-apply` (installed via home-manager from `scripts/config-apply.nix` and `scripts/system-apply.nix`) — both `pushd` into `/persist/source-of-truth` and run `nixos-rebuild switch --flake '.#' --sudo`, so `.#` resolves to the current host's `nixosConfigurations` entry by hostname.
- `home-manager switch --flake '.#irene@orchid'` — apply a standalone Home Manager config (only `orchid` has one under `homeConfigurations`; `tempest` integrates home-manager as a NixOS module, so `nixos-rebuild` is enough there).
- `./update-flakes.sh` — `nix flake update`.
- `system-clean` (from `scripts/system-clean.nix`) — delete old generations, GC, optimize the store.

Disk / install helpers are **destructive** — they wipe and reformat the target device. Only run when actually installing:

- `./tempest-format.sh` — runs disko `destroy,format,mount` against `./disks/tempest.nix`.
- `./tempest-install.sh` — disko-install `.#tempest` to `/dev/nvme0n1`.
- `./vm-install.sh` — disko-install `.#vm` to `/dev/vda` (note: no `vm` entry currently exists in `flake.nix`; check before running).

No test framework — validation is "does `nixos-rebuild` evaluate and switch successfully on the relevant host". Prefer `nixos-rebuild build --flake '.#<host>'` (no `switch`) for a dry eval when iterating on a host you're not running on.

## Architecture

The flake is wired together with three main axes:

**Hosts** (`flake.nix` → `nixosConfigurations`):
- `tempest` — Framework AMD AI 300 laptop. Uses `disko` + `impermanence` + `lanzaboote` + `ucodenix` + `nixos-hardware.framework-amd-ai-300-series`. Home Manager is attached as a NixOS module here (so one rebuild covers both). Disko layout is `disks/tempest.nix`.
- `orchid` — desktop; minimal flake wiring, uses standalone Home Manager (`homeConfigurations."irene@orchid"`).
- `hydra` — QEMU guest server (imports `profiles/qemu-guest.nix`), uses disko, runs `services/caddy`.
- `router.nix` at `hosts/router.nix` is a single-file variant (not currently wired into `nixosConfigurations`).

Each host's `default.nix` is the composition root: imports its own `system/*.nix` and `users/*.nix`, then pulls shared modules from `../../modules`, `../../services`, `../../hardware`, `../../desktop`, and `../../rices`. There is no central "enable options" layer — host composition is explicit `imports = [ ... ]` lists. Toggling a feature for a host means editing that host's `default.nix` (or a file it imports), not flipping a top-level option.

**Shared modules** (imported by hosts):
- `modules/` — cross-cutting system modules (`nix.nix`, `gaming.nix`, `secure-boot.nix`).
- `hardware/` — opt-in hardware modules (audio, bluetooth, framework, pipewire, rocm, zfs, tlp). Hosts pick what they need.
- `services/` — NixOS services (borg-backup, btrfs-snapshots, caddy, grafana, glance, syncthing, ssh-secure, redshift, nix-cleanup, thermal-logger). Each is imported à la carte.
- `desktop/` — editor/terminal/app configs consumed from Home Manager (vscode, helix, neovim, emacs, zed, tmux, fonts, home-packages, gnome/kde/plasma).
- `rices/{estradiol,hypr,niri}` — desktop environments. Each rice has a `system.nix` (imported by the host) and a `default.nix` / home-manager-side files (imported by the home config). `tempest` currently uses `niri`; `orchid` currently uses `estradiol`.
- `packages/` — custom derivations called via `pkgs.callPackage` from home configs.
- `scripts/` — Nix files that build small `writeScriptBin` wrappers (`config-apply`, `system-apply`, `system-clean`, `port-forward`, `battery`, `brightness`, `wait-ac`, `thermal-logger`). These are installed into `home.packages` by importing the script module from a home config.

**Nixpkgs channels**: `flake.nix` builds a `multiChannelOverlay` exposing `pkgs.stable` (nixos-25.11), `pkgs.trunk`, and `pkgs.custom` (both `github:nixos/nixpkgs`). Default `nixpkgs` is `nixos-unstable`. Reach for `pkgs.stable.foo` when unstable breaks something. Other overlays active globally: `emacs-overlay`, `niri`, `claude-code`, `nix-cachyos-kernel`. `allowUnfree = true`.

**Home Manager integration** differs by host:
- On `tempest`, HM is wired in via `home-manager.nixosModules.home-manager` inside `nixosConfigurations.tempest`, with `useUserPackages = true` and `backupFileExtension = "backup"`. `homes/tempest.nix` is the user entry point.
- On `orchid`, HM runs standalone via `homeConfigurations."irene@orchid"` and `homes/orchid.nix`. Rebuild with `home-manager switch --flake '.#irene@orchid'`.

Home configs themselves are composition roots that import a rice, desktop modules, and script modules — same pattern as host configs.

## Conventions worth knowing

- The working directory is `/persist/source-of-truth` and several scripts hard-code that path. Don't move the tree without updating `scripts/config-apply.nix` and `homes/orchid.nix`'s `user-apply`/`system-apply` wrappers.
- Secrets go through `sops-nix` (imported in `homes/orchid.nix`). Don't commit raw secrets.
- Host `specialArgs` / `extraSpecialArgs` inject `inputs` and `hostname` — modules expect these available.
- Nix formatting: 2-space indent (alejandra / nixpkgs-fmt if available). Shell scripts use explicit `set -euo pipefail` where relevant (`vm-install.sh`) or plain `#!/bin/sh` for simple wrappers.
- Commit style (per `AGENTS.md` and recent log): short, lowercase summaries, one logical change per commit, mention the host or module touched.
