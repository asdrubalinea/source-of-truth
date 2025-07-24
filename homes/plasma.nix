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
    inputs.impermanence.homeManagerModules.impermanence

    ../desktop/zed-editor
    ../scripts/system-clean.nix
    ../scripts/config-apply.nix
    ../misc/fish.nix
    ../misc/aliases.nix

    ../desktop/home-packages.nix
    ../scripts/port-forward.nix
  ];

  home = {
    username = "plasma";
    homeDirectory = "/home/plasma";
    stateVersion = "24.11";

    #   persistence."/persist/home/plasma" = {
    #     directories = [
    #       "Downloads"
    #       "Music"
    #       "Pictures"
    #       "Documents"
    #       "Videos"
    #       "VirtualBox VMs"
    #       ".gnupg"
    #       ".ssh"
    #       ".zen"
    #       ".nixops"
    #       ".local/share/keyrings"
    #       ".local/share/direnv"
    #     ];
    #     files = [
    #       ".screenrc"
    #     ];
    #     allowOther = true;
    #   };
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

  home.packages = [
    arc-size
    nix-size
  ];
}
