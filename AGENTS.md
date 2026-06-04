# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` and `flake.lock` define Nix inputs and system outputs.
- `hosts/` contains per-machine NixOS configs (e.g., `hosts/orchid/`, `hosts/tempest/`).
- `homes/` holds Home Manager configs per user/host (e.g., `homes/orchid.nix`).
- `modules/`, `services/`, `hardware/`, and `desktop/` provide reusable Nix modules.
- `disks/` contains Disko layouts; `packages/` contains custom package definitions.
- `rices/` holds UI theming, waybar, fonts, and wallpaper assets.
- `scripts/` and top-level `*.sh` are operational helpers (apply, format, install).

## Build, Test, and Development Commands
- `nixos-rebuild switch --flake '.#<host>' --sudo`: apply a host configuration (used by `scripts/system-apply.nix`).
- `nix flake update`: update flake inputs (the old `./update-flakes.sh` wrapper was removed).
- `./build-vm`: build the non-destructive `tempest-vm` QEMU clone (`system.build.vmWithDisko`); run `./result/bin/disko-vm`.
- `./tempest-format`: format/mount disks for the `tempest` layout (destructive).
- `./tempest-install`: install NixOS using the `tempest` Disko layout.

## Coding Style & Naming Conventions
- Nix files use two-space indentation; keep attribute sets aligned and readable.
- Prefer concise, descriptive file names (e.g., `hosts/<name>/system/networking.nix`).
- Format Nix with `alejandra` or `nixpkgs-fmt` when available.
- Shell scripts use `#!/bin/sh` or `#!/usr/bin/env bash` and keep flags explicit.

## Testing Guidelines
- No automated test framework is defined in this repository.
- Validate changes by building or switching the relevant host:
  `nixos-rebuild switch --flake '.#tempest' --sudo`.

## Commit & Pull Request Guidelines
- Recent commits use short, lowercase summaries (e.g., `update`, `cleanup things`).
- Keep commits focused on one logical change; mention the host or module touched.
- PRs should describe the target host(s), the intent, and any risky operations.
- Include screenshots for UI changes under `rices/` or `desktop/` when applicable.

## Security & Configuration Tips
- Disk operations (`tempest-format`, `tempest-install`) are destructive; double-check target disks.
- Host secrets may be managed via `sops-nix`; avoid committing raw secrets.
- Review `hosts/<name>/system/security.nix` before changing security-sensitive settings.
