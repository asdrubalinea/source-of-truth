{ pkgs, ... }:
# Soft-reboot session policy — tempest-specific, so it lives here rather than in
# the portable niri rice (same rationale as monitors.nix; see ADR 0004).
#
# Goal: `systemctl soft-reboot` tears down ALL of userspace (niri included) but
# keeps the kernel, then re-execs PID 1 and brings the default target back up —
# a few seconds, no firmware/kernel/ZFS round-trip. greetd autologins straight
# back into niri (hosts/tempest/system/session.nix), so a soft-reboot lands you
# in the desktop hands-free.
#
# The catch: that same autologin fires on a cold boot, which on tempest has NO
# auth at all (TPM2 auto-unlocks LUKS). So the guard below locks the session on
# a cold boot and only stays out of the way after a soft-reboot. The
# discriminator is systemd's SoftRebootsCount: 0 on a cold/TPM boot, >= 1 after a
# soft-reboot, reset on a full reboot. See ADR 0007.
let
  # Cold-boot gate. Runs from niri's spawn-at-startup. On a cold boot it drives
  # Noctalia's lockscreen (the rice's lock path; swayidle.nix uses the same IPC
  # call). niri launches noctalia concurrently with this script, so we wait for
  # the shell to come up before locking — but crucially NOT just until its IPC
  # answers.
  #
  # The trap (Noctalia v5): the IPC socket binds ~0.3s BEFORE the shell finishes
  # drawing its bar/surfaces. Locking the half-initialised v5 shell makes it drop
  # its Wayland connection and exit; niri then holds the ext-session-lock with no
  # lock surface and paints a solid fallback — a red screen you can't even unlock
  # (the locker is dead). So: wait for the IPC socket to *exist*, give it a settle
  # window to finish init, and only then lock. After a soft-reboot the
  # SoftRebootsCount gate no-ops this, leaving you in the desktop. (v5 IPC:
  # `noctalia msg session lock` replaced `noctalia-shell ipc call lockScreen
  # lock`.)
  coldBootLock = pkgs.writeShellScript "niri-coldboot-lock" ''
    set -u
    count=$(${pkgs.systemd}/bin/systemctl show -p SoftRebootsCount --value 2>/dev/null || echo 0)
    [ "''${count:-0}" -eq 0 ] || exit 0

    # Wait (up to 20s) for Noctalia's IPC socket to appear. Its presence proves
    # the process is up without locking it yet (unlike polling the lock command,
    # which is exactly the too-early lock that bricks v5). Path matches the log
    # line "[app] IPC socket at /run/user/<uid>/noctalia-<wl-display>.sock".
    sock="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/noctalia-''${WAYLAND_DISPLAY:-wayland-1}.sock"
    i=0
    while [ ! -S "$sock" ] && [ "$i" -lt 200 ]; do
      ${pkgs.coreutils}/bin/sleep 0.1
      i=$((i + 1))
    done

    # Settle: let the bar/surfaces finish initialising past the IPC bind, so the
    # lock lands on a fully-up shell instead of racing its startup.
    ${pkgs.coreutils}/bin/sleep 2

    # Now lock, retrying briefly in case it's still settling.
    j=0
    while [ "$j" -lt 50 ]; do
      if noctalia msg session lock 2>/dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.1
      j=$((j + 1))
    done
  '';

  # The trigger. soft-reboot is a systemd-manager op (not a logind verb), so it
  # needs privilege; doas is passwordless for wheel here (security.doas), and the
  # setuid wrapper lives at /run/wrappers/bin/doas (the ${pkgs.doas} store path is
  # NOT setuid and would silently fail to escalate).
  niriSoftReboot = pkgs.writeShellScriptBin "niri-soft-reboot" ''
    exec /run/wrappers/bin/doas ${pkgs.systemd}/bin/systemctl soft-reboot
  '';
in
{
  home.packages = [ niriSoftReboot ];

  # Merge into the niri rice's settings (attrset/list merge across modules).
  programs.niri.settings = {
    spawn-at-startup = [
      { command = [ "${coldBootLock}" ]; }
    ];
    binds."Mod+Shift+R".action.spawn = [ "${niriSoftReboot}/bin/niri-soft-reboot" ];
  };
}
