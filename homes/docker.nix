{ config, pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /etc/nixos/source-of-truth

    home-manager switch --flake '.#giovanni-docker'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/etc/nixos/source-of-truth";
  }).systemApply;

in
{
  imports = [
    ../scripts/system-clean.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # System utils
    git
    neovim
    htop

    userApply
    systemApply
  ];
}

