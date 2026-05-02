{ inputs, pkgs, ... }:
{
  imports = [
    # Desktop environment and theming
    inputs.hyprland.homeManagerModules.default
    inputs.stylix.homeModules.stylix

    # ../rices/estradiol
    ../rices/niri

    # Applications and tools
    ../desktop/zed-editor
    ../desktop/vscode.nix
    ../desktop/helix.nix
    ../desktop/emacs
    ../desktop/tmux.nix
    ../desktop/home-packages.nix

    # System utilities
    ../scripts/system-clean.nix
    ../scripts/config-apply.nix
    ../scripts/port-forward.nix

    # Shell and configuration
    ../misc/fish.nix
  ];

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";

    packages = [
      (pkgs.callPackage ../packages/cider-2.nix { })
      inputs.codex.packages.${pkgs.stdenv.hostPlatform.system}.default
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
