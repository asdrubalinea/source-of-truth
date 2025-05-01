{ pkgs, ... }:

let
  configApply = pkgs.writeScriptBin "config-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth

    nixos-rebuild switch --flake '.#' --use-remote-sudo

    popd
  '';
in
{
  home.packages = [ configApply ];
}
