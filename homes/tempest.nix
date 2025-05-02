{ pkgs, inputs, ... }:
let
  arc-size = (
    pkgs.writeShellScriptBin "arc-size" ''
      cat /proc/spl/kstat/zfs/arcstats | grep '^size ' | awk '{ print $3 }' | awk '{ print $1 / (1024 * 1024 * 1024) " GiB" }'
    ''
  );

  nix-size = (
    pkgs.writeShellScriptBin "nix-size" ''
      zfs list -o name,used -t filesystem,volume -Hp | awk -v dataset='zroot/local/nix' '$1 == dataset { printf "%.0f GiB", $2/1024/1024/1024 }'
    ''
  );
in
{
  imports = [
    inputs.hyprland.homeManagerModules.default
    inputs.stylix.homeManagerModules.stylix

    ../rices/feet

    ../desktop/zed-editor

    ../scripts/system-clean.nix
    ../scripts/config-apply.nix

    ../misc/fish.nix
    ../misc/aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";
  };

  services.gnome-keyring = {
    enable = false;
    components = [
      "pkcs11"
      "secrets"
      "ssh"
    ];
  };

  programs.git = {
    enable = true;
    userName = "Irene";
    userEmail = "git@asdrubalini.xyz";
  };

  home.packages = with pkgs; [
    # System utils
    hyfetch
    onefetch
    fastfetch
    htop
    dool
    sshfs
    pciutils
    file
    eza
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
    smartmontools
    xxd
    telegram-desktop
    pavucontrol
    obsidian
    vesktop
    btop
    zoom-us
    superTuxKart
    nemo
    csvlens
    onlyoffice-desktopeditors
    obs-studio
    dnsutils
    wl-clipboard
    postman
    just
    distrobox
    rclone
    restic
    czkawka
    cachix
    tor-browser
    mpv
    vlc
    dbeaver-bin
    gitui
    yazi
    evil-helix
    seahorse
    blueberry
    ntfs3g
    networkmanagerapplet

    # Nix
    nixpkgs-fmt
    # rnix-lsp
    nil
    alejandra
    nixd

    # Project management
    devenv
    direnv

    # Docker
    docker-compose

    # Desktop
    keepassxc
    chromium
    alacritty
    kitty
    wezterm
    inputs.zen-browser.packages.x86_64-linux.default
    ladybird

    # inputs.mm.packages.x86_64-linux.default
    sqlite
    sqlitebrowser

    inputs.nixvim.packages.${pkgs.system}.default

    luarocks
    lua

    prismlauncher

    arc-size
    nix-size

    aider-chat
  ];

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
}
