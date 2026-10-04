{
  config,
  pkgs,
  ...
}: {
  # Greeter for the ember rice. Same shape as hosts/tempest/system/session.nix
  # minus its machine policy: no soft-reboot autologin (orchid has no
  # Mod+Shift+R trigger, so `initial_session` is left unset and every greetd
  # start is a plain tuigreet) and no --battery readout.
  #
  # The 9070 XT drives the desktop, so a running session holds its DRM node and
  # the win11 hook (./gaming-vm.nix) refuses to start the VM. Log out first.

  # Unlocks the login keyring from the greetd PAM session.
  security.pam.services.greetd.enableGnomeKeyring = true;

  # HM (stylix, gtk) writes settings through dconf; without the system service
  # those writes fail at activation.
  programs.dconf.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      # `--sessions` must be `sessionData.desktops`, not /run/current-system/sw —
      # see the long note in hosts/tempest/system/session.nix.
      command = builtins.concatStringsSep " " [
        "${pkgs.tuigreet}/bin/tuigreet"
        "--time"
        "--asterisks"
        "--remember"
        "--remember-session"
        "--greeting 'orchid // authenticate'"
        "--theme 'container=black;border=darkgray;title=white;greet=darkgray;prompt=white;input=white;action=darkgray;button=yellow;time=darkgray;text=white'"
        "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
      ];
      user = "greeter";
    };
  };
}
