{ pkgs, inputs, ... }:
let
  user-apply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth/

    home-manager switch --flake '.#irene@orchid' "$@"

    popd
  '';

  system-apply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/persist/source-of-truth";
  }).systemApply;

  arc-size = (pkgs.writeShellScriptBin "arc-size" ''
    cat /proc/spl/kstat/zfs/arcstats | grep '^size ' | awk '{ print $3 }' | awk '{ print $1 / (1024 * 1024 * 1024) " GiB" }'
  '');

  nix-size = (pkgs.writeShellScriptBin "nix-size" ''
    zfs list -o name,used -t filesystem,volume -Hp | awk -v dataset='zroot/local/nix' '$1 == dataset { printf "%.0f GiB", $2/1024/1024/1024 }'
  '');
in {
  imports = [
    inputs.sops-nix.homeManagerModules.sops

    ../rices/feet

    ../desktop/zed-editor
    # ../desktop/emacs

    ../scripts/system-clean.nix

    ../misc/fish.nix
    ../misc/aliases.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

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
    onefetch
    fastfetch
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

    (pkgs.callPackage ../packages/cider-2.nix {})

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

    neovim
    luarocks
    lua

    prismlauncher

    # Custom
    user-apply
    system-apply

    arc-size
    nix-size

    aider-chat
  ];

  # programs.vscode = {
  #   enable = true;
  #   package = pkgs.vscode.fhsWithPackages
  #   (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
  # };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  sops = {
    age.sshKeyPaths = [ "/home/irene/.ssh/id_ed25519" ];
    defaultSopsFile = ./secrets.yaml;
  };
}
