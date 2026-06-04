{ inputs, pkgs, ... }:
{
  imports = [
    ./fonts.nix
  ];

  programs = {
    niri.enable = true;
    fish.enable = true;
  };

  # Noctalia's lockscreen authenticates against the `login` PAM service
  # (LockContext.qml: NOCTALIA_PAM_SERVICE || "login"), which already exists,
  # so no swaylock PAM entry is needed now that swaylock is gone.
}
