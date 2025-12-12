{ pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    # --- System Utilities & Monitoring ---
    btop # Resource monitor
    coreutils # Basic utilities (ls, cp, mv, etc.)
    dool # Resource statistics tool (dstat replacement)
    fastfetch # System information fetcher
    # feh # Lightweight image viewer
    file # Determine file type
    # mesa-demos # OpenGL information utility
    gnupg # Encryption and signing
    htop # Interactive process viewer
    hyfetch # System information fetcher (neofetch fork)
    lsof # List open files
    ntfs3g # NTFS filesystem driver
    nvtopPackages.amd # AMD GPU monitoring
    onefetch # Git repository information fetcher
    jujutsu
    lazyjj
    openssl # Cryptography toolkit
    pciutils # PCI utilities (lspci)
    powertop # Power consumption monitoring
    sbctl # UEFI Secure Boot key management
    smartmontools # Disk health monitoring (smartctl)
    usbutils # USB utilities (lsusb)
    yek # System monitoring tool
    nautilus
    nnn
    lm_sensors
    nmap
    restic

    # --- File Management & Text Processing ---
    bat # Cat clone with syntax highlighting
    cdrtools # CD/DVD writing tools
    csvlens # CSV file viewer
    czkawka # File duplicate finder/cleaner
    eza # Modern replacement for ls
    fd # Simple, fast find alternative
    jq # Command-line JSON processor
    ripgrep # Fast search tool (grep alternative)
    sshfs # Mount remote filesystems over SSH
    unzip # Extract zip archives
    xxd # Make a hexdump or do the reverse
    yazi # Terminal file manager
    zip # Create zip archives
    lz4
    ncdu

    # --- Networking ---
    curl # Data transfer utility
    dnsutils # DNS utilities (dig, nslookup)
    ipcalc # IP address calculator
    iperf3 # Network performance measurement
    networkmanagerapplet # NetworkManager systray applet
    postman # API testing tool
    traceroute # Network path tracing
    wget # Non-interactive network downloader
    yt-dlp # Video downloader

    # --- Development & Nix ---
    # aider-chat # AI coding assistant in the terminal
    alejandra # Nix code formatter
    # android-studio # Android IDE with SDK
    httptoolkit
    cachix # Nix binary cache management
    devenv # Nix-based development environment manager
    devbox # Nix-based development environment manager
    gitui # Terminal UI for Git
    just # Command runner
    lazygit # Simple terminal UI for Git
    lua # Lua programming language
    luarocks # Lua package manager
    lurk # Monitor Nix builds? (check description if needed)
    nil # Nix language server
    nix-tree # View Nix derivation trees
    nixd # Nix language server
    nixpkgs-fmt # Nix code formatter

    # --- Containerization & Virtualization ---
    distrobox # Use any Linux distribution inside your terminal
    dive # Explore Docker/OCI image layers
    docker-compose # Define and run multi-container Docker applications

    # --- Shell & Terminal Enhancements ---
    direnv # Load/unload environment variables depending on directory
    fzf # Command-line fuzzy finder
    ghostty # Configurable terminal emulator
    grc # Generic Colouriser for command output
    screen # Terminal multiplexer
    starship # Cross-shell prompt
    tmux # Terminal multiplexer
    zellij # Terminal workspace and multiplexer

    # --- Desktop Environment & GUI Apps ---
    alacritty # GPU-accelerated terminal emulator
    blueberry # Bluetooth frontend
    chromium # Web browser
    google-chrome
    brave
    dbeaver-bin # Universal database tool
    # inputs.helix.packages.x86_64-linux.default

    # pkgs.trunk.helix

    ffmpeg # Multimedia framework (often a dependency)
    inputs.zen-browser.packages.x86_64-linux.default # Zen Browser
    firefox
    keepassxc # Password manager
    kitty # GPU-based terminal emulator
    # ladybird # SerenityOS web browser (experimental)
    mpv # Media player
    nemo # File manager
    obs-studio # Streaming and recording software
    obsidian # Note-taking application
    # onlyoffice-desktopeditors # Office suite
    pavucontrol # PulseAudio volume control
    # prismlauncher # MultiMC/PolyMC fork for Minecraft
    seahorse # GPG/SSH key manager GUI
    telegram-desktop # Messaging application
    # tor-browser # Privacy-focused web browser
    vesktop # Vencord-enhanced Discord client
    vlc # Media player
    wezterm # GPU-accelerated terminal emulator
    wl-clipboard # Wayland clipboard utilities
    zoom-us # Video conferencing

    # --- Data Management ---
    rclone # Sync files to cloud storage
    restic # Backup tool
    sqlite # SQLite database engine
    sqlitebrowser # SQLite database GUI
    litecli

    # --- Fun & Miscellaneous ---
    blahaj # IKEA shark ASCII art
    gay # Colorizer tool? (check description if needed)
    ponysay # Cowsay reimplementation with ponies

    solaar # Logitech mouse manager
    kdePackages.okular

    krita
    inkscape
    gimp3
    libheif
    imagemagick

    # (pkgs.callPackage ../packages/cider-2.nix { })
    # rnix-lsp
    # inputs.mm.packages.x86_64-linux.default

    appimage-run
    asciinema
    # ladybird

    # kdePackages.dolphin
    # trunk.claude-code
    custom.codex
    # opencode
    nodejs
    # inputs.claude-desktop.packages.${system}.claude-desktop
    inputs.hn-tui-flake.packages.${pkgs.stdenv.hostPlatform.system}.hackernews-tui # hn command for Hacker News TUI
    thunderbird
    uv
    upower
    python3
    bun
    pkgs.burpsuite
  ];
}
