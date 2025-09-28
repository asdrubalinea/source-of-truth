# Repository Guidelines

## Project Structure & Module Organization
Core NixOS entries live in `flake.nix`, which wires hosts under `hosts/` (e.g. `hosts/tempest/default.nix`) and user environments under `homes/`. Shared building blocks sit in `modules/`, `services/`, `packages/`, and `desktop/`, while hardware-specific pieces live in `hardware/` and disk layouts in `disks/`. Theming and Hyprland/Niri tweaks are kept in `rices/`, and reusable helper binaries are defined in `scripts/`. Keep new files in the nearest existing module tree to keep host imports lean.

## Build, Test, and Development Commands
- `nix flake check` – evaluates all systems and home configurations; run after every change.
- `nixos-rebuild build --flake '.#<host>'` – builds a host configuration without switching; useful for CI-style verification.
- `nixos-rebuild switch --flake '.#<host>' --dry-run` – confirm activations before applying on the target machine.
- `home-manager switch --flake '.#irene@<host>' --dry-run` – validate user profiles.

## Coding Style & Naming Conventions
Use two-space indentation in Nix files and keep attribute sets alphabetised when feasible. Prefer lowercase, hyphenated filenames (`hosts/tempest/networking.nix`) and concise option names (`services.monitoring.enable`). Group imports by responsibility with short comments. Format Nix code with `alejandra` or `nixpkgs-fmt` (`nix fmt` honours the flake formatter) before committing, and keep inline comments brief but informative.

## Testing Guidelines
Every change must at least pass `nix flake check`. For host updates, share the relevant `nixos-rebuild build` or `--dry-run switch` output; for Home Manager tweaks, do the same with `home-manager ... --dry-run`. Desktop or theming adjustments should ship with a screenshot from the target rice. Avoid committing secrets—use `sops-nix` inputs or hashed placeholders under `passwords/`.

## Commit & Pull Request Guidelines
Recent history favours short, present-tense summaries (`fix boot`, `trunk update`). Follow that style, optionally prefixing the affected host (`tempest: sync virtualization`). Squash noisy WIP commits locally. Pull requests should call out affected hosts or modules, list the commands you ran, and attach before/after visuals for UI work. Link related issues when available and note any manual follow-up steps the deployer must run.

## Deployment Safety
Never auto-apply configurations from automation—provide instructions instead (`nixos-rebuild switch --flake '.#tempest'`). When touching disk layouts or secure boot settings, flag the risk so the maintainer can schedule downtime.
