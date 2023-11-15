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
    ../scripts/system-clean.nix
    ../misc/aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # programs.home-manager.path = "/persist/source-of-truth";

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

    # Nix
    nixpkgs-fmt

    # Rust
    # rust-analyzer
    clang
    rustup


    # Docker
    # docker-compose

    # Custom
    userApply
    systemApply
  ];
}
