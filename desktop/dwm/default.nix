{ config, pkgs, ... }:

let
  dwm = pkgs.callPackage ../../packages/dwm.nix { };
  dwmblocks = pkgs.callPackage ../../packages/dwmblocks.nix { };
in
{
  home.packages = [ dwm dwmblocks pkgs.dmenu pkgs.feh ];
}
