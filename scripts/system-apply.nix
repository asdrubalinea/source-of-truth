{ config, pkgs, ... }:

let
  # TODO: don't hardcode giovanni here
  systemApply = pkgs.writeScriptBin "system-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs

    nix flake update
    nixos-rebuild switch --flake '.#'

    popd
  '';
in { home.packages = [ systemApply ]; }
