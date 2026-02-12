{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    # --- Core system utilities ---
    coreutils
    file
    gnupg
    lsof
    ntfs3g
    openssl
    pciutils
    sbctl # UEFI Secure Boot key management
    smartmontools # smartctl
    usbutils
    upower

    # --- System info & monitoring ---
    btop
    dool # dstat replacement
    fastfetch
    htop
    hyfetch # neofetch fork
    lm_sensors
    nvtopPackages.amd # AMD GPU monitor
    onefetch # repo summary (git)
    powertop
    yek

    # --- File management & text processing ---
    bat
    cdrtools
    csvlens
    czkawka # duplicate finder/cleanup
    eza
    fd
    jq
    lz4
    ncdu
    nnn # terminal file manager
    ripgrep
    sshfs
    unzip
    xxd
    yazi
    zip

    # --- Networking & HTTP ---
    curl
    dnsutils # dig, nslookup
    ipcalc
    iperf3
    nmap
    postman
    traceroute
    wget
    yt-dlp

    # --- Backup & sync ---
    borgbackup
    rclone
    restic
    vorta # Borg GUI

    # --- Nix & developer tooling ---
    alejandra
    cachix
    devenv
    devbox
    gitui
    httptoolkit
    just
    jujutsu # VCS
    lazygit
    lazyjj # TUI for jujutsu
    lurk # Nix helper (see nixpkgs description)
    nil # Nix LSP
    nix-tree
    nixd # Nix LSP
    nixpkgs-fmt
    custom.codex

    inputs.hn-tui-flake.packages.${stdenv.hostPlatform.system}.hackernews-tui # hn TUI

    # --- Languages & runtimes ---
    bun
    lua
    luarocks
    nodejs
    python3
    uv # Python package manager

    # --- Containers & virtualization ---
    distrobox
    dive
    docker-compose

    # --- Shell & terminal ---
    alacritty
    asciinema # terminal session recorder
    direnv
    fzf
    ghostty
    grc
    kitty
    screen
    starship
    tmux
    wezterm
    zellij

    # --- Desktop integration ---
    appimage-run # run AppImages via Nix
    blueberry
    networkmanagerapplet
    pavucontrol
    seahorse
    solaar
    wl-clipboard

    # --- Browsers ---
    brave
    chromium
    firefox
    tor-browser
    google-chrome
    inputs.zen-browser.packages.x86_64-linux.default # Zen Browser

    # --- Communication & productivity ---
    keepassxc
    obsidian
    telegram-desktop
    thunderbird
    vesktop
    zoom-us

    # --- Media, graphics & documents ---
    feh
    ffmpeg
    gimp3
    imagemagick
    inkscape
    kdePackages.okular
    krita
    libheif
    mpv
    nautilus
    nemo
    obs-studio
    vlc

    # --- Data & databases ---
    dbeaver-bin
    litecli # SQLite CLI
    sqlite
    sqlitebrowser

    # --- Security testing ---
    burpsuite

    # --- Fun & misc ---
    blahaj
    gay # rainbow output filter
    ponysay
  ];
}
