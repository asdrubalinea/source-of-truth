# zephyr (Raspberry Pi 3B+) boots the mainline kernel from a generic aarch64 SD image

Status: accepted (2026-06-08)

## Context

`zephyr` is a new host: a Raspberry Pi 3B+ (`aarch64-linux`), headless,
always-on, installed with no interactive installer — the image is built on
tempest, flashed to an SD card, and boots straight into a finished config (see
also the binfmt build path in `hosts/tempest/system/virtualization.nix`).

There are three credible ways to get a bootable NixOS onto a Pi 3:

1. **Mainline, generic SD image** — `installer/sd-card/sd-image-aarch64.nix`
   from nixpkgs. Default nixpkgs kernel, `generic-extlinux-compatible` + U-Boot,
   Raspberry Pi firmware + Pi 3/4 device trees baked into the image's firmware
   partition. This is exactly the image NixOS publishes for aarch64.
2. **nixos-hardware's `raspberry-pi-3` module** — already an input, so "free".
3. **`raspberry-pi-nix`** (nix-community) — a vendor kernel + firmware + device
   tree overlay stack, a new flake input.

The decision matters because it sets the kernel and boot stack for the host and
is annoying to swap later, and because the build runs under qemu emulation on an
x86_64 machine — so anything *not* in the binary cache gets compiled under
emulation.

## Decision

`zephyr` imports **`(modulesPath + "/installer/sd-card/sd-image-aarch64.nix")`
and nothing else** for its boot/kernel stack. It runs the **default nixpkgs
(mainline) kernel**. No disko (the sd-image module partitions itself and the
root ext4 auto-expands on first boot).

Explicitly **not** used:

- **`nixos-hardware.nixosModules.raspberry-pi-3`.** Despite being a "free"
  already-present input, it pins a *vendor* kernel
  (`boot.kernelPackages = linuxPackagesFor (callPackage ../common/kernel.nix {
  rpiVersion = 3; })`). That both contradicts the mainline choice and is an
  uncached `callPackage` — under tempest's binfmt emulation it would mean
  compiling an entire ARM kernel under qemu on every change.
- **`raspberry-pi-nix`.** A heavier vendor stack (Pi-foundation kernel,
  firmware, device-tree overlays), a second flake input to tend, and aimed
  squarely at Pi 4/5/CM4 GPIO/camera workloads — none of which `zephyr` has.

## Why

- **Cache coverage.** The default aarch64 kernel and the rest of the closure are
  built by `cache.nixos.org`, so emulation only touches the handful of local
  derivations. A vendor kernel is not cached → full ARM kernel compile under
  qemu. This is the dominant practical reason.
- **Fewest moving parts.** The generic image already carries U-Boot + Pi
  firmware + Pi 3/4 device trees and boots a 3B+ unattended. No new input, no
  vendor module.
- **A headless base needs none of the vendor extras** — no camera (CSI), no HAT
  device-tree overlays, no GPU bits. The one real loss (CPU-frequency scaling,
  some HAT support) is irrelevant to "an always-on box I ssh into".

## Consequences

- Mainline drops vendor-kernel hardware support: CSI camera, certain HATs, the
  VideoCore GPU stack, CPU-freq scaling. All acceptable for a headless node.
- If `zephyr` later grows a workload that genuinely needs GPIO/camera/overlays,
  the path back is `raspberry-pi-nix` — and that switch is itself surprising and
  hard-to-reverse enough to warrant its own ADR at that time.
- The host carries `nixpkgs.overlays = [ multiChannelOverlay ]` only — the
  desktop overlays (niri/emacs/claude-code/cachyos) are irrelevant to a headless
  ARM base and several don't build cleanly cross-arch, so they are deliberately
  not applied here.

## Rejected alternatives

- **nixos-hardware `raspberry-pi-3`** — vendor kernel + uncached compile under
  emulation; defeats the cache rationale. (See above.)
- **raspberry-pi-nix** — heavier, new input, vendor kernel, aimed at hardware
  features `zephyr` doesn't use.
- **Cross-compilation / building on the Pi** — orthogonal to the boot stack;
  decided separately in favour of binfmt emulation on tempest + the cache.
