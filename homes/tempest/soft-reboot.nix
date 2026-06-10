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
  # call) as soon as the shell answers — niri launches noctalia-shell
  # concurrently with this, so retry until it's up (mirrors the scratchpad-init
  # wait in niri.nix). After a soft-reboot it no-ops, leaving you in the desktop.
  coldBootLock = pkgs.writeShellScript "niri-coldboot-lock" ''
    set -u
    count=$(${pkgs.systemd}/bin/systemctl show -p SoftRebootsCount --value 2>/dev/null || echo 0)
    [ "''${count:-0}" -eq 0 ] || exit 0

    i=0
    while [ "$i" -lt 200 ]; do
      if noctalia-shell ipc call lockScreen lock 2>/dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 0.1
      i=$((i + 1))
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
