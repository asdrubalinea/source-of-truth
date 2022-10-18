{ config, pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /etc/nixos/nixos-config

    home-manager switch --flake '.#giovanni-router'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/etc/nixos/source-of-truth";
  }).systemApply;

in
{
  imports = [
    ../misc/aliases.nix

    ../scripts/system-clean.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # System utils
    pfetch
    neofetch
    htop
    dstat
    sshfs
    git
    ncdu
    file
    screen
    wireguard-tools

    userApply
    systemApply
  ];
}
