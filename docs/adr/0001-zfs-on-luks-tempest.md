# tempest: ZFS-on-LUKS, tmpfs-root impermanence, lanzaboote + TPM2(PCR 7)

Status: accepted (2026-06-01)

## Context

tempest (Framework AMD AI 300 laptop) is being reinstalled onto a new SSD,
moving its root filesystem from btrfs to ZFS while preserving four properties
it relies on: full-disk encryption, silent TPM2 auto-unlock, impermanence
(ephemeral root), and Secure Boot via lanzaboote. These interact in non-obvious
ways, so the layout is deliberate, not incidental.

## Decision

- **ZFS on LUKS**, not ZFS-native encryption. Disk stack is
  `LUKS2 → LVM → { swap LV, root LV → zpool rpool }`.
- **Keep the LVM layer** so swap stays a plain LV (never a zvol) and there is a
  single LUKS container → a single TPM2 enrollment.
- **tmpfs root** for impermanence (unchanged from btrfs); only `/nix`,
  `/persist` and `/var/lib/sbctl` are ZFS datasets. No on-disk root dataset and
  no blank-snapshot rollback.
- **TPM2 auto-unlock sealed to PCR 7 only**, enrolled *after* Secure Boot is on.
- **lanzaboote** with a single 2 GB ESP at `/boot`.
- **CachyOS LTS kernel** (`linuxPackages-cachyos-lts-lto-zen4`).
- **Install-time geometry (frozen at format):** 4 GB ESP; NVMe reformatted to a
  4K LBA (`nvme format -b 4096`) with LUKS `--sector-size 4096` and ZFS
  `ashift=12` for native 4K alignment; 40 GB swap with the root LV at **95%** of
  the VG (leaving ~5% headroom so swap can grow later — ZFS can't shrink);
  `/home` as its own dataset (`rpool/persist/home`).

## Why

- **TPM2 is a LUKS2 feature, not a ZFS one.** `systemd-cryptenroll` stores its
  key in a LUKS2 token; ZFS-native encryption has no equivalent and would need a
  hand-rolled "seal a keyfile to the TPM, unseal it in initrd" dance. Keeping
  LUKS makes the existing silent unlock carry over verbatim. Native encryption's
  payoff (raw `zfs send -w` to untrusted targets) is moot — backups are
  borg-over-SSH, not `zfs send`.
- **Swap must never be a zvol under hibernation** (OpenZFS can deadlock swapping
  to its own pool) and the hibernation key must be stable. Keeping LVM lets swap
  stay a plain, TPM-unlocked LV, so hibernation works exactly as before with
  still only one LUKS container to enroll.
- **tmpfs root** is already battle-tested here and needs no initrd rollback
  hook; root barely uses RAM (mostly symlinks into `/nix` and bind-mounts from
  `/persist`).
- **PCR 7 only** ties auto-unlock to "booted with my Secure Boot keys active"
  while surviving the constant churn of kernel/generation updates (PCR 4/9/11)
  and most firmware updates (PCR 0). Enrolling *after* SB is enabled is
  mandatory because turning SB on changes PCR 7.
- **CachyOS LTS** because ZFS is an out-of-tree module; nixpkgs hard-fails to
  evaluate when the kernel outruns OpenZFS support, which the bleeding-edge
  `-latest` CachyOS kernel routinely does. LTS keeps the CachyOS/BORE patches +
  scx scheduler on a base ZFS supports.

## Consequences

- Kernel bumps on tempest are constrained to what `zfs_unstable` supports; stay
  on the `-lts` CachyOS variant.
- Re-enrolling TPM2 (`systemd-cryptenroll --wipe-slot=tpm2` + re-add) is needed
  after any change to Secure Boot keys/state; the LUKS passphrase is the
  permanent fallback.
- Root-on-ZFS hibernation is "supported, use at your own risk" per OpenZFS, even
  with swap off-pool.
- Secure Boot signing keys live in a dedicated `rpool/sbctl` dataset, isolated
  from the `/persist` backup scope.

## Rejected alternatives

- **ZFS-native encryption** — loses turnkey TPM2 unlock; rougher correctness
  history; its headline feature (raw encrypted send) is unused here.
- **Blank-snapshot rollback root** — more initrd machinery than tmpfs for no
  gain on this box.
- **PCR 0/4 binding** — breaks unlock on every firmware/kernel update.
- **PCR 11 signed-policy** — strongest, but the most ways to brick unlock during
  the rebuild; deferred.
- **Two LUKS partitions (no LVM)** — two TPM enrollments for no functional gain
  on a single disk.
