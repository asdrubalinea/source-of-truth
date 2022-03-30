
{ config, pkgs, ... }:

let
  # TODO: don't hardcode giovanni here
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /home/giovanni/.dotfiles

    nix flake update
    home-manager switch --flake '.#g'

    popd
  '';
in
{
  home.packages = [ userApply ];
}
