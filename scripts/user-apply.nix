{ config, pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs/

    home-manager switch --flake '.#giovanni'

    popd
  '';
in { home.packages = [ userApply ]; }
