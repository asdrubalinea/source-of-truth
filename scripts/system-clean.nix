{ config, pkgs, ... }:

let
  # Remove old generations and perform garbage collection
  systemClean = pkgs.writeScriptBin "system-clean" ''
    #!${pkgs.stdenv.shell}
    nix-env -p /nix/var/nix/profiles/system --delete-generations old
    nix-collect-garbage -d
    nix-store --gc
    nix-store --optimize
  '';
in { home.packages = [ systemClean ]; }
