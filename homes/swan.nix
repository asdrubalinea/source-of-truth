{ config, pkgs, ... }:

{
  imports =
    [
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
    neofetch htop dstat
    glxinfo sshfs pavucontrol pciutils
    file exa grim
    gnome.gnome-disk-utility

    # Browsers
    firefox google-chrome chromium
    
    # Rust
    rustup rust-analyzer

    # Python
    python310

    # IDEs
    vscode emacs neovim

    # Docker
    docker-compose

    # Multimedia
    mpv

    # Virt
    quickemu virt-manager

    wpa_supplicant_gui
  ];

  nixpkgs.config.chromium.commandLineArgs = "--enable-features=UseOzonePlatform --ozone-platform=wayland";
}
