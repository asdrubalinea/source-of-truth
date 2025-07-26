# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a NixOS configuration repository using flakes, managing multiple hosts with different desktop environments and specialized "rices" (aesthetic configurations). The repository supports Framework laptop (tempest) and AMD desktop (orchid) configurations.

## Common Commands

### System Configuration
```bash
# Apply system configuration (auto-detects current host)
nixos-rebuild switch --flake '.#' --use-remote-sudo

# Apply specific host configuration  
nixos-rebuild switch --flake '.#tempest' --use-remote-sudo
nixos-rebuild switch --flake '.#orchid' --use-remote-sudo

# Apply home-manager configuration
home-manager switch --flake '.#irene@orchid'
home-manager switch --flake '.#irene@tempest'
```

### Installation & Maintenance
```bash
# Format disks (tempest only)
./tempest-format.sh

# Install system (tempest only) 
./tempest-install.sh

# Update flake inputs
./update-flakes.sh

# System cleanup (when installed)
system-clean
```

## Architecture

### Core Directory Structure
- **`flake.nix`** - Main entry point, defines all hosts and configurations
- **`hosts/`** - Host-specific system configurations (tempest.nix, orchid.nix, router.nix)
- **`homes/`** - Home Manager user configurations
- **`disks/`** - Disko disk partitioning configurations
- **`rices/`** - Desktop aesthetic/theming configurations (estradiol/, feet/, hypr/)

### Configuration Categories
- **`hardware/`** - Hardware-specific modules (framework.nix, zfs.nix, rocm.nix)
- **`desktop/`** - Desktop environment configs (emacs/, neovim/, gnome.nix)
- **`services/`** - System services (grafana/, caddy.nix, syncthing.nix)
- **`scripts/`** - Custom utility scripts installed as packages

### Host Specifications
- **tempest**: Framework laptop with LUKS+BTRFS+impermanence, secure boot, Hyprland
- **orchid**: AMD desktop with ZFS, virtualization, Docker, development services
- **router**: Minimal router configuration

### Key Features
- **Impermanence**: Tempest uses tmpfs root with selective persistence via `/persist`
- **Multi-channel**: Uses nixpkgs stable, unstable, trunk, and custom channels
- **Modular design**: Heavily modularized with imports and options
- **Desktop ricing**: Multiple aesthetic configurations with Stylix theming
- **Hardware optimization**: Framework-specific and AMD GPU virtualization support

## Development Workflow

1. Edit configurations in appropriate directory
2. Test with `nixos-rebuild switch --flake '.#hostname'` 
3. For home configs: `home-manager switch --flake '.#user@host'`
4. Update dependencies with `./update-flakes.sh`
5. Clean up with `system-clean`

## IMPORTANT: Configuration Application Policy

**NEVER automatically apply NixOS configurations.** Always let the user run `nixos-rebuild` commands themselves. Claude should only edit configuration files and inform the user that they need to apply the changes manually.

## Important Patterns

- Host configurations import from multiple modules (hardware/, services/, desktop/)
- Rice configurations define complete desktop themes and are imported by hosts
- Scripts are defined as Nix packages and installed system-wide
- Secrets and sensitive configs may be in `/persist` or managed separately
- Disko configurations handle disk partitioning and encryption setup