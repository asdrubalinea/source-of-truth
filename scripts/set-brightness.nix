
{ config, pkgs, ... }:

let
  # Remove old generations and perform garbage collection
  setBrightness = pkgs.writeScriptBin "set-brightness" ''
    #!${pkgs.stdenv.shell}
    cat /sys/class/backlight/amdgpu_bl*/brightness
    echo $1 | sudo tee /sys/class/backlight/amdgpu_bl*/brightness
  '';
in
{
    environment.systemPackages = with pkgs; [ setBrightness ];
}
