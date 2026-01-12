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
    ../desktop/helix.nix
    # ../desktop/emacs
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

    packages = [ (pkgs.callPackage ../packages/cider-2.nix { }) ];

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
      settings.user = {
        name = "Irene";
        email = "git@irene.foo";
      };
    };

    # Development tools
    nix-index = {
      enable = true;
      # enableFishIntegration = true;
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

    # Emacs editor
    emacs = {
      enable = false;
      package = pkgs.emacs-pgtk;
    };

    # vscode = {
    #   enable = true;
    #   package = pkgs.vscode.fhsWithPackages (ps: with ps; [
    #     rustup
    #     zlib
    #     openssl.dev
    #     pkg-config
    #   ]);
    # };
  };

  services.wlsunset = {
    enable = true;
    latitude = 45.4642; # Milan, Italy
    longitude = 9.1900;
  };

  # Security services
  # services.gnome-keyring = {
  # enable = false;
  # components = [
  # "pkcs11"
  # "secrets"
  # "ssh"
  # ];
  # };
}
