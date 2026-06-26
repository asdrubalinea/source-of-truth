{ pkgs, ... }:
# Soft-reboot session policy — tempest-specific, so it lives here rather than in
# the portable niri rice (same rationale as monitors.nix; see ADR 0004).
#
# Goal: `systemctl soft-reboot` tears down ALL of userspace (niri included) but
# keeps the kernel, then re-execs PID 1 and brings the default target back up —
# a few seconds, no firmware/kernel/ZFS round-trip. After a soft-reboot greetd
# autologins straight back into niri (hosts/tempest/system/session.nix gates the
# autologin on systemd's SoftRebootsCount), so a soft-reboot lands you in the
# desktop hands-free.
#
# A cold boot, by contrast, has no auth at all (TPM2 auto-unlocks LUKS), so the
# same SoftRebootsCount gate drops it to the tuigreet TTY greeter and you log in
# yourself. That cold-boot auth used to be a noctalia lockscreen driven from
# here; it now lives entirely in the greetd config. See ADR 0007.
let
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
    binds."Mod+Shift+R".action.spawn = [ "${niriSoftReboot}/bin/niri-soft-reboot" ];
  };
}
