<div align="center">

# ❄️ source-of-truth

**One flake. Three machines. Zero snowflakes.** 🏳️‍⚧️

A personal [NixOS](https://nixos.org) monorepo wiring up a laptop, a desktop, and a
server — plus Home Manager for `irene` — from a single declarative tree.

[![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?logo=nixos&logoColor=white)](https://nixos.org)
[![Flakes](https://img.shields.io/badge/flakes-enabled-7EB1DD?logo=nixos&logoColor=white)](https://nixos.wiki/wiki/Flakes)
[![Home Manager](https://img.shields.io/badge/home--manager-standalone-41A6B5)](https://github.com/nix-community/home-manager)
![Hosts](https://img.shields.io/badge/hosts-3-blueviolet)
![License](https://img.shields.io/badge/license-do_whatever-lightgrey)

</div>

> [!IMPORTANT]
> This tree **must** live at `/persist/source-of-truth` — the path is load-bearing.
> Several scripts and wrappers hard-code it. Don't move it without updating them.

---

## 🖥️ The fleet

| Host | What it is | Highlights |
|------|------------|------------|
| **`tempest`** ⛈️ | Framework AMD AI 300 laptop | `disko` + `impermanence` + `lanzaboote` (secure boot) + `ucodenix`, CachyOS kernel, ZFS, [niri](https://github.com/YaLTeR/niri) scrolling WM |
| **`orchid`** 🌸 | Desktop workstation | standalone Home Manager, `estradiol` rice |
| **`hydra`** 🐍 | QEMU guest server | runs Caddy, Grafana, Glance — the always-on box |

> `hosts/router.nix` is a single-file router variant that's drafted but **not** currently
> wired into `nixosConfigurations`.

---

## 🚀 Quick start

Everything is driven from the flake root against `.#<host>`. Wrapper scripts `pushd`
into `/persist/source-of-truth` so `.#` resolves to the current host by hostname.

```sh
# Apply a host's NixOS config (current host)
system-apply              # → nixos-rebuild switch --flake '.#' --sudo

# Apply standalone Home Manager
home-manager switch --flake '.#irene@tempest'
user-apply                # tempest wrapper, runs the above with -b backup

# On tempest, a full system change = BOTH:
system-apply && user-apply
```

> [!TIP]
> On **tempest**, NixOS and Home Manager are two separate activations.
> Run `system-apply` *then* `user-apply` to land a complete change.

### Housekeeping

```sh
update-home        # tempest: bump only the HM-side flake inputs
./update-flakes.sh # nix flake update — everything
system-clean       # drop old generations, GC, optimize the store
```

> [!CAUTION]
> The disk helpers are **destructive** — they wipe and reformat the target device.
> Only run them when actually installing.
>
> ```sh
> ./tempest-format.sh    # disko destroy,format,mount on disks/tempest.nix
> ./tempest-install.sh   # disko-install .#tempest → /dev/nvme0n1
> ```

---

## 🧭 Architecture

There is **no central "enable options" layer.** Every host's `default.nix` is a
composition root: an explicit `imports = [ … ]` list pulling from the shared trees.
Toggling a feature means editing that list — not flipping a global option.

```
flake.nix              # inputs, multi-channel overlay, nixosConfigurations + homeConfigurations
├── hosts/             # per-machine composition roots (tempest, orchid, hydra)
├── homes/             # Home Manager configs (irene@orchid, irene@tempest)
├── modules/           # cross-cutting system modules (nix, gaming, secure-boot)
├── hardware/          # opt-in hardware (audio, bluetooth, framework, pipewire, rocm, zfs, tlp)
├── services/          # à-la-carte NixOS services (borg, caddy, grafana, glance, syncthing…)
├── desktop/           # editor/terminal/app configs (helix, neovim, emacs, zed, tmux, fonts…)
├── rices/             # desktop environments — estradiol · hypr · niri
├── packages/          # custom derivations (pkgs.callPackage)
├── scripts/           # writeScriptBin wrappers (system-apply, battery, brightness…)
└── disks/             # disko layouts
```

### 🌊 Multi-channel nixpkgs

The `multiChannelOverlay` exposes several channels side-by-side, so you can reach for a
different one when unstable breaks something:

| Attribute | Channel |
|-----------|---------|
| `pkgs.*` (default) | `nixos-unstable` |
| `pkgs.stable.*` | `nixos-25.11` |
| `pkgs.trunk.*` | nixpkgs trunk |
| `pkgs.custom.*` | nixpkgs trunk |

Tempest's Home Manager builds from a **separate** `nixpkgs-home` input (also tracking
unstable), so `update-home` can advance the HM channel without disturbing the system
channel. Same overlays apply to both, so `pkgs.stable.foo` resolves identically everywhere.

Other global overlays: `emacs-overlay`, `niri`, `claude-code`, `nix-cachyos-kernel`,
plus a `helix` Steel-plugin build. `allowUnfree = true`.

---

## 💾 Backups (tempest)

A real **3-2-1** backup, three legs each with its own meaning of "ran" (see
[`CONTEXT.md`](./CONTEXT.md) for the full state machine):

- **borg** → daily encrypted offsite backup of `/home/irene` to a Hetzner storage box.
- **syncoid** → ZFS replication of irreplaceable datasets to an external USB pool (when attached).
- **sanoid** → on-NVMe snapshots for instant local rollback.

Only a leg that *ran and errored* raises the red waybar badge. An unplugged USB drive is
a clean no-op, not a failure.

---

## 📐 Conventions

- **Don't move the tree** — `/persist/source-of-truth` is hard-coded in several scripts.
- **Secrets** go through [`sops-nix`](https://github.com/Mic92/sops-nix). Never commit raw secrets.
- **Formatting** — 2-space indent, `alejandra` / `nixpkgs-fmt`.
- **Commits** — short, lowercase summaries; one logical change; mention the host/module touched.
- **No test framework** — validation is "does `nixos-rebuild` evaluate and switch cleanly."

See [`AGENTS.md`](./AGENTS.md) for the author-maintained guidelines and
[`CLAUDE.md`](./CLAUDE.md) for the agent-oriented map of the repo.

---

<div align="center">

*Built with ❄️ and stubbornness. Reproducible to the bit.*

</div>
