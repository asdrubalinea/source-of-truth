{ config, pkgs, ... }:

let
  lenopow = pkgs.callPackage ../packages/lenopow.nix { };

  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/configs/

    home-manager switch --flake '.#giovanni-swan'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/persist/configs";
  }).systemApply;

  dump1090_sdrplay = pkgs.callPackage ../packages/sdrplay/dump1090.nix { };
  rsp_tcp_sdrplay = pkgs.callPackage ../packages/sdrplay/rsp_tcp.nix { };

  # opcua-client-gui = pkgs.callPackage ../packages/opcua-client-gui.nix { };

  # rkvm = pkgs.callPackage ../packages/rkvm { };

in
{
  imports = [
    ../desktop/sway
    ../desktop/alacritty
    ../desktop/neovim
    ../desktop/emacs

    ../scripts/brightness.nix
    ../scripts/system-clean.nix

    ../misc/aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.home-manager.path = "/persist/configs";

  programs.fish.enable = true;
  programs.fish.shellInit = ''
    set fish_greeting
    fish_add_path ~/.emacs.d/bin
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
    gnome.gnome-disk-utility
    git
    bat
    jq
    wdisplays
    unzip
    ripgrep
    usbutils
    openssl
    curl
    wget
    traceroute
    zip
    nixos-shell
    coreutils
    fd
    git-crypt
    gnupg
    fzf

    cmake
    gnumake

    # Browsers
    firefox
    google-chrome
    chromium
    # stable.librewolf
    stable.tor-browser-bundle-bin

    # Nix
    nixpkgs-fmt

    # Python
    python310

    # Rust
    rust-analyzer

    # Haskell
    stack
    ghc
    ghcid
    cabal-install

    # Common-Lisp
    sbcl

    # Docker
    docker-compose

    # Multimedia
    mpv
    feh
    ncdu
    gnome.nautilus
    gnome.eog
    zathura
    libsForQt5.okular
    libreoffice-fresh

    # Virtual
    quickemu
    virt-manager

    # Misc
    wpa_supplicant_gui
    ciscoPacketTracer8

    # Software Defined Radio
    (sdrpp.override { sdrplay_source = true; })
    gnuradio
    dump1090_sdrplay
    custom.sdrangel

    # Games
    polymc

    # rkvm

    # Custom
    lenopow
    userApply
    systemApply
    # opcua-client-gui

    # Themes
    gruvbox-dark-gtk
    kde-gruvbox
    gruvbox-dark-icons-gtk
  ];

  #programs.vscode = {
    #enable = true;
    #extensions = with pkgs.vscode-extensions; [
      #dracula-theme.theme-dracula
      #vscodevim.vim

      #matklad.rust-analyzer
      #bungcip.better-toml
    #];
  #};

  fonts.fontconfig.enable = true;

  services.gnome-keyring.enable = true;
}
