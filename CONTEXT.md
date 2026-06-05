# Context glossary

Canonical language for this repo. Definitions only — no implementation detail.

## Backups (tempest)

tempest keeps a 3-2-1 backup. Three legs, each with its own meaning of "ran":

- **borg (offsite)** — daily encrypted backup of `/home/irene` to the Hetzner
  storagebox. Expected to run every day.
- **syncoid (USB)** — ZFS replication of the irreplaceable datasets onto an
  external USB pool. Runs only when the drive is attached; the drive is
  normally unplugged.
- **sanoid (local)** — on-NVMe snapshots for instant rollback. Not a remote copy.

### Backup states

- **failed** — a backup leg *ran and errored*. This is the only condition that
  raises an alarm (the **health indicator** in the bar goes red). It is a latched state: it persists
  until the next successful run of that leg clears it. The syncoid (USB) leg
  also counts as failed if, after replicating, the backup pool reports
  unhealthy (see *integrity scrub* — the run can only inspect the SSD while the
  drive is attached).
- **drive absent** — the USB drive is not plugged in, so the syncoid leg has
  nothing to do and finishes cleanly. This is **not** a failure and raises no
  alarm. (A deliberate consequence: an unplugged drive can let the USB copy age
  silently — that staleness is intentionally *not* surfaced.)
- **healthy** — every leg's last run either succeeded or was a clean no-op.

### Pool health

- **integrity scrub** — a full ZFS scrub of a pool to detect/repair silent
  corruption. `rpool` (internal) is scrubbed weekly and its health is shown
  always (the health indicator in the bar). The external **backup** pool can only be scrubbed while the
  drive is attached, so its scrub rides along with a backup run on a *stale*
  cadence (skipped if scrubbed recently), and an unhealthy result fails that
  run rather than showing as its own always-on indicator.

## Desktop (rices)

- **rice** — a self-contained desktop environment: the Wayland compositor
  (niri / hyprland) plus its shell furniture — bar, launcher, notifications,
  lockscreen, terminals, theming, idle handling, wallpaper, window rules. A
  rice defines *what the desktop is and how it behaves*; it is meant to be
  independent of the machine it runs on. tempest's rice is niri; orchid's is
  estradiol.
- **machine policy** — per-host facts a rice must not bake in: monitor
  identities and layout (the kanshi profiles), and the systemd units a bar
  readout watches (e.g. the backup-health indicator). These belong with the
  host, not the rice. A rice consumes them as inputs, and degrades cleanly
  (a readout collapses to nothing) when the thing it would describe is absent
  on a given machine.
