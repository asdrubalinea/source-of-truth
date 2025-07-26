{ inputs, ... }:
{
  imports = [
    # Desktop environment and theming
    inputs.hyprland.homeManagerModules.default
    inputs.stylix.homeModules.stylix
    inputs.impermanence.homeManagerModules.impermanence

    ../rices/estradiol

    # Applications and tools
    ../desktop/zed-editor
    ../desktop/tmux.nix
    ../desktop/home-packages.nix

    # System utilities
    ../scripts/system-clean.nix
    ../scripts/config-apply.nix
    ../scripts/port-forward.nix

    # Shell and configuration
    ../misc/fish.nix
    ../misc/aliases.nix
  ];

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";

    # packages = [ ];

    persistence."/persist/home/irene" = {
      directories = [
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"
        ".gnupg"
        ".ssh"
        ".local/share/keyrings"
        ".local/share/direnv"
        {
          directory = ".local/share/Steam";
          method = "symlink";
        }
      ];
      files = [
        ".claude.json" ".claude.json"
        ".bash_history"
        ".python_history" ".mysql_history"
      ];
      allowOther = true;
    };
  };

  programs = {
    home-manager.enable = true;

    # Version control
    git = {
      enable = true;
      userName = "Irene";
      userEmail = "git@asdrubalini.xyz";
    };

    # Development tools
    nix-index = {
      enable = true;
      enableFishIntegration = true;
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

  # Security services
  services.gnome-keyring = {
    enable = false;
    components = [
      "pkcs11"
      "secrets"
      "ssh"
    ];
  };
}
