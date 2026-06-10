# Soft-reboot back into niri: greetd autologin gated by a cold-boot lockscreen

Status: accepted (2026-06-10)

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
