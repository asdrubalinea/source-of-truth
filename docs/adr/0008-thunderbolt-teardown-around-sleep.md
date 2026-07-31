# Proactively tear down Thunderbolt around s2idle instead of repairing it on resume

Status: accepted, provisional (2026-06-28; extended 2026-07-01) — a bet that the
dead-on-resume hang is in the dock/USB4 suspend path; revisit if hangs survive
(see Consequences). The hang held, but the external DP failing to relight on long
resumes remained — see "Update (2026-07-01)" at the end.

## Context

tempest's only sleep state is s2idle (the firmware exposes no S3 and ZFS root
forces `nohibernate` — see `hardware/framework.nix` and ADR 0001). Two distinct
failures rode on that, which had been fused into one complaint ("resume sucks"):

- **the hang** — intermittently (≈1 suspend in 5) the machine entered s2idle and
  never came back: no `PM: suspend exit` was ever logged and the only recovery
  was holding the power button. Across eight boots of journal history *every*
  observed hang happened while **docked** (CalDigit TS3), three of four within
  ~15–45 s of the dock coming fully up. There is no undocked-suspend sample to
  compare against, because tempest is used mostly docked at a desk.
- **redock** — on the resumes that *did* survive, the dock read as authorized
  but re-enumerated nothing behind it (USB, ethernet, DP-over-TB tunnels) until
  a replug.

The previous fix, the `tb-redock` systemd service, tried to *repair* the dock
after resume: a "surgical" tier-1 deauthorize/reauthorize with USB-count baseline
polling, escalating to a tier-2 Thunderbolt NHI PCIe unbind/rebind. The journal
showed tier-1 essentially never succeeded (0/9 and 0/5 in the two most recent
docked boots) — so in practice it was already doing a full NHI rebind on nearly
every resume. ~120 lines of commented shell to reliably trigger one operation.
And it did nothing for the hang (boot −6 hung on the first suspend before
`tb-redock` had ever run; boot −3 ran 9 tier-2 rebinds with zero hangs).

## Decision

Delete `tb-redock`. Take the USB4 controllers out of the suspend path entirely:
unbind **every** Thunderbolt host controller (NHI) *before* suspend and rebind it
*after* resume, via NixOS's symmetric `powerManagement.powerDownCommands` /
`powerUpCommands` (the `systemd/system-sleep` pre/post hook). The unbound NHIs
are recorded in `/run` so resume rebinds exactly them.

No retry, verify, or escalation logic — a clean tear-down/bring-up replaces the
post-hoc repair. We unbind all NHIs rather than resolving the dock's specific
domain (it has appeared on domain 1 and 2), which is simpler and harmless on a
mostly-docked machine.

Alongside it, enable `pm_debug_messages` (one `tmpfiles` rule) so a future hang
names the last device that suspended.

## Consequences

- The hang's suspected trigger — live dock/USB4 tunnels across s2idle — is gone,
  and the original `redock` re-enumeration failure is fixed by construction (a
  fresh rebind on every resume is the "replug equivalent").
- This is a **hypothesis test on the dock path**, not a proven cure. If hangs
  survive, the dock is cleared and the next suspect is the **MediaTek MT7925**
  Wi-Fi (`mt7925e`), connected at every suspend regardless of dock state;
  `pm_debug_messages` output in the persistent journal is the evidence to act on.
- No safety net: a rare failed rebind leaves the dock absent until a replug —
  accepted deliberately, in exchange for zero recovery cruft. It is never a hang.
- **Undocked** suspend reliability is explicitly out of scope (mostly-docked
  machine); there was no data to reason about it and it isn't a felt problem.

## Update (2026-07-01): the hang was real but masked a second failure — the external DP not relighting

The teardown held: no dead-on-resume hang has recurred. But the felt symptom
never went away, because two failures were still fused. The remaining one is
**not a hang** — the machine resumes fully (userspace back, `boltd` re-authorizes
the dock, `[tb-sleep] rebound` runs) but the **external DP monitor on the dock
stays black**. Short naps resume the monitor fine; an overnight sleep leaves it
dark, and the only apparent recovery is a reboot — so it read as "resume is
broken." (In the 2026-07-01 journal you can watch it: resume at 09:57, dock
re-authorized ~10:00, monitor never lights, power key pressed → re-suspend →
forced reboot at 10:01.)

Root cause, from the persistent journal:

- On resume the kernel resumes **amdgpu before** this ADR's `powerUpCommands`
  hook runs. So amdgpu probes its DP connectors while the NHI is *still unbound* —
  no DP-over-TB tunnel exists yet — and bails with
  `[drm] *ERROR* retrieve_link_cap: Read receiver caps dpcd data failed`,
  marking the connector disconnected. There is **no retry**.
- The hook then rebinds the NHI and the tunnel comes back, but nothing re-probes
  amdgpu, so the connector stays disconnected and `card1-DP-7` never lights.
- The short-vs-long split is the dock/monitor's *own* power state, not the SoC's:
  after a short nap the dock never dropped its link and a natural HPD re-detect
  wins the race; overnight it drops hard, the tunnel is slow to re-establish
  (often preceded by `thunderbolt … failed to allocate DP resource for port 7`),
  and amdgpu's one-shot probe loses.

**Decision:** keep the NHI teardown; add a resume step that, *after* the rebind,
forces amdgpu to re-detect its DP connectors so the restored tunnel is actually
picked up. Implementation (`hardware/framework.nix`):

- `powerDownCommands` drops a `/run/tb-dp-was-connected` flag iff an external
  `card1-DP-*` connector was `connected` at suspend (internal `eDP-1` excluded).
- `powerUpCommands`, after rebinding the NHI, and only if that flag is set, runs a
  bounded poll (≤8×1s): each tick writes `detect` to every `card*-DP-*/status`
  and stops as soon as one reads `connected`, then fires a `drm` `change` uevent
  so niri re-reads outputs. Docked-only, so an undocked resume adds no delay.

This keeps the "no post-hoc repair cruft" spirit for the *dock fabric* (still a
clean unbind/rebind) while accepting a small, bounded re-detect for the *display*,
because the display genuinely needs a second look the fabric rebind can't give it.

**Provisional, same as the original bet** — this needs an overnight docked sleep
to confirm; the `[tb-sleep]` breadcrumbs (`external DP re-detected after N s`, or
`still down after 8s`) in the persistent journal are the evidence. If it still
goes dark, the tunnel itself isn't coming back (the `failed to allocate DP
resource` path) and the next move is a dock-domain rescan rather than a connector
re-detect. Separately unresolved and out of scope here: every resume still logs
`amd_pmc: Last suspend didn't reach deepest state` (`total_hw_sleep:0`) — a power
draw / never-reaches-S0i3 problem, independent of the DP relight.

## Update (2026-07-31): the 2026-07-01 re-detect never worked, and the failure had shifted from "black" to "degraded"

The re-detect above was a placebo on two independent counts, and the symptom it
was aimed at had meanwhile mutated: the portable panel now came back *lit* but at
a junk mode, fixable only by unplugging and replugging it.

**Why the re-detect was a no-op.**

1. *It measured the wrong thing.* The poll broke out as soon as **any**
   `card*-DP-*` read `connected`. The MSI OLED hangs off a direct USB4 port and is
   back within a second of the NHI rebind, so the poll tripped on it immediately —
   `[tb-sleep] external DP re-detected after 1 s` — while the dock's panel had not
   yet appeared. In the 2026-07-31 journal the hook declares success at 10:31:38;
   `DP-7` only shows up at 10:31:39 and the dock's PCIe tunnel not until 10:31:43.
   The hook was reliably logging victory ~5s before the thing it was fixing
   existed.
2. *Its repair action does nothing on amdgpu.* Writing `detect` to a connector's
   sysfs `status` re-runs `fill_modes` → `connector->funcs->detect(force=true)`,
   and amdgpu's implementation is:

   ```c
   amdgpu_dm_connector_detect(struct drm_connector *connector, bool force)
   {
       if (aconnector->base.force == DRM_FORCE_UNSPECIFIED && !aconnector->fake_enable)
           connected = (aconnector->dc_sink != NULL);
   ```

   It reports the cached sink pointer. No DPCD read, no link training, no EDID
   re-read, no mode rebuild. The only part of the old block with any effect was the
   trailing `udevadm trigger`.

**The failure it should have been looking at.** amdgpu probes a DP connector once,
the instant its tunnel appears, and never again. When the dock's retimers are
still settling (`thunderbolt 1-0:2.1: new retimer found` lands in the same second
as the HPD), the link trains below its real capability and mode validation prunes
everything that link can't carry. The portable comes back advertising 4 modes
instead of 8 — 60Hz and 1080p, no 144/120/100. kanshi's pinned
`2560x1440@144.000` then can't apply, and since kanshi commits a profile
atomically the *entire* profile aborts:

```
kanshi[…]: output 'DP-7' doesn't support mode '2560x1440@144.000000Hz'
```

leaving the layout wrong until a physical replug forces a fresh probe. Same root
cause as the black screen, one notch less severe: the tunnel now comes up in time
to be *seen*, just not in time to be measured correctly.

**Decision:** replace the flag-and-poll with a capability check plus a real
software replug, still in `hardware/framework.nix`:

- **Suspend** records, per lit external panel, a fingerprint keyed by **EDID hash**
  (not connector name — the connector follows the port, and the portable has been
  both `DP-7` on the dock and `DP-2` direct) whose value is the connector's mode
  **count**. `modes` prints one line per mode including per-refresh duplicates, so
  the count catches a refresh-rate pruning, not just a resolution one. It is a
  high-water mark, so suspending while already degraded can't poison the baseline.
- **Resume** waits for *every* recorded panel to return, matched by its own EDID
  (bails early at 8s if none do — that's an undocked resume), then for each one
  compares mode count against the baseline and repairs a shortfall by writing
  `0` then `1` to amdgpu's per-connector debugfs `trigger_hotplug`. Unlike
  `status`, that is a genuine re-probe: `0` releases the sink and drops the link
  to `dc_connection_none`, `1` runs a full `dc_link_detect(DETECT_REASON_HPD)` —
  fresh link-cap verification, fresh EDID, rebuilt mode list, hotplug event to
  userspace. It is precisely the physical replug, which is why the physical replug
  was the only known cure. Up to 3 attempts, re-verified each time.
- A panel that never returns at all (the original black screen) gets the same
  `trigger_hotplug` treatment on every *disconnected* external connector — free,
  since there's no picture to disturb.

Healthy resumes are untouched: the check is a mode count, and if it matches
nothing is written, so there's no new flicker on the common path. Cost is bounded
at ~35s worst case, against `TimeoutStopSec=120s`.

**Evidence to watch** in the persistent journal — `[tb-sleep] … lit at suspend: N
modes` on the way in, then on the way out either `all external panels back after
Ns` alone (healthy), or `came back degraded (4 of 8 modes) — replug 1/3` followed
by `restored to 8 modes`. If `replug 3/3` recurs without a `restored` line, the
link truly can't carry the pinned mode in that topology and the pin in
`homes/tempest/monitors.nix` has to come down for that profile. The
`amd_pmc: Last suspend didn't reach deepest state` drain remains out of scope.
