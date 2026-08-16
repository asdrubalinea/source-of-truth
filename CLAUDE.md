# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Personal NixOS flake configuring four machines — `tempest` (laptop), `orchid` (desktop), `hydra` (QEMU server), `zephyr` (Raspberry Pi 3B+, aarch64) — plus `tempest-vm`, a non-destructive QEMU clone of tempest, and Home Manager for the `irene` user. The tree lives at `/persist/source-of-truth` (the path is load-bearing — several scripts hard-code it). See `AGENTS.md` for the author-maintained repo guidelines; this file is complementary, not a replacement.

## Common commands

Applying config is [`nh`](https://github.com/nix-community/nh), enabled per host with `programs.nh = { enable = true; flake = "<repo path>"; }` (tempest and orchid: `/persist/source-of-truth`; hydra: `/home/irene/source-of-truth`). That option sets `NH_FLAKE`, so every `nh` command works from any directory — no `pushd`, no wrapper scripts:

- `nh os switch` — activate the current host's `nixosConfigurations` entry (resolved by hostname). Handles its own privilege elevation and prints an nvd package diff.
- `nh home switch -b backup` — activate `homeConfigurations."irene@<host>"` (resolved from `$USER@$HOSTNAME`; `-c` overrides). `-b backup` is passed by habit so a conflicting file is moved aside instead of aborting the switch.
- `apply` — shell alias (`misc/aliases.nix`) for `nh os switch && nh home switch -b backup`. Both hosts run HM standalone, so a full system change needs both activations; this is the daily command.
- Useful flags on either: `-n` dry run, `-a` ask before activating, `-u` update all flake inputs first, `-U <input>` update one, `-d always` force the package diff.
- `update-home` (tempest only, `scripts/update-home.nix`) — `nix flake update` for the subset of inputs that only affect tempest's HM closure (`nixpkgs-home`, `claude-code`, `llm-agents`, `zen-browser`, `hn-tui-flake`, `emacs-overlay`, `stylix`, `hyprland`). `niri` and `helix` are intentionally excluded because both also live in tempest's system layer.
- `nix flake update` — update all flake inputs (the old `./update-flakes.sh` wrapper was removed).
- `nh clean all` — delete old generations and GC across **all** profiles (system, per-user, home-manager) plus gcroots — `nix.gc` only ever pruned the system profile. Runs weekly on its own via `programs.nh.clean` (`--keep 5 --keep-since 7d`), so it rarely needs invoking by hand. `nix.gc.automatic` is set to `false` on every host that enables it (the two are mutually exclusive); `nix.optimise` stays on, since `nh clean` doesn't hardlink-dedupe. Replaces the old `system-clean` wrapper and `services/nix-cleanup.nix`.

The old `config-apply` / `system-apply` / `user-apply` / `system-clean` `writeScriptBin` wrappers were deleted in favor of the above — if you find a reference to one, it's stale.

A non-destructive `tempest-vm` clone exists for testing the full config (disko layout + impermanence + niri) in QEMU without touching hardware:

- `./build-vm` — `nix build .#nixosConfigurations.tempest-vm.config.system.build.vmWithDisko`; run the result with `./result/bin/disko-vm`. (Do NOT use `nixos-rebuild build-vm` — it builds a generic VM that ignores the disko layout and the VM tuning in `hosts/tempest/vm.nix`.)

Disk / install helpers are **destructive** — they wipe and reformat the target device. Only run when actually installing:

- `./tempest-format /dev/disk/by-id/<target>` — runs disko `destroy,format,mount` against `./disks/tempest.nix`. The target device is a **required argument** (no default) — `disks/tempest.nix` only has a non-existent placeholder, so a bare/accidental run fails fast instead of wiping a disk.
- `./tempest-install /dev/disk/by-id/<target>` — disko-install `.#tempest` to the given device (passed through as `--disk main`). Same required-argument safety.

No test framework — validation is "does it evaluate and switch successfully on the relevant host", via `nh` (not `nixos-rebuild`, which this repo doesn't use outside the fresh-install runbooks in `docs/`).

**Do not run `nixos-rebuild` (build, switch, dry-build, dry-activate, …), `home-manager switch`, `nh os` / `nh home` / `nh clean`, `apply`, or any other command that builds or activates the system config.** The user runs all rebuilds themselves. Make the edits and stop — do not "verify" by building.

## Architecture

The flake is wired together with three main axes:

**Hosts** (`flake.nix` → `nixosConfigurations`):
- `tempest` — Framework AMD AI 300 laptop. Uses `disko` + `impermanence` + `lanzaboote` + `ucodenix` + `nixos-hardware.framework-amd-ai-300-series`. Disko layout is `disks/tempest.nix`. Home Manager is **standalone** here, not a NixOS module — see the Home Manager section below.
- `tempest-vm` — the same `hosts/tempest/default.nix` built with `virtual = true` (`mkTempest` in `flake.nix`), which drops the physical-hardware imports. Built via `./build-vm`.
- `orchid` — desktop; minimal flake wiring, uses standalone Home Manager (`homeConfigurations."irene@orchid"`).
- `hydra` — QEMU guest server (imports nixpkgs' own `profiles/qemu-guest.nix` via `modulesPath`), uses disko, runs `services/caddy`.
- `zephyr` — Raspberry Pi 3B+, headless aarch64. Built on tempest under binfmt emulation and flashed as an SD image; no disko, no `nixos-hardware`, and a trimmed overlay set (the desktop overlays don't cross-compile cleanly). See `docs/adr/0005`.

Each host's `default.nix` is the composition root: imports its own `system/*.nix` and `users/*.nix`, then pulls shared modules from `../../modules`, `../../services`, `../../hardware`, `../../desktop`, and `../../rices`. Host composition is explicit `imports = [ ... ]` lists by default — toggling a feature for a host usually means editing that host's `default.nix` (or a file it imports), not flipping a top-level option. Enable-options are the deliberate exception, used only where a unit is large enough to be worth a clean on/off boundary: `rices.ember.enable` (the ember rice, plus one flag per compositor layer; see `docs/adr/0004-niri-rice-as-enable-module.md` and `docs/adr/0012-one-rice-two-compositors.md`) is the only one. The `options/` tree that once held `vfio.enable` was imported by no host and has been deleted.

**Shared modules** (imported by hosts):
- `modules/` — cross-cutting system modules (`nix.nix`, `secure-boot.nix`).
- `hardware/` — opt-in hardware modules (audio, bluetooth, framework, zfs, tlp). Hosts pick what they need. (`pipewire.nix` was deleted — `audio.nix` supersedes it and `pipewire.nix` still referenced the renamed `hardware.pulseaudio` option.)
- `services/` — NixOS services (borg-backup, caddy, grafana, syncthing, ssh-secure, vaultwarden-mirror). Each is imported à la carte. `vaultwarden-mirror` is the read-only mirror of orchid's vault, shared by tempest and hydra (it was two byte-identical copies under `hosts/*/system/vaultwarden-sync.nix`); only `sshKeyPath` varies, because tempest's tmpfs root forces the key onto `/persist`.
  - Colour temperature on tempest is `services.wlsunset` (Home Manager, `homes/tempest/default.nix`). `services/redshift.nix` was removed: its `randr` backend has no X display under niri, so it exited 1 on every start and systemd restart-looped it indefinitely while wlsunset did the actual work.
- `desktop/` — editor/terminal/app configs consumed from Home Manager (vscode, helix, neovim, zed, tmux, fonts, home-packages, warp, mimeapps). `desktop/emacs/` and `desktop/{gnome,kde,plasma}.nix` are present but imported by nothing: the emacs import is commented out in both home configs, and the three DE modules are leftovers from the Plasma removal.
- `rices/{estradiol,ember}` — desktop environments. Each rice has a `system.nix` (imported by the host) and a `default.nix` / home-manager-side files (imported by the home config). `orchid` uses `estradiol`. `tempest` uses `ember`, which is **one rice with two compositor layers** under `rices/ember/compositors/{niri,mango}/` — both are installed and the session is chosen at the greeter per login; see `docs/adr/0012-one-rice-two-compositors.md`.
- `packages/` — custom derivations called via `pkgs.callPackage` from home configs.
- `scripts/` — Nix files that build small `writeScriptBin` wrappers (`update-home`, `port-forward`, `keep-awake`, `ps5-audio`). These are installed into `home.packages` by importing the script module from a home config. Larger ones (`cage`, `sitrep`) are `writeShellApplication`s whose body lives in a sibling `.sh` file — those are shellcheck-gated at build time, so a warning-level finding fails the build.
- `sitrep` (`scripts/sitrep.nix` + `scripts/sitrep.sh`) — one-screen health readout: alerts, load/PSI, memory, ZFS pools, SMART, filesystems, backup units, failed services, network, power/thermal, and this boot's log errors grouped by shape. Feature-detects everything, so it degrades rather than fails on hosts without ZFS or a battery. SMART needs root (`sudo sitrep`); the unprivileged run says so instead of printing zeroes. Renders into `$BODY` inside a brace group so the alert block can be printed above the detail — any loop that raises an alert must use `done < <(cmd)`, never `cmd | while`, or the alert is lost in the subshell.

**Nixpkgs channels**: `flake.nix` builds a `multiChannelOverlay` exposing `pkgs.stable` (nixos-25.11), `pkgs.trunk`, and `pkgs.custom` (both `github:nixos/nixpkgs`). Default `nixpkgs` is `nixos-unstable`. Reach for `pkgs.stable.foo` when unstable breaks something. Other overlays active globally: `emacs-overlay`, `niri`, `claude-code`, `nix-cachyos-kernel`. `allowUnfree = true`.

**Home Manager integration**: both desktop hosts now run HM **standalone** via `homeConfigurations` — `irene@orchid` and `irene@tempest`. On both hosts a system change requires two activations: `nh os switch` for NixOS, then `nh home switch -b backup` for HM — `apply` runs both in order.

Tempest's HM build uses a separate `nixpkgs-home` flake input (also tracking `nixos-unstable`) consumed via `mkHomePkgs` in `flake.nix`. This lets `update-home` advance the HM channel without touching the system channel. The same `overlays` list is applied to both `mkPkgs` and `mkHomePkgs`, so `pkgs.stable.foo` still resolves identically in HM modules. `flake.nix` also exposes the locked HM CLI as `packages.<system>.home-manager` so you can bootstrap with `nix run /persist/source-of-truth#home-manager -- switch --flake '.#irene@tempest' -b backup` when `home-manager` isn't on PATH yet.

Home configs themselves are composition roots that import a rice, desktop modules, and script modules — same pattern as host configs.

## Conventions worth knowing

- The working directory is `/persist/source-of-truth` and several scripts hard-code that path. Don't move the tree without updating `programs.nh.flake` in `hosts/tempest/default.nix` and `hosts/orchid/default.nix`, plus `scripts/update-home.nix`.
- Secrets go through `sops-nix` (imported in `homes/orchid.nix`). Don't commit raw secrets.
- Host `specialArgs` / `extraSpecialArgs` inject `inputs` and `hostname` — modules expect these available.
- Nix formatting: 2-space indent (alejandra / nixpkgs-fmt if available). Shell scripts use explicit `set -euo pipefail` where relevant, or plain `#!/bin/sh` for simple wrappers (e.g. `build-vm`, `tempest-install`).
- Commit style (per `AGENTS.md` and recent log): short, lowercase summaries, one logical change per commit, mention the host or module touched.
