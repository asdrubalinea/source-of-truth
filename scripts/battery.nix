{ config, pkgs, ... }:

let
  # Get battery percentage
  battery = pkgs.writeScriptBin "battery" ''
    #!${pkgs.stdenv.shell}
    cat /sys/class/power_supply/BAT0/capacity
  '';
in { environment.systemPackages = with pkgs; [ battery ]; }
