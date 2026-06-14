{ inputs, pkgs, ... }:
{
  imports = [
    ./fonts.nix
  ];

  programs = {
    niri.enable = true;
    fish.enable = true;
  };

  # Noctalia's battery readout polls upowerd over D-Bus; without the daemon the
  # battery widget stays blank. The v5 NixOS docs list this as a required option
  # for the battery/wifi/bluetooth/power-profile features
  # (https://docs.noctalia.dev/v5/getting-started/nixos/). networkmanager and
  # bluetooth are already on at the host level; power-profiles-daemon is the one
  # feature we deliberately can't satisfy — tempest runs TLP (hardware/framework-
  # tlp-advanced.nix forces power-profiles-daemon off, the two are mutually
  # exclusive), so Noctalia's power-profile control is inert here by design.
  services.upower.enable = true;

  # Noctalia's lockscreen authenticates via PAM. It defaults to the `login`
  # service (LockContext.qml: NOCTALIA_PAM_SERVICE || "login"), but `login`
  # expects a privileged caller — an unprivileged locker fails its account stage
  # with "pam_unix(login:account): setuid failed: Operation not permitted", so
  # unlocking never succeeds. Give it a dedicated, minimal PAM service instead
  # (standard unix auth via the setuid unix_chkpwd helper, plus fingerprint when
  # fprintd is enabled) and point NOCTALIA_PAM_SERVICE at it (set in the niri
  # environment block, rices/niri/niri.nix). This mirrors what swaylock/hyprlock
  # do.
  security.pam.services.noctalia = { };
}
