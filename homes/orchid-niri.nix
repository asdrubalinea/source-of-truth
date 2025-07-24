{ pkgs, inputs, ... }:
let
  user-apply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth/

    home-manager switch --flake '.#irene-niri@orchid' "$@"

    popd
  '';

  system-apply =
    (pkgs.callPackage ../scripts/system-apply.nix {
      configPath = "/persist/source-of-truth";
    }).systemApply;

  arc-size = (
    pkgs.writeShellScriptBin "arc-size" ''
      cat /proc/spl/kstat/zfs/arcstats | grep '^size ' | awk '{ print $3 }' | awk '{ print $1 / (1024 * 1024 * 1024) " GiB" }'
    ''
  );

  nix-size = (
    pkgs.writeShellScriptBin "nix-size" ''
      zfs list -o name,used -t filesystem,volume -Hp | awk -v dataset='zroot/local/nix' '$1 == dataset { printf "%.0f GiB", $2/1024/1024/1024 }'
    ''
  );
in
{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
    inputs.hyprland.homeManagerModules.default

    ../rices/niri

    ../desktop/zed-editor

    ../scripts/system-clean.nix
    ../scripts/port-forward.nix

    ../misc/fish.nix
    ../misc/aliases.nix

    ../desktop/home-packages.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";
  };

  services.gnome-keyring = {
    enable = true;
    components = [
      "pkcs11"
      "secrets"
      "ssh"
    ];
  };

  programs.emacs = {
    enable = false;
    package = pkgs.emacsPgtkGcc;
  };

  programs.git = {
    enable = true;
    userName = "Irene";
    userEmail = "git@asdrubalini.xyz";
  };

  home.packages = with pkgs; [
    user-apply
    system-apply
    arc-size
    nix-size
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages (ps: with ps; [
      rustup
      zlib
      openssl.dev
      pkg-config
    ]);
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };

  sops = {
    age.sshKeyPaths = [ "/home/irene/.ssh/id_ed25519" ];
    defaultSopsFile = ./secrets.yaml;
  };
}
