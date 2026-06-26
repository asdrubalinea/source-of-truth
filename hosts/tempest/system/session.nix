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
  #     hands-free.
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
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd niri-session";
        user = "greeter";
      };
    };
  };
}
