
{ config, pkgs, ... }:

let
  # TODO: don't hardcode giovanni here
  applyUser = pkgs.writeScriptBin "apply-user" ''
    #!${pkgs.stdenv.shell}
    pushd /home/giovanni/.dotfiles/

    nix flake update
    home-manager switch --flake '.#giovanni'

    popd
  '';
in
{
  environment.systemPackages = [ applyUser ];
}
