{ pkgs, ... }:

let
  configApply = pkgs.writeScriptBin "config-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth

    nixos-rebuild switch --flake '.#' --sudo

    popd
  '';
in
{
  home.packages = [ configApply ];
}
