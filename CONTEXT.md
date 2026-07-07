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

## Sleep & resume (tempest)

tempest's "resume from sleep" has historically meant two *independent* failure
modes fused into one complaint. The glossary keeps them apart.

- **s2idle** — tempest's only sleep state. The firmware exposes no S3 and ZFS
  root rules out hibernation, so "suspend" always means s2idle (S0ix); there is
  no deeper state to fall back to. _Avoid_: "deep sleep", S3, "suspend-to-RAM"
  (each implies a hardware state this machine doesn't have).
- **the hang** — the failure where tempest enters s2idle and never comes back:
  the CPU never resumes, nothing is logged past suspend entry, and the only
  recovery is holding the power button. Intermittent (roughly one cycle in five)
  and only ever observed while docked. This is "resume doesn't work" in the
  literal sense — a dead machine.
- **redock** — the *separate* failure where resume succeeds but the Thunderbolt
  dock, though powered and authorized, brings nothing back behind it (USB,
  ethernet, and the external displays all ride its tunnels) until those tunnels
  are rebuilt. The machine is alive; only the dock is dead.
  _Flagged ambiguity_: "the resume is broken" has meant **the hang** and
  **redock** interchangeably. They are different — one is a dead box, the other
  a live box with a dead dock — with different causes and different fixes.
- **keep-awake** — a deliberate utility to hold off idle/lid/sleep while a
  long-running task finishes. A convenience tool, _not_ a workaround for **the
  hang**.

## Desktop (rices)

- **rice** — a self-contained desktop environment: the Wayland compositor
  (niri / hyprland) plus its shell furniture — bar, launcher, notifications,
  lockscreen, terminals, theming, idle handling, wallpaper, window rules. A
  rice defines *what the desktop is and how it behaves*; it is meant to be
  independent of the machine it runs on. tempest's rice is niri; orchid's is
  estradiol.
- **machine policy** — per-host facts a rice must not bake in: monitor
  identities and layout (the kanshi profiles), the systemd units a bar
  readout watches (e.g. the backup-health indicator), and per-host audio
  correction (a speaker DSP/EQ profile tuned to a specific laptop's drivers).
  These belong with the
  host, not the rice. A rice consumes them as inputs, and degrades cleanly
  (a readout collapses to nothing) when the thing it would describe is absent
  on a given machine.
- **scratchpad** — a window kept running but parked out of view, summoned by a
  keybind as a floating overlay onto whatever workspace is focused and
  dismissed with the same key. On tempest (niri) the canonical tenant is
  Telegram (Mod+T). _Avoid_: special workspace, drop-down, quake terminal.
  _Flagged ambiguity_: niri has no native scratchpad and no hidden workspace,
  so unlike Hyprland's `togglespecialworkspace` this is **emulated** — the
  parked window still lives on a real (bottom-most) workspace and remains
  visible in the overview. "Scratchpad" here names that emulated behaviour, not
  a first-class compositor feature.
