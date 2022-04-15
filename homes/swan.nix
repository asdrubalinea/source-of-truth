{ config, pkgs, ... }:

let
  lenopow = pkgs.callPackage ../packages/lenopow.nix { };

  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs/

    home-manager switch --flake '.#giovanni-swan'

    popd
  '';

in {
  imports = [
    ../desktop/sway
    ../desktop/alacritty
    ../desktop/neovim

    ../scripts/brightness.nix
    ../scripts/system-clean.nix

    ../misc/aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    set fish_greeting
  '';

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
    git
    bat
    jq
    wdisplays

    # Browsers
    firefox
    ungoogled-chromium
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
    userApply
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

  nixpkgs.config.ungoogled-chromium.commandLineArgs =
    "--enable-features=UseOzonePlatform --ozone-platform=wayland";
}
