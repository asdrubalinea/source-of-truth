{ pkgs, ... }:
let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth/

    home-manager switch --flake '.#irene@orchid' "$@"

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/persist/source-of-truth";
  }).systemApply;
in {
  imports = [
    ../desktop/zed-editor

    ../rices/feet

    ../scripts/system-clean.nix
    ../misc/fish.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.fish = {
    enable = true;
    shellInitLast = ''
      starship init fish | source
    '';
  };

  # programs.nushell.enable = true;
  services.vscode-server.enable = true;
  services.vscode-server.enableFHS = true;

  services.gnome-keyring = {
    enable = true;
    components = [ "pkcs11" "secrets" "ssh" ];
  };

  home.packages = with pkgs; [
    # System utils
    hyfetch
    htop
    dool
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
    coreutils
    fd
    lazygit
    gnupg
    fzf
    ipcalc
    iperf3
    zellij
    tmux
    screen
    grc
    devbox
    gay
    ponysay
    blahaj
    dive
    lsof
    lurk
    nix-tree
    yt-dlp
    ffmpeg
    starship
    nvtopPackages.amd
    stable.iozone
    fio
    smartmontools
    parted
    xxd

    # Nix
    nixpkgs-fmt
    # rnix-lsp

    alejandra
    nixd

    # Project management
    devenv
    direnv

    fontconfig
    cmake
    pkg-config
    quickemu
    distrobox

    # Rust
    # rust-analyzer
    oha

    # Docker
    docker-compose

    # Desktop
    # firefox
    keepassxc
    chromium
    alacritty
    wezterm

    neovim
    luarocks
    lua

    rofi

    trunk.geekbench
    # prismlauncher

    # Custom
    userApply
    systemApply

    aider-chat
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages
      (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
}
