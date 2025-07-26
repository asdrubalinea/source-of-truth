{ inputs, ... }:
{
  imports = [
    # Desktop environment and theming
    inputs.hyprland.homeManagerModules.default
    inputs.stylix.homeModules.stylix
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
