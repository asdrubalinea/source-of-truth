# tempest: Time-Machine-style local backup via ZFS replication to an external USB SSD

Status: accepted (2026-06-02); amended (2026-08-11) — the backup scrub became
automatic, result notifications and an on-demand verify command were added, and
the "long gap forces a reseed" consequence turned out to be wrong (see the
Amendment section at the end).

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
- A long gap between plug-ins does **not** force a reseed (this bullet said the
  opposite until 2026-08-11 — see the Amendment). The common base is syncoid's
  own `syncoid_<host>_<ts>` snapshot, and sanoid's autoprune only expires
  `autosnap_*`, so it is never pruned no matter how long the drive is away.
  Exactly one is kept per dataset; syncoid deletes the previous after each
  successful run. The real reseed trigger is destroying that snapshot by hand.
  Note it is a snapshot and **not** a bookmark — `--create-bookmark` is opt-in
  in syncoid and is not passed, so `zfs list -t bookmark` is empty and there is
  no second fallback if the sync snapshot is lost.
- `/nix` (reproducible) and `rpool/sbctl` (regenerable Secure Boot keys) are not
  backed up by design.
- Scrub of the backup pool rides along with a backup run (scrub-if-stale, 30d,
  stamped as the `tempest:scrubbed` user property on the pool so the cadence
  travels with the drive). The run is the only window the pool is imported, so
  on a scrub run the drive must stay attached — `zpool scrub -w` blocks and the
  oneshot has no timeout.
- **A replication that succeeds can still fail the unit.** The orchestrator ends
  with a `zpool status -x` gate and exits 1 on an unhealthy pool, so the syncoid
  leg shows as failed even though the data was sent. That is deliberate — the
  alternative is a green unit sitting on a rotting drive — but it means "unit
  failed" here does not imply "backup did not happen".
- **A faulted drive hangs the unit indefinitely.** The oneshot sets no
  `TimeoutStartSec`, and a suspended pool blocks `zpool`/`zfs` calls forever
  rather than erroring, so the unit can sit in `activating` with sustained I/O
  pressure and no CPU use. `tempest-backup-verify` wraps every call in
  `timeout`; the orchestrator does not.
- Three operator commands, all root: `tempest-backup-browse` (import + load key
  + mount under `/mnt/backup` for `httm`), `tempest-backup-eject` (export), and
  `tempest-backup-verify` (below). Browse is the only one that loads the key.
- `tempest-backup-verify` answers "is the backup current and intact?" on demand:
  it imports **read-only** and **without loading the encryption key** (snapshot
  names, creation times and pool health are unencrypted metadata), so a
  verification can neither modify the drive nor expose plaintext. It reports
  what the last scrub found — being read-only, it cannot scrub or repair.
  Note it cannot report pool fill either: a read-only import never loads the
  metaslab space maps, so `zpool list` reports `ALLOC 0 / 0%` however full the
  pool is. It reads per-dataset `used` instead and refuses to print a pool
  percentage. Measuring true fill needs a read-write import.
- Results surface as desktop notifications (`packages/backup-notify.nix`):
  failure via `OnFailure=` on the unit, success emitted inline by the
  orchestrator so a plug-less timer tick — which no-ops and exits 0 — stays
  silent. This replaced the Noctalia bar readout that ADR 0003 describes, after
  v5's `custom_button` lost the ability to poll a script.

## Rejected alternatives

- **A second borg repo on the USB drive** — file-walk every run, worse
  full-system restore, no native point-in-time browsing. Wrong tool for the
  local leg.
- **LUKS-wrapped ZFS on the external** — uniform with root but an extra layer
  (and a destructive disko file pinned to one drive) for no benefit on a
  hand-plugged backup target.
- **Leave it always imported on a plain timer** — simplest, but a USB reset can
  fault a live pool, and runs fail noisily whenever the drive is detached.

## Amendment (2026-08-11)

Three changes since acceptance, plus one correction.

**The backup scrub became automatic.** As accepted, scrubbing the external was a
manual `tempest-backup-browse` + `zpool scrub backup`, on the reasoning that the
auto flow exports immediately and so leaves no window. In practice a manual step
gated on remembering it is a step that does not happen. The orchestrator now
scrubs *inside* the run when the last one is older than 30 days, stamping
`tempest:scrubbed` on the pool as a user property — deliberately on the pool
rather than in host state, so the cadence travels with the drive and is readable
exactly when it matters. Cost: on a scrub run the drive must stay attached for
potentially hours, because `zpool scrub -w` blocks.

**Results became push notifications.** ADR 0003's Noctalia bar readout was a
*pull* — the bar polled a script for storage/backup health. Noctalia v5's
`custom_button` can no longer poll, so that readout was dropped and each backup
unit now pushes a notification as it finishes (`packages/backup-notify.nix`).

**An on-demand verify command was added** (`tempest-backup-verify`). The
orchestrator's `zpool status -x` gate only inspects the pool during a run, which
answers "was it healthy when the backup happened?", not "is my backup good right
now?". The verify path imports read-only and never loads the key, so asking the
question cannot damage or decrypt the thing being asked about.

**Correction: "a longer gap forces a full reseed" was wrong.** The original
consequence tied the incremental base to `rpool/persist` weeklies expiring after
4 weeks. That is not the base. syncoid takes its own `syncoid_<host>_<ts>`
snapshot, and sanoid's autoprune only expires `autosnap_*` — so the common base
survives an arbitrarily long gap and no reseed is forced. Verified 2026-08-11:
exactly one `syncoid_` snapshot per source dataset, oldest surviving history on
the backup reaching to 2026-06-02.

Worth knowing that the same check found `zfs list -t bookmark` empty across
`rpool`. A code comment had claimed syncoid creates a bookmark alongside the sync
snapshot "so incrementals survive even if a source snapshot is later pruned";
`--create-bookmark` is opt-in and is not passed, so that safety net does not
exist. The comment has been corrected. Passing `--create-bookmark` would make the
claim true and is the obvious hardening if the sync snapshot ever gets destroyed
by accident — untaken for now, since nothing prunes it today.
