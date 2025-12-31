{ pkgs, inputs, ... }:
let
  user-apply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth/

    home-manager switch --flake '.#irene@orchid' "$@"

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
    # inputs.stylix.homeManagerModules.stylix

    ../rices/estradiol

    # ../desktop/zed-editor
    ../desktop/helix.nix
    # ../desktop/emacs

    ../scripts/system-clean.nix
    ../scripts/port-forward.nix

    ../misc/fish.nix
    ../desktop/tmux.nix

    ../desktop/home-packages.nix
    # ../desktop/orchid-gaming-packages.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";
  };

  home.sessionVariables = {
    EDITOR = "${pkgs.helix}/bin/hx";
  };

  # programs.nushell.enable = true;
  # services.vscode-server.enable = true;
  # services.vscode-server.enableFHS = true;

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
    package = pkgs.emacs-pgtk;
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Irene";
      email = "git@irene.foo";
    };
  };

  home.packages = with pkgs; [
    user-apply
    system-apply
    arc-size
    nix-size
  ];

  # programs.neovim = {
  #   enable = true;

  #   plugins = with pkgs.vimPlugins; [
  #     telescope-nvim
  #     telescope-fzf-native-nvim
  #   ];

  #   extraPackages = with pkgs; [
  #     lua-language-server
  #   ];
  # };

  # programs.vscode = {
  #   enable = true;
  #   package = pkgs.vscode.fhsWithPackages
  #   (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
  # };

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
