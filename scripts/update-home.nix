{ pkgs, ... }:

let
  updateHome = pkgs.writeScriptBin "update-home" ''
    #!${pkgs.stdenv.shell}
    set -e
    pushd /persist/source-of-truth/

    # Bump only the flake inputs that affect home generation on tempest.
    # niri and helix are intentionally excluded — both are also consumed by
    # tempest's system layer (niri rice activates programs.niri at the
    # NixOS level; pkgs.helix is set via evilHelixOverlay and referenced as
    # EDITOR in hosts/tempest/system/environment.nix), so bumping them would
    # change the system closure. Use ./update-flakes.sh for a full bump.
    nix flake update \
      nixpkgs-home \
      claude-code \
      codex \
      zen-browser \
      hn-tui-flake \
      emacs-overlay \
      stylix \
      hyprland

    popd
  '';
in
{
  home.packages = [ updateHome ];
}
