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
  rtl_airband = pkgs.callPackage ../packages/sdrplay/rtl_airband.nix { };
  guglielmo = pkgs.callPackage ../packages/sdrplay/guglielmo.nix { };
  soapysdr = pkgs.soapysdr.override { extraPackages = [ pkgs.soapysdrplay ]; };

  # rkvm = pkgs.callPackage ../packages/rkvm { };

  sdrpp_patched = pkgs.sdrpp.overrideAttrs (attrs: {
    patches = attrs.patches ++ [ ../patches/sdrpp/add-radiomicrophones.patch ];
  });

in
{
  imports = [
    ../desktop/sway
    ../desktop/rofi
    ../desktop/dwm
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
    # pfetch
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
    wireguard-tools
    ipcalc

    # cmake
    # gnumake

    barrier

    # Browsers
    stable.firefox
    stable.google-chrome
    stable.chromium
    stable.librewolf
    stable.tor-browser-bundle-bin

    # Nix
    nixpkgs-fmt

    # Python
    python310

    # Rust
    rust-analyzer

    # Haskell
    # stack
    # ghc
    # ghcid
    # cabal-install

    # Common-Lisp
    # sbcl

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
    # libreoffice-fresh
    onlyoffice-bin
    trunk.yt-dlp
    # teams
    discord
    carla

    # Virtual
    quickemu
    virt-manager

    # Misc
    wpa_supplicant_gui
    ciscoPacketTracer8

    # Software Defined Radio
    (sdrpp_patched.override { sdrplay_source = true; })
    #gnuradio
    # rsp_tcp_sdrplay
    #dump1090_sdrplay
    #custom.sdrangel
    # rtl_airband
    #soapysdr
    # guglielmo

    # Games
    polymc

    # rkvm
    obs-studio

    # Custom
    lenopow
    userApply
    systemApply
    # opcua-client-gui

    # Themes
    gruvbox-dark-gtk
    kde-gruvbox
    gruvbox-dark-icons-gtk
    kde-gtk-config
  ];

  programs.vscode = {
    enable = true;
    extensions = with pkgs.trunk.vscode-extensions; [
      dracula-theme.theme-dracula
      jdinhlife.gruvbox

      vscodevim.vim

      rust-lang.rust-analyzer
      bungcip.better-toml
      serayuzgur.crates
    ];
  };

  fonts.fontconfig.enable = true;

  services.gnome-keyring.enable = true;
}
