{
  config,
  pkgs,
  ...
}: let
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
in {
  # Login / session manager for the niri desktop.
  #
  # `default_session` (tuigreet) is the TTY greeter: shown on every cold/full
  # boot and after a logout. Enabling greetd is also what makes the
  # `security.pam.services.greetd.enableGnomeKeyring` line in security.nix do
  # anything — logging in through tuigreet unlocks the login keyring as part of
  # the greetd PAM session.
  # Unlocks the login keyring from the greetd PAM session. Lives here rather
  # than in a security.nix because it is meaningless without greetd below;
  # the rest of the doas/sudo posture is modules/security.nix.
  security.pam.services.greetd.enableGnomeKeyring = true;

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
        # The path MUST be `sessionData.desktops`, not
        # /run/current-system/sw/share/wayland-sessions: sessionPackages are
        # collected into their own symlinkJoin which the display-manager module
        # exports only through XDG_DATA_DIRS — nothing ever lands under `sw`, so
        # that directory does not exist and the menu comes up empty.
        #
        # This is the ONLY place a session is chosen interactively; the
        # soft-reboot path above deliberately does not consult it.
        #
        # The greeter is the one always-seen surface the brightness budget does
        # not constrain: it lives for seconds, on a TTY, before any compositor
        # exists, so nothing here can burn a panel (ADR 0009). It is themed
        # anyway rather than left stock because it is also the first thing the
        # machine says.
        #
        # --theme takes ANSI colour NAMES, and stylix themes the console
        # palette from the ember scheme, so these resolve to the rice's own
        # colours without a hex appearing here (principle 4 in
        # docs/ember-visual-language.md): black is base00, darkgray base03,
        # white base05, yellow base0A. Unknown keys and unknown colour names are
        # silently ignored by tuigreet, not rejected — a typo here degrades to
        # the stock colour rather than failing to start, which also means the
        # only way to know a key landed is to look at the greeter.
        #
        # --battery and --time are readouts, not decoration: on a laptop that
        # cold-boots after an unknown time on the shelf, charge and clock are
        # exactly the two facts wanted before logging in. --asterisks makes the
        # password field show its length, so a stuck key or a dead keyboard is
        # visible instead of being indistinguishable from typing.
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
