# Soft-reboot back into niri: greetd autologin gated to the tuigreet greeter on cold boot

Status: accepted (2026-06-10); amended (2026-06-25) — cold-boot auth moved from
the noctalia lockscreen to the tuigreet greeter, and the runtime lock moved from
noctalia to swaylock (see the two "Amendment" sections below).

## Context

The goal was a one-key "restart my whole desktop fast": run
`systemctl soft-reboot` and land back in niri hands-free after a few seconds.
A soft-reboot keeps the running kernel but tears down ALL of userspace —
including the niri compositor and the login session — then re-execs PID 1 and
brings the default target back up. So "come back into niri automatically" is the
same problem as "boot into niri automatically": something has to auto-login and
auto-start `niri-session` once userspace returns.

tempest had no such mechanism — `services.greetd`, `displayManager.autoLogin`
and `getty.autologinUser` were all off — so niri was started by hand. The only
pre-existing hint was a dormant `security.pam.services.greetd.enableGnomeKeyring`
line, suggesting greetd was always the intended login path.

The complication is tempest's threat model: LUKS is auto-unlocked by **TPM2**,
so a cold boot reaches userspace with **no authentication at all**. Plain
autologin would therefore mean a powered-on (or stolen) laptop boots straight
into an unlocked desktop. Auth has to happen *somewhere* on a cold boot, but
must NOT happen after a soft-reboot (that session was already authenticated).

## Decision

Enable **greetd** with an autologin `initial_session` (`niri-session` as
`irene`) and a `tuigreet` `default_session` greeter for logout
(`hosts/tempest/system/session.nix`). This also activates the dormant
gnome-keyring PAM line.

Discriminate cold boot from soft-reboot with systemd's **`SoftRebootsCount`**:
it is `0` on a cold/TPM boot, `>= 1` after a `systemctl soft-reboot`, and resets
on a full reboot — a built-in signal, no marker files. A niri
`spawn-at-startup` guard (`homes/tempest/soft-reboot.nix`) reads it and, when
`0`, drives Noctalia's lockscreen (the rice's existing lock IPC, retried until
the shell is up); when `>= 1` it no-ops. So:

- **Cold boot** → niri starts, immediately **locked** (auth via the noctalia
  `login` PAM lockscreen).
- **Soft-reboot** → niri starts **unlocked**, straight in.

The trigger is a `niri-soft-reboot` script (`doas systemctl soft-reboot` via the
setuid wrapper — soft-reboot is a systemd-manager op, not a logind verb, so it
needs privilege) bound to `Mod+Shift+R`.

The session policy (autologin + lock gate + keybind) lives in `homes/tempest`
and `hosts/tempest`, NOT in the niri rice: it depends on tempest's TPM
auto-unlock, so it is machine policy, keeping the rice portable (cf. ADR 0004
and monitors.nix).

## Consequences / trade-offs

- The cold-boot security boundary is a **lockscreen**, not a full greeter — apps
  in `spawn-at-startup` do launch behind the lock before auth. Weaker than a
  greeter that runs nothing pre-auth, but it reuses the existing noctalia stack;
  TPM already unlocked the disk regardless, so the marginal exposure is small.
  The greeter-gated alternative was considered and rejected for complexity.
- A manual **log out → tuigreet → log in** within the same boot still has
  `SoftRebootsCount == 0`, so the guard locks again: you authenticate twice
  (greeter, then lockscreen). Mildly annoying, accepted as rare.
- `niri-soft-reboot` relies on passwordless `doas` for wheel (`security.doas`).

## Amendment (2026-06-25): cold boot drops to the tuigreet greeter

The noctalia-lockscreen cold-boot gate worked badly in practice: the v5 locker
was flaky (a half-initialised shell locked too early painted an unlockable red
screen; later builds segfaulted), so the careful "wait for `[bar] creating`
before locking" dance in `soft-reboot.nix` was always fighting the locker rather
than relying on it. The original ADR rejected the greeter-gated alternative "for
complexity" — but the lockscreen path turned out to be the more complex and less
reliable of the two.

So the cold-boot auth surface is now the **tuigreet greeter** — the
greeter-gated alternative this ADR originally rejected:

- The `initial_session` command is now a wrapper
  (`hosts/tempest/system/session.nix`) that reads `SoftRebootsCount`. On a
  soft-reboot (`>= 1`) it `exec`s `niri-session` (hands-free, unchanged). On a
  cold boot (`0`) it exits immediately, so greetd falls through to
  `default_session` (tuigreet) and you log in at the TTY yourself.
- The `coldBootLock` spawn-at-startup guard in `homes/tempest/soft-reboot.nix`
  is gone; that file now only carries the `Mod+Shift+R` soft-reboot trigger.

This *strengthens* the cold-boot boundary relative to the original decision:
`niri-session` never starts pre-auth, so the "spawn-at-startup apps run behind
the lock" trade-off above no longer applies. It also removes the double-auth
annoyance (logout → tuigreet → login no longer triggers a second lock).

## Amendment (2026-06-25): runtime lock moves off Noctalia to swaylock

The cold-boot move above left the *runtime* lock (idle / `Mod+L` / before-sleep,
all in `rices/niri/swayidle.nix`) still driven by `noctalia msg session lock`.
That kept the red screen alive **when docked**: Noctalia v5's ext-session-lock
client segfaults deterministically on output hotplug (same fault offset every
time), and docking *is* output hotplug (eDP-1 off, externals on). So any lock
taken while docked crashed the locker, leaving niri to hold the outputs locked
with no surface — painting its solid red fallback — which the auto-restarted
locker re-crashed into. Single-output (internal/undocked) never hotplugs, so it
never reproduced.

So the runtime lock now uses **swaylock** — a tiny wlroots locker that survives
output hotplug and draws its prompt on every connected output. swayidle's `lock`
and `before-sleep` call swaylock by absolute path (guarded against double-launch,
since only one ext-session-lock client may exist); a `swaylock` PAM service is
added in `rices/niri/system.nix`. Noctalia stays the shell (bar / launcher /
notifications / wallpaper); it just no longer owns the lock surface. This is the
same reasoning as the cold-boot move — get auth off the flaky v5 locker — applied
to the one path the first amendment didn't cover.
