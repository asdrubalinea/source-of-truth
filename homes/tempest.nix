{ pkgs, inputs, ... }:
let
  arc-size = pkgs.writeShellScriptBin "arc-size" ''
    awk '/^size / { printf "%.1f GiB\n", $3 / (1024*1024*1024) }' /proc/spl/kstat/zfs/arcstats
  '';

  nix-size = pkgs.writeShellScriptBin "nix-size" ''
    zfs list -o name,used -t filesystem,volume -Hp | awk -v dataset='zroot/local/nix' '$1 == dataset { printf "%.0f GiB\n", $2 / (1024*1024*1024) }'
  '';
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

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      userName = "Irene";
      userEmail = "git@asdrubalini.xyz";
    };

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };
  };

  services.gnome-keyring = {
    enable = false;
    components = [
      "pkcs11"
      "secrets"
      "ssh"
    ];
  };

  home.packages = with pkgs; [
    # --- System Utilities & Monitoring ---
    btop # Resource monitor
    coreutils # Basic utilities (ls, cp, mv, etc.)
    dool # Resource statistics tool (dstat replacement)
    fastfetch # System information fetcher
    file # Determine file type
    gnupg # Encryption and signing
    htop # Interactive process viewer
    hyfetch # System information fetcher (neofetch fork)
    lsof # List open files
    ntfs3g # NTFS filesystem driver
    nvtopPackages.amd # AMD GPU monitoring
    onefetch # Git repository information fetcher
    openssl # Cryptography toolkit
    pciutils # PCI utilities (lspci)
    smartmontools # Disk health monitoring (smartctl)
    usbutils # USB utilities (lsusb)
    sbctl
    glxinfo
    feh

    # --- File Management & Text Processing ---
    bat # Cat clone with syntax highlighting
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
    yek
    powertop

    # --- Networking ---
    curl # Data transfer utility
    dnsutils # DNS utilities (dig, nslookup)
    ipcalc # IP address calculator
    iperf3 # Network performance measurement
    postman # API testing tool
    traceroute # Network path tracing
    wget # Non-interactive network downloader
    yt-dlp # Video downloader

    # --- Development & Nix ---
    aider-chat # AI coding assistant in the terminal
    alejandra # Nix code formatter
    cachix # Nix binary cache management
    devenv # Nix-based development environment manager
    devbox # Nix-based development environment manager
    gitui # Terminal UI for Git
    inputs.nixvim.packages.${pkgs.system}.default # Neovim configuration
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
    grc # Generic Colouriser for command output
    screen # Terminal multiplexer
    starship # Cross-shell prompt
    tmux # Terminal multiplexer
    zellij # Terminal workspace and multiplexer

    # --- Desktop Environment & GUI Apps ---
    alacritty # GPU-accelerated terminal emulator
    blueberry # Bluetooth frontend
    chromium # Web browser
    ffmpeg # Multimedia framework (often a dependency)
    inputs.zen-browser.packages.x86_64-linux.default # Zen Browser
    keepassxc # Password manager
    kitty # GPU-based terminal emulator
    ladybird # SerenityOS web browser (experimental)
    mpv # Media player
    nemo # File manager
    networkmanagerapplet # NetworkManager systray applet
    obs-studio # Streaming and recording software
    obsidian # Note-taking application
    onlyoffice-desktopeditors # Office suite
    pavucontrol # PulseAudio volume control
    seahorse # GPG/SSH key manager GUI
    telegram-desktop # Messaging application
    tor-browser # Privacy-focused web browser
    vesktop # Vencord-enhanced Discord client
    vlc # Media player
    wezterm # GPU-accelerated terminal emulator
    wl-clipboard # Wayland clipboard utilities
    zoom-us # Video conferencing

    # --- Data Management ---
    dbeaver-bin # Universal database tool
    rclone # Sync files to cloud storage
    restic # Backup tool
    sqlite # SQLite database engine
    sqlitebrowser # SQLite database GUI

    # --- Fun & Miscellaneous ---
    blahaj # IKEA shark ASCII art
    evil-helix # (Likely a game or demo)
    gay # Colorizer tool? (check description if needed)
    ponysay # Cowsay reimplementation with ponies

    # --- Custom Scripts ---
    arc-size
    nix-size
  ];
}
