
{ config, pkgs, ... }:

let
  # TODO: don't hardcode giovanni here
  applySystem = pkgs.writeScriptBin "apply-system" ''
    #!${pkgs.stdenv.shell}
    pushd /home/giovanni/.dotfiles/

    nix flake update
    nixos-rebuild switch --flake '.#'

    popd
  '';
in
{
  environment.systemPackages = [ applySystem ];
}
