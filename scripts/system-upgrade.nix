
{ config, pkgs, ... }:

let
  systemUpgrade = pkgs.writeScriptBin "system-upgrade" ''
    #!${pkgs.stdenv.shell}
    nix-channel --update
    nixos-rebuild switch --upgrade
  '';
in
{
  environment.systemPackages = [ systemUpgrade ];
}
