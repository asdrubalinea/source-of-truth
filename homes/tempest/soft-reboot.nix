{pkgs, ...}:
# Soft-reboot session policy — tempest-specific, so it lives here rather than in
# the portable rice (same rationale as monitors.nix; ADR 0004).
#
# `systemctl soft-reboot` tears down ALL of userspace but keeps the kernel, then
# re-execs PID 1 — a few seconds, no firmware/kernel/ZFS round-trip. greetd then
# autologins straight back into niri, gated on SoftRebootsCount in
# hosts/tempest/system/session.nix, so a soft-reboot is hands-free. A cold boot
# has no auth at all (TPM2 auto-unlocks LUKS), so the same gate drops it to the
# tuigreet TTY greeter instead. See ADR 0007.
let
  # soft-reboot is a systemd-manager op, not a logind verb, so it needs
  # privilege. doas is passwordless for wheel here, and the path MUST be the
  # setuid wrapper — ${pkgs.doas} is not setuid and silently fails to escalate.
  niriSoftReboot = pkgs.writeShellScriptBin "niri-soft-reboot" ''
    exec /run/wrappers/bin/doas ${pkgs.systemd}/bin/systemctl soft-reboot
  '';
in {
  home.packages = [niriSoftReboot];

  # Merges into each compositor layer's settings, so the key does the same thing
  # whichever session is running. No `lib.mkIf` needed: an unenabled layer's
  # whole config is gated, so a stray setting is inert.
  programs.niri.settings = {
    binds."Mod+Shift+R".action.spawn = ["${niriSoftReboot}/bin/niri-soft-reboot"];
  };

  wayland.windowManager.mango.settings.bind = [
    "SUPER+SHIFT,r,spawn,${niriSoftReboot}/bin/niri-soft-reboot"
  ];
}
