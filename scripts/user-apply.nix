{ pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    set -e
    pushd /persist/source-of-truth/

    # -b backup is baked in so first-time switches against an existing
    # profile (or any future conflicting file) move it aside instead of
    # aborting. HM only writes the .backup when there's a real conflict.
    home-manager switch --flake '.#irene@tempest' -b backup "$@"

    popd
  '';
in
{
  home.packages = [ userApply ];
}
