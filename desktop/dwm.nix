{ config, pkgs, ... }:

let 
  dwm = (import ../packages/dwm.nix);
  dwmblocks = (import ../packages/dwmblocks.nix);
  picom = (import ../packages/picom.nix);
in
{
  environment.systemPackages = [ dwm dwmblocks picom pkgs.dmenu pkgs.feh ];

}
