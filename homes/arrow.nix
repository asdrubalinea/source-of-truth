{ config, pkgs, ... }:

{
  imports = [
    ../scripts/system-clean.nix
    ../scripts/system-apply.nix
    ../scripts/user-apply.nix

    ../misc/bash-aliases.nix
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

    # IDEs
    neovim
  ];
}
