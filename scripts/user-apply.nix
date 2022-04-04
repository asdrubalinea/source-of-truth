
{ config, pkgs, ... }:

let
  # TODO: don't hardcode giovanni here
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs/

    nix flake update
    home-manager switch --flake '.#giovanni'

    popd
  '';
in
{
  home.packages = [ userApply ];
}
