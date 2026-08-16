# Repository Guidelines

## Project Structure & Module Organization
- `flake.nix` and `flake.lock` define Nix inputs and system outputs.
- `hosts/` contains per-machine NixOS configs (e.g., `hosts/orchid/`, `hosts/tempest/`).
- `homes/` holds Home Manager configs per user/host (e.g., `homes/orchid.nix`).
- `modules/`, `services/`, `hardware/`, and `desktop/` provide reusable Nix modules.
- `disks/` contains Disko layouts; `packages/` contains custom package definitions.
- `rices/` holds whole desktop environments — shell furniture, theming, fonts,
  wallpaper, plus the compositor(s) that run under them. `ember` (tempest) and
  `estradiol` (orchid). ember is one rice with two *compositor layers*,
  `rices/ember/compositors/{niri,mango}/`: both are installed and the session is
  picked at the greeter per login (ADR 0012). No waybar: tempest's shell is
  Noctalia, and the one remaining waybar process is the marquee's strut.
- `docs/` holds long-form notes and `docs/adr/` the decision records — read the
  relevant ADR before changing anything it covers.
- `scripts/` holds the `writeScriptBin` / `writeShellApplication` helpers. The
  top-level executables have no extension: `build-vm`, `tempest-format`,
  `tempest-install`.
- `misc/` (fish + shell aliases, imported by both home configs) and `passwords/`
  also exist. Helix's config lives in `desktop/helix.nix` + `desktop/helix/`
  (Steel cogs) — there is no top-level `helix/`.

## Build, Test, and Development Commands
- `nh os switch` / `nh home switch -b backup` (or `apply` for both): activate the current host's NixOS and Home Manager configs. `nh` is enabled per host via `programs.nh.flake`, which sets `NH_FLAKE`.
- `nix flake update`: update flake inputs (the old `./update-flakes.sh` wrapper was removed).
- `./build-vm`: build the non-destructive `tempest-vm` QEMU clone (`system.build.vmWithDisko`); run `./result/bin/disko-vm`.
- `./tempest-format`: format/mount disks for the `tempest` layout (destructive).
- `./tempest-install`: install NixOS using the `tempest` Disko layout.

## Coding Style & Naming Conventions
- Nix files use two-space indentation; keep attribute sets aligned and readable.
- Prefer concise, descriptive file names (e.g., `hosts/<name>/system/networking.nix`).
- Format Nix with `alejandra` or `nixpkgs-fmt` when available.
- Small shell wrappers use `#!/bin/sh` or `#!/usr/bin/env bash` and keep flags
  explicit. The larger ones (`scripts/cage.sh`, `scripts/sitrep.sh`) are
  `writeShellApplication` bodies: no shebang of their own, and **shellcheck runs
  at build time** — a warning-level finding fails the build, so fix it rather
  than working around it.

## Testing Guidelines
- No automated test framework is defined in this repository.
- Validation is "does it evaluate and switch on the relevant host". **The author
  runs every rebuild.** An agent working in this tree must not run `nh os` /
  `nh home` / `apply` / `nixos-rebuild` / `home-manager switch` — make the edit
  and stop. (`nixos-rebuild` is not the tool here in any case; `nh` is.)
- Cheap checks an agent *may* run: `nix-instantiate --parse <file>` for syntax,
  `nix flake check --no-build`, and `shellcheck` on `scripts/*.sh`.
- For anything needing a real build, `./build-vm` produces the non-destructive
  `tempest-vm` — but it is still a build, so it is the author's to run too.

## Commit & Pull Request Guidelines
- Short, lowercase summaries, scoped to what was touched — e.g. `backup-external:
  name the unit once`, `niri: lift the last machine facts out of the rice`,
  `docs: refresh the module inventory`. (Older commits in the log are bare
  `update` / `cleanup things`; don't copy those.)
- Keep commits focused on one logical change; mention the host or module touched.
- No agent attribution trailers (`Co-Authored-By:`, `Generated with …`) — commits
  in this repo read as author-written.
- PRs should describe the target host(s), the intent, and any risky operations.
- Include screenshots for UI changes under `rices/` or `desktop/` when applicable.

## Security & Configuration Tips
- Disk operations (`tempest-format`, `tempest-install`) are destructive; double-check target disks.
- Host secrets may be managed via `sops-nix`; avoid committing raw secrets.
- Review `hosts/<name>/system/security.nix` before changing security-sensitive settings.
