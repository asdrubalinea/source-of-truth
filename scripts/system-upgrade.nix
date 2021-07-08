
{ config, pkgs, ... }:

let
  # Remove old generations and perform garbage collection
  systemUpgrade = pkgs.writeScriptBin "system-upgrade" ''
    #!${pkgs.stdenv.shell}
    nix-channel --update
    nixos-rebuild switch --upgrade
  '';
in
{
    environment.systemPackages = with pkgs; [ systemUpgrade ];
}
