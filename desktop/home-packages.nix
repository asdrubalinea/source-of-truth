{
  pkgs,
  inputs,
  ...
}: {
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
    bubblewrap
    opencode
    ddcutil

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
    kdePackages.dolphin # KDE file manager
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
    httm # Time-Machine-style TUI to browse/restore ZFS snapshots
    rclone
    restic
    # vorta # Borg GUI

    # --- Nix & developer tooling ---
    alejandra
    cachix
    devenv
    devbox
    gitui
    # httptoolkit
    just
    jujutsu # VCS
    lazygit
    lazyjj # TUI for jujutsu
    lurk # Nix helper (see nixpkgs description)
    nil # Nix LSP
    nix-tree
    nixd # Nix LSP
    nixpkgs-fmt
    gh # GitHub CLI (used by magit/forge)
    # trunk.codex

    inputs.hn-tui-flake.packages.${stdenv.hostPlatform.system}.hackernews-tui # hn TUI

    # --- Languages & runtimes ---
    bun
    jdk21
    lua
    luarocks
    nodejs
    php
    # pygobject3 (the `gi` module) rides on the interpreter for niri's noctalia
    # Screen Toolkit webcam-mirror tool; a bare python3 can't import it.
    (python3.withPackages (ps: with ps; [pygobject3]))
    uv # Python package manager

    # Language servers (consumed by emacs eglot, helix, etc.)
    pyright
    ruff
    rust-analyzer
    gopls
    clang-tools
    typescript-language-server
    tinymist # Typst LSP
    texlab # LaTeX LSP
    bash-language-server
    marksman # Markdown LSP
    phpactor # PHP LSP
    vscode-langservers-extracted # HTML/CSS/JSON/ESLint LSPs
    vue-language-server # Vue 3 LSP (Volar)
    jdt-language-server # Java LSP (Eclipse JDT.LS)
    harper # Grammar/spell LSP for prose (markdown/typst/org)
    taplo # TOML LSP + formatter
    yaml-language-server

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
    (callPackage ../packages/drift.nix {src = inputs.drift;})
    grc
    kitty
    screen
    starship
    tmux
    wezterm
    zellij

    # --- Desktop integration ---
    appimage-run # run AppImages via Nix
    blueman
    libnotify # notify-send
    networkmanagerapplet
    pavucontrol
    seahorse
    solaar
    wl-clipboard

    # --- Browsers ---
    brave
    (callPackage ../packages/brave-origin.nix {})
    firefox
    tor-browser
    google-chrome
    inputs.zen-browser.packages.x86_64-linux.default # Zen Browser

    # --- Communication & productivity ---
    keepassxc
    obsidian
    telegram-desktop
    signal-desktop
    thunderbird
    # vesktop
    zoom-us
    claude-code
    rtk
    antigravity

    # --- Media, graphics & documents ---
    feh
    ffmpeg
    ghostscript
    # gimp3
    imagemagick
    # inkscape
    kdePackages.gwenview # KDE image viewer
    kdePackages.okular
    krita
    libheif
    mpv
    nautilus
    nemo
    # obs-studio
    vlc
    onlyoffice-desktopeditors
    xournalpp
    typst
    # (texlive.combine {inherit (texlive) scheme-full;})
    zathura # PDF viewer with SyncTeX inverse search

    # --- Data & databases ---
    dbeaver-bin
    # litecli # disabled: cli-helpers tests fail in unstable (Pygments ANSI mismatch)
    sqlite
    sqlitebrowser
    tableplus

    # --- Security testing ---
    burpsuite
    # caido-desktop

    # --- Games ---
    prismlauncher

    # --- Fun & misc ---
    blahaj
    gay # rainbow output filter
    ponysay
  ];
}
