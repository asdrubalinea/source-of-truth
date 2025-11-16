{ pkgs, inputs, ... }:

{
  imports = [
    ../misc/fish.nix
    ../scripts/config-apply.nix
    ../scripts/system-clean.nix
  ];

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "24.11";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      settings.user = {
        name = "Irene";
        email = "git@asdrubalini.xyz";
      };
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    # Enhanced shell experience
    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        format = "$hostname$all";
        hostname = {
          ssh_only = false;
          format = "[$hostname]($style) ";
          style = "bold green";
        };
      };
    };

    # Better directory listing
    eza = {
      enable = true;
      enableFishIntegration = true;
    };

    # Better cat with syntax highlighting
    bat = {
      enable = true;
    };

    # Fuzzy finder
    fzf = {
      enable = true;
      enableFishIntegration = true;
    };

    # Modern grep alternative
    ripgrep = {
      enable = true;
    };

    # Terminal multiplexer
    tmux = {
      enable = true;
      terminal = "screen-256color";
      keyMode = "vi";
      customPaneNavigationAndResize = true;

      extraConfig = ''
        # Enable mouse support
        set -g mouse on

        # Start windows and panes at 1, not 0
        set -g base-index 1
        setw -g pane-base-index 1

        # Reload config file
        bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

        # Split panes using | and -
        bind | split-window -h
        bind - split-window -v

        # Switch panes using Alt-arrow without prefix
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D
      '';
    };

    # Development environment
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  # CLI development packages
  home.packages = with pkgs; [
    # Neovim configuration
    inputs.nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Core development tools
    htop
    tree
    unzip
    zip

    # Development languages and tools
    nodejs_20
    python3
    rustc
    cargo
    gcc
    gnumake

    # CLI utilities
    ripgrep
    fd
    bat
    eza
    fzf
    jq
    yq-go

    # Network tools
    nmap
    netcat
    socat
    httpie

    # System tools
    tmux
    screen
    zellij

    # Version control
    lazygit

    # File management
    ranger

    # System monitoring
    btop
    ncdu

    # Development tools
    just
    watchexec
    tokei

    # Language servers for neovim
    rust-analyzer
    nil # Nix language server

    claude-code
  ];

  # Service configurations
  services = {
    # Auto-cleanup old generations
    home-manager.autoUpgrade = {
      enable = false; # Disabled by default for stability
    };
  };

  # XDG configuration
  xdg = {
    enable = true;
  };
}
