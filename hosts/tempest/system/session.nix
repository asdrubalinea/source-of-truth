{
  config,
  pkgs,
  ...
}: let
  # greetd's `initial_session` fires on EVERY greetd start, but hands-free
  # autologin is only wanted after a soft-reboot (that session was already
  # authenticated) — a cold boot reaches userspace with no auth at all, since
  # TPM2 auto-unlocks LUKS.
  #
  # systemd's SoftRebootsCount is the discriminator, so no marker files: >= 1
  # execs niri-session, 0 exits and lets greetd fall through to tuigreet.
  # niri specifically, not the last-picked session — the hands-free path must
  # not strand you, so it stays on the compositor known to work (ADR 0012).
  # Replaces the older noctalia-lockscreen cold-boot gate (ADR 0007), which
  # autologined and then locked, letting startup apps run behind a flaky locker.
  autologinIfSoftReboot = pkgs.writeShellScript "niri-autologin-if-soft-reboot" ''
    count=$(${pkgs.systemd}/bin/systemctl show -p SoftRebootsCount --value 2>/dev/null || echo 0)
    [ "''${count:-0}" -ge 1 ] || exit 0
    exec niri-session
  '';
in {
  # Unlocks the login keyring from the greetd PAM session. Lives here rather
  # than in modules/security.nix because it is meaningless without greetd below.
  security.pam.services.greetd.enableGnomeKeyring = true;

  services.greetd = {
    enable = true;
    settings = {
      initial_session = {
        command = "${autologinIfSoftReboot}";
        user = "irene";
      };
      default_session = {
        # `--sessions`, not a hard-coded `--cmd`: each compositor layer
        # contributes a wayland-session entry, and tuigreet lists the directory,
        # so adding or removing one changes the menu with no edit here.
        # `--remember-session` is what makes trying the other one cheap.
        #
        # The path MUST be `sessionData.desktops` — sessionPackages go into
        # their own symlinkJoin exported only via XDG_DATA_DIRS, so the
        # /run/current-system/sw path does not exist and the menu comes up
        # empty. This is the only place a session is chosen interactively.
        #
        # Themed rather than left stock because it's the first thing the machine
        # says; the brightness budget (ADR 0009) doesn't constrain it since it
        # lives for seconds on a TTY. --theme takes ANSI colour NAMES, and
        # stylix themes the console palette from the ember scheme, so these
        # resolve to the rice's colours with no hex here. Beware: tuigreet
        # silently ignores unknown keys and colour names, so a typo degrades to
        # stock and the only way to know a key landed is to look.
        #
        # --battery/--time are readouts, not decoration: on a laptop that
        # cold-boots off the shelf they're the two facts wanted before login.
        # --asterisks makes a stuck key or dead keyboard visible.
        command = builtins.concatStringsSep " " [
          "${pkgs.tuigreet}/bin/tuigreet"
          "--time"
          "--battery"
          "--asterisks"
          "--remember"
          "--remember-session"
          "--greeting 'tempest // authenticate'"
          "--theme 'container=black;border=darkgray;title=white;greet=darkgray;prompt=white;input=white;action=darkgray;button=yellow;time=darkgray;text=white'"
          "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        ];
        user = "greeter";
      };
    };
  };
}
