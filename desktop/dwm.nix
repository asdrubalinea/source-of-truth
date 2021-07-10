{ config, pkgs, ... }:

let 
  dwm = (import ../packages/dwm.nix);
  dwmblocks = (import ../packages/dwmblocks.nix);
in
{
  environment.systemPackages = with pkgs; [ dwm dwmblocks dmenu ];
}
