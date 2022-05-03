{ config, pkgs, ... }:

let
  lenopow = pkgs.callPackage ../packages/lenopow.nix { };

  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs/

    home-manager switch --flake '.#giovanni-arrow'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/etc/nixos/nixos-config";
  }).systemApply;

in {
  imports = [
    ../scripts/system-clean.nix

    ../misc/aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # System utils
    neofetch
    pfetch
    htop
    dstat
    sshfs
    pciutils
    file
    exa
    sudo
    git
    bat
    jq

    git-crypt
    gnupg

    # IDEs
    neovim

    userApply
    systemApply
  ];
}
