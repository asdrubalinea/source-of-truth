# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal NixOS flake configuring three hosts (`tempest`, `orchid`, `hydra`) plus Home Manager for the `irene` user. The tree lives at `/persist/source-of-truth` (the path is load-bearing — several scripts hard-code it). See `AGENTS.md` for the author-maintained repo guidelines; this file is complementary, not a replacement.

## Common commands

Rebuilds are done from the flake root against `.#<host>`:

- `nixos-rebuild switch --flake '.#tempest' --sudo` — apply a host config. Wrapped as `config-apply` / `system-apply` (installed via home-manager from `scripts/config-apply.nix` and `scripts/system-apply.nix`) — both `pushd` into `/persist/source-of-truth` and run `nixos-rebuild switch --flake '.#' --sudo`, so `.#` resolves to the current host's `nixosConfigurations` entry by hostname.
- `home-manager switch --flake '.#irene@<host>'` — apply a standalone Home Manager config. Both `orchid` and `tempest` have entries under `homeConfigurations` (`irene@orchid`, `irene@tempest`). On tempest there's a `user-apply` wrapper (`scripts/user-apply.nix`) that runs this with `-b backup`. On tempest a system change therefore needs **both** `system-apply` and `user-apply`.
- `update-home` (tempest only, `scripts/update-home.nix`) — `nix flake update` for the subset of inputs that only affect tempest's HM closure (`nixpkgs-home`, `claude-code`, `codex`, `zen-browser`, `hn-tui-flake`, `emacs-overlay`, `stylix`, `hyprland`). `niri` and `helix` are intentionally excluded because both also live in tempest's system layer.
- `./update-flakes.sh` — `nix flake update` (everything).
- `system-clean` (from `scripts/system-clean.nix`) — delete old generations, GC, optimize the store.

Disk / install helpers are **destructive** — they wipe and reformat the target device. Only run when actually installing:

- `./tempest-format.sh` — runs disko `destroy,format,mount` against `./disks/tempest.nix`.
- `./tempest-install.sh` — disko-install `.#tempest` to `/dev/nvme0n1`.
- `./vm-install.sh` — disko-install `.#vm` to `/dev/vda` (note: no `vm` entry currently exists in `flake.nix`; check before running).

No test framework — validation is "does `nixos-rebuild` evaluate and switch successfully on the relevant host".

**Do not run `nixos-rebuild` (build, switch, dry-build, dry-activate, …), `home-manager switch`, `config-apply`, `system-apply`, `user-apply`, or any other command that builds or activates the system config.** The user runs all rebuilds themselves. Make the edits and stop — do not "verify" by building.

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

**Home Manager integration**: both desktop hosts now run HM **standalone** via `homeConfigurations` — `irene@orchid` and `irene@tempest`. On both hosts a system change requires two activations: `system-apply` (or `config-apply`) for NixOS, then `home-manager switch --flake '.#irene@<host>'` (wrapped as `user-apply` on tempest) for HM.

Tempest's HM build uses a separate `nixpkgs-home` flake input (also tracking `nixos-unstable`) consumed via `mkHomePkgs` in `flake.nix`. This lets `update-home` advance the HM channel without touching the system channel. The same `overlays` list is applied to both `mkPkgs` and `mkHomePkgs`, so `pkgs.stable.foo` still resolves identically in HM modules. `flake.nix` also exposes the locked HM CLI as `packages.<system>.home-manager` so you can bootstrap with `nix run /persist/source-of-truth#home-manager -- switch --flake '.#irene@tempest' -b backup` when `home-manager` isn't on PATH yet.

Home configs themselves are composition roots that import a rice, desktop modules, and script modules — same pattern as host configs.

## Conventions worth knowing

- The working directory is `/persist/source-of-truth` and several scripts hard-code that path. Don't move the tree without updating `scripts/config-apply.nix` and `homes/orchid.nix`'s `user-apply`/`system-apply` wrappers.
- Secrets go through `sops-nix` (imported in `homes/orchid.nix`). Don't commit raw secrets.
- Host `specialArgs` / `extraSpecialArgs` inject `inputs` and `hostname` — modules expect these available.
- Nix formatting: 2-space indent (alejandra / nixpkgs-fmt if available). Shell scripts use explicit `set -euo pipefail` where relevant (`vm-install.sh`) or plain `#!/bin/sh` for simple wrappers.
- Commit style (per `AGENTS.md` and recent log): short, lowercase summaries, one logical change per commit, mention the host or module touched.
