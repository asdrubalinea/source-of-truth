# tempest: Time-Machine-style local backup via ZFS replication to an external USB SSD

Status: accepted (2026-06-02)

## Context

tempest now runs root-on-ZFS (see ADR 0001). A new external USB SSD is to serve
as a local backup so the machine can recover if the internal NVMe fails. The ask
was an "easy, Time-Machine-like" recovery: browse history, restore a point in
time, get everything back without a fragile rebuild. sanoid already takes local
snapshots of `rpool/persist` and `rpool/persist/home`; borg already ships
`/home/irene` offsite to a Hetzner storagebox.

## Decision

- **Replicate with syncoid (`zfs send`/`receive`), not a second borg repo.** A
  oneshot orchestrator (`hosts/tempest/system/backup-external.nix`) imports the
  external pool, `syncoid`s `rpool/persist` and `rpool/persist/home` onto it,
  prunes per a deep-retention policy, and exports.
- **Encrypt the external with ZFS-native encryption + a passphrase key file**
  (`keyformat=passphrase`, `keylocation=file:///persist/backup/backup.key`), not
  LUKS. Single layer, no LVM, import + `zfs load-key` is the whole unlock.
- **Pool imported only for the run, exported after** (`cachefile=none`), under an
  altroot (`/mnt/backup`) so replicated `/persist` mountpoints never collide
  with the live ones.
- **Trigger on plug-in** via a udev rule matching the `zfs_member` partition
  labelled `backup`, plus a daily fallback timer that no-ops when the drive is
  absent.
- **Deep retention on the backup** (prune-only sanoid: 30 daily / 16 weekly / 24
  monthly) — the external is the long archive; the NVMe keeps only short local
  history.
- **`httm`** installed for the file-level browse/restore UX.

## Why

- **ZFS replication beats borg for the local disk-failure case.** It is
  block-level incremental (a daily run after the seed is seconds, not a file
  re-walk), it preserves every sanoid snapshot so any point in time is browsable
  (`httm` or `.zfs/snapshot/`), and recovery is a single `zfs send` of the whole
  pool state back. Borg stays as the *offsite* leg — dedup + client-side
  encryption over an untrusted transport is what it is good at; re-walking the
  filesystem locally is not. Together: 3-2-1 (NVMe + external + Hetzner).
- **ZFS-native encryption over LUKS here** — the opposite of ADR 0001's root
  choice, deliberately. ADR 0001 kept LUKS for *turnkey TPM2 unlock* and noted
  raw `send -w` was unused. A hand-plugged backup drive needs neither: there is
  no TPM unlock requirement, and the source datasets are plaintext at the ZFS
  layer (encrypted by LUKS below), so syncoid sends a normal non-raw stream that
  the backup pool re-encrypts at rest under its own key. One layer is simpler
  and fully sufficient.
- **Import/export per run** because USB bridges reset and UAS can drop the
  device; a pool imported only transiently can never be faulted live, and
  `cachefile=none` keeps it out of the boot import set entirely.

## Consequences

- **The passphrase must live somewhere other than `/persist`.** The key file is
  on the very NVMe the backup protects; if that disk dies and the passphrase
  exists only there, the backup is unrecoverable. It is also stored in
  vaultwarden (self-hosted) / printed. Recovery uses `zfs load-key -L prompt`.
- Plug the drive in at least every few weeks: incrementals ride the common
  snapshot, and `rpool/persist` weeklies are kept 4 weeks (system/zfs.nix). A
  longer gap forces a full reseed.
- `/nix` (reproducible) and `rpool/sbctl` (regenerable Secure Boot keys) are not
  backed up by design.
- Scrub of the backup pool is manual (the auto flow exports immediately):
  `sudo tempest-backup-browse` then `sudo zpool scrub backup` while attached.

## Rejected alternatives

- **A second borg repo on the USB drive** — file-walk every run, worse
  full-system restore, no native point-in-time browsing. Wrong tool for the
  local leg.
- **LUKS-wrapped ZFS on the external** — uniform with root but an extra layer
  (and a destructive disko file pinned to one drive) for no benefit on a
  hand-plugged backup target.
- **Leave it always imported on a plain timer** — simplest, but a USB reset can
  fault a live pool, and runs fail noisily whenever the drive is detached.
