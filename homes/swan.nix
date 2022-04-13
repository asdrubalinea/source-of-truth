{ config, pkgs, ... }:

let lenopow = pkgs.callPackage ../packages/lenopow.nix { };
in {
  imports = [
    ../desktop/sway
    ../desktop/alacritty

    ../scripts/brightness.nix
    ../scripts/system-clean.nix
    ../scripts/system-apply.nix
    ../scripts/user-apply.nix

    ../misc/bash-aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Passwords
    keepassxc

    # Social
    tdesktop

    # System utils
    neofetch
    pfetch
    htop
    dstat
    glxinfo
    sshfs
    pavucontrol
    pciutils
    file
    exa
    grim
    gnome.gnome-disk-utility
    sudo
    git
    bat
    jq

    # Browsers
    firefox
    chromium
    librewolf

    # Nix
    nixfmt

    # Python
    python310

    # IDEs
    emacs
    neovim

    # Docker
    docker-compose

    # Multimedia
    mpv
    feh
    ncdu
    gnome.nautilus
    gnome.eog
    zathura

    # Virtual
    quickemu
    virt-manager

    # Misc
    wpa_supplicant_gui
    ciscoPacketTracer8

    # Custom
    lenopow
  ];

  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      vscodevim.vim

      matklad.rust-analyzer
      bungcip.better-toml
    ];
  };

  fonts.fontconfig.enable = true;

  services.gnome-keyring.enable = true;

  nixpkgs.config.chromium.commandLineArgs =
    "--enable-features=UseOzonePlatform --ozone-platform=wayland";
}
