{ config, pkgs, ... }:

let
  brightness = pkgs.writeScriptBin "brightness" ''
    #!${pkgs.stdenv.shell}
    cat /sys/class/backlight/amdgpu_bl*/brightness
    echo $1 | doas tee /sys/class/backlight/amdgpu_bl*/brightness
  '';
in { home.packages = [ brightness ]; }
