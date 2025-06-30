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
    inputs.stylix.homeModules.stylix

    ../rices/estradiol
    ../desktop/zed-editor
    ../scripts/system-clean.nix
    ../scripts/config-apply.nix
    ../misc/fish.nix
    ../misc/aliases.nix

    ../desktop/home-packages.nix
    ../scripts/port-forward.nix
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

    vscode = {
      enable = true;
      package = pkgs.vscode.fhsWithPackages (ps: with ps; [ 
        rustup zlib openssl.dev pkg-config 
      ]);
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
    arc-size
    nix-size
  ];
}
