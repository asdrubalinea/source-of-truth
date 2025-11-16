{ inputs, pkgs, ... }:
{
  imports = [
    ./fonts.nix
  ];

  programs = {
    hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    };

    fish.enable = true;
  };
}
