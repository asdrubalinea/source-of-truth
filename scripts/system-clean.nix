{ config, pkgs, ... }:

let
  # Remove old generations and perform garbage collection
  systemClean = pkgs.writeScriptBin "system-clean" ''
    #!${pkgs.stdenv.shell}
    nix-env -p /nix/var/nix/profiles/system --delete-generations old
    nix-collect-garbage -d
  '';
in
{
    environment.systemPackages = with pkgs; [ systemClean ];
}
