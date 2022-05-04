{ config, pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /etc/nixos/nixos-config

    home-manager switch --flake '.#giovanni-arrow'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/etc/nixos/nixos-config";
  }).systemApply;

in {
  imports = [
    ../misc/aliases.nix

    ../scripts/system-clean.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # System utils
    pfetch
    htop
    dstat
    sshfs
    git

    git-crypt
    gnupg

    # IDEs
    neovim

    userApply
    systemApply
  ];
}
