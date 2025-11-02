{ pkgs, inputs, ... }:
{
  imports = [
    inputs.impermanence.homeManagerModules.impermanence

    ../desktop/zed-editor
    ../scripts/system-clean.nix
    ../scripts/config-apply.nix
    ../misc/fish.nix

    ../scripts/port-forward.nix
  ];

  home = {
    username = "claude";
    homeDirectory = "/home/claude";
    stateVersion = "24.11";

    persistence."/persist/home/claude" = {
      directories = [
        "workspace"
        ".local/share/direnv"
        ".cache"
      ];
      files = [
        ".screenrc"
      ];
      allowOther = true;
    };
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings.user = {
        name = "Claude";
        email = "claude@localhost";
      };
    };

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    direnv = {
      enable = true;
    };
  };

  home.packages = with pkgs; [
    # Claude Code - The main purpose of this user
    trunk.claude-code

    # System utilities needed for Claude Code
    coreutils
    file
    gnupg
    openssl

    # File management and text processing
    bat
    eza
    fd
    fzf
    jq
    ripgrep
    tree
    unzip
    xxd
    zip

    # Development tools and editors
    neovim
    inputs.nixvim.packages.${pkgs.system}.default

    # Build tools
    gnumake
    gcc

    # Version control
    git
    gitui
    lazygit

    # Language runtimes and tools
    nodejs
    python3
    rustc
    cargo
    lua

    # Nix development tools
    alejandra
    nil
    nixd
    nixpkgs-fmt
    nix-tree

    # Networking utilities
    curl
    wget
    dnsutils

    # Shell and terminal enhancements
    starship
    tmux
    zellij

    # Terminal emulators (in case needed)
    alacritty
    kitty

    # Monitoring and debugging
    btop
    htop
    lsof

    # Database tools
    sqlite

    # Text processing
    csvlens

    # Container/virtualization (if needed for development)
    distrobox

    # Language servers and formatters
    just
  ];

  # Create workspace directory
  home.file."workspace/.gitkeep".text = "";
}
