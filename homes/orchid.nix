{ config, pkgs, ... }:

let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth/

    home-manager switch --flake '.#irene-orchid'

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/persist/source-of-truth";
  }).systemApply;

in
{
  imports = [
    ../desktop/alacritty
    ../desktop/emacs

    ../desktop/hyprland
    ../desktop/waybar

    # ../desktop/sway
    # ../desktop/rofi
    # ../desktop/neovim

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
    # System utils
    neofetch
    pfetch
    htop
    dstat
    sshfs
    pciutils
    file
    eza
    git
    bat
    jq
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
    ipcalc
    iperf3

    nodejs_21
    yarn

    # Nix
    nixpkgs-fmt
    rnix-lsp
    nix-index
    gnumake
    nixfmt

    fontconfig
    cmake
    pkg-config

    # Rust
    # rust-analyzer
    clang
    rustup

    # Python
    pipenv

    # Docker
    docker-compose
    mkcert

    meld

    # Desktop
    firefox
    keepassxc
    chromium

    trunk.geekbench

    prismlauncher

    jetbrains.rust-rover

    # Custom
    userApply
    systemApply
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
  };

  wayland.windowManager.hyprland.enable = true;
}
