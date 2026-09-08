{...}:
# The NixOS half of the ember rice's *furniture* — what every compositor layer
# needs whichever one you log into. The compositors themselves come from
# ./compositors/<name>/system.nix, imported alongside this by the host.
# Standalone HM can't set NixOS options, hence the two halves (ADR 0004).
{
  imports = [
    ./fonts.nix
  ];

  programs.fish.enable = true;

  # Noctalia's battery/wifi/bluetooth widgets poll upowerd over D-Bus and stay
  # blank without it. Its power-profile control is inert here by design: tempest
  # runs TLP, which forces power-profiles-daemon off.
  services.upower.enable = true;

  # Both lockers need their own PAM service to unlock as unprivileged Wayland
  # clients — the default config gives them unix auth via the setuid unix_chkpwd
  # helper, plus fingerprint when fprintd is on.
  #
  # swaylock is the runtime locker (./swayidle.nix). Noctalia's is kept only so
  # its own lock IPC still authenticates if ever invoked: it defaults to the
  # `login` service, which expects a privileged caller and fails its account
  # stage with "setuid failed", so unlocking never succeeds. Each compositor
  # layer points NOCTALIA_PAM_SERVICE here from its env block, that being the
  # one place an env var can be set per session.
  security.pam.services.swaylock = {};
  security.pam.services.noctalia = {};
}
