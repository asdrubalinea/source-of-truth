{ config, pkgs, ... }:

let
  systemApply = pkgs.writeScriptBin "system-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs

    nixos-rebuild switch --flake '.#'

    popd
  '';
in { environment.systemPackages = [ systemApply ]; }
