{ inputs, pkgs, ... }:
{
  imports = [
    ./fonts.nix
  ];

  programs = {
    niri.enable = true;
    fish.enable = true;
  };
}