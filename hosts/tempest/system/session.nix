{ pkgs, ... }:
let
  # greetd's `initial_session` fires on EVERY greetd start — both a cold boot and
  # a `systemctl soft-reboot`. We only want the hands-free autologin after a
  # soft-reboot (that session was already authenticated). A cold boot reaches
  # userspace with NO auth at all (TPM2 auto-unlocks LUKS), so it must go through
  # a real login instead.
  #
  # systemd's SoftRebootsCount is the discriminator: 0 on a cold/full boot, >= 1
  # after a soft-reboot, reset on a full reboot (a built-in signal, no marker
  # files). So the wrapper:
  #   - soft-reboot (>= 1) → `exec niri-session`, landing back in the desktop
  #     hands-free. niri specifically, not "whichever session you last picked":
  #     the hands-free path is the one that must not strand you, so it stays on
  #     the compositor known to work rather than tracking tuigreet's remembered
  #     choice. Log into mango, soft-reboot, and you come back up in niri — pick
  #     mango again at the greeter. See docs/adr/0012.
  #   - cold boot (0)      → exit immediately, which makes greetd fall through to
  #     `default_session` (tuigreet) — the plain TTY greeter, where you log in
  #     yourself.
  #
  # niri-session therefore never starts pre-auth on a cold boot. This replaces
  # the older noctalia-lockscreen cold-boot gate (which autologined and then
  # locked, letting spawn-at-startup apps run behind the lock and depending on a
  # flaky v5 locker) — see ADR 0007. `niri-session` is resolved bare, the same
  # way it was as the original `initial_session` command and in tuigreet's
  # `--cmd`; programs.niri puts it on the system PATH greetd sets up.
  autologinIfSoftReboot = pkgs.writeShellScript "niri-autologin-if-soft-reboot" ''
    count=$(${pkgs.systemd}/bin/systemctl show -p SoftRebootsCount --value 2>/dev/null || echo 0)
    [ "''${count:-0}" -ge 1 ] || exit 0
    exec niri-session
  '';
in
{
  # Login / session manager for the niri desktop.
  #
  # `default_session` (tuigreet) is the TTY greeter: shown on every cold/full
  # boot and after a logout. Enabling greetd is also what makes the
  # `security.pam.services.greetd.enableGnomeKeyring` line in security.nix do
  # anything — logging in through tuigreet unlocks the login keyring as part of
  # the greetd PAM session.
  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${autologinIfSoftReboot}";
        user = "irene";
      };
      default_session = {
        # `--sessions` rather than a hard-coded `--cmd`: tempest installs two
        # compositor layers of the ember rice (niri and mango), each of which
        # contributes a wayland-session entry via
        # `services.displayManager.sessionPackages`. tuigreet lists what is in
        # that directory, so adding or removing a compositor changes the menu
        # with no edit here. `--remember-session` reopens on the last one picked,
        # which is what makes trying a second compositor cheap.
        #
        # This is the ONLY place a session is chosen interactively; the
        # soft-reboot path above deliberately does not consult it.
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions";
        user = "greeter";
      };
    };
  };
}
