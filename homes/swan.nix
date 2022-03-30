{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Passwords
    keepassxc

    # Social
    tdesktop

    # Terminals
    alacritty

    # System utils
    neofetch htop dstat
    glxinfo sshfs pavucontrol pciutils
    gparted file exa grim

    # Browsers
    firefox google-chrome
    
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

    quickemu

    wpa_supplicant_gui
  ];
}
