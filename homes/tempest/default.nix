{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    # Desktop environment and theming
    inputs.hyprland.homeManagerModules.default
    inputs.stylix.homeModules.stylix

    # ../../rices/estradiol
    ../../rices/niri # the niri rice (declares rices.niri.*; enabled below)
    ./monitors.nix # machine policy: monitor identities + layout (kanshi)

    # Applications and tools
    ../../desktop/zed-editor
    ../../desktop/vscode.nix
    ../../desktop/helix.nix
    # ../../desktop/emacs
    ../../desktop/mail
    ../../desktop/tmux.nix
    ../../desktop/home-packages.nix
    ../../desktop/mimeapps.nix
    ../../desktop/telegram-sandbox.nix

    # System utilities
    ../../scripts/system-clean.nix
    ../../scripts/config-apply.nix
    ../../scripts/user-apply.nix
    ../../scripts/update-home.nix
    ../../scripts/port-forward.nix
    ../../scripts/claude-sandboxed.nix

    # Shell and configuration
    ../../misc/fish.nix
  ];

  # Activate the niri rice. Its machine policy stays out here: monitor layout is
  # ./monitors.nix, and the backup-health readout's watched units default
  # to tempest's in the rice options (rices.niri.backupWidget.*), so no override
  # is needed. See docs/adr/0004-niri-rice-as-enable-module.md.
  rices.niri.enable = true;

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";

    packages = [
      # (pkgs.callPackage ../../packages/cider-2.nix { })
      # inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # persistence."/persist/home/irene" = {
    #   directories = [
    #     "Downloads"
    #     "Music"
    #     "Pictures"
    #     "Documents"
    #     "Videos"
    #     ".gnupg"
    #     ".ssh"
    #     ".local/share/keyrings"
    #     ".local/share/direnv"
    #     {
    #       directory = ".local/share/Steam";
    #       method = "symlink";
    #     }
    #   ];
    #   files = [
    #     ".claude.json"
    #     ".bash_history"
    #     ".python_history" ".mysql_history"
    #   ];
    #   allowOther = true;
    # };
  };

  home.sessionVariables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };

  programs = {
    home-manager.enable = true;

    # Version control
    git = {
      enable = true;
      signing.format = null;
      settings.user = {
        name = "Irene";
        email = "git@irene.foo";
      };
    };

    # Development tools
    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

    # Enhanced shell prompt
    starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        add_newline = false;
        format = "$hostname$all";
        hostname = {
          ssh_only = false;
          format = "[$hostname]($style) ";
          style = "bold green";
        };
      };
    };
  };

  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
    };
  };

  services.wlsunset = {
    enable = true;
    latitude = 28.1235; # Las Palmas de Gran Canaria, Spain
    longitude = -15.4363;
  };
}
