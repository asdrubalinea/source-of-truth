{ pkgs, ... }:
let
  userApply = pkgs.writeScriptBin "user-apply" ''
    #!${pkgs.stdenv.shell}
    pushd /persist/source-of-truth/

    home-manager switch --flake '.#irene@orchid' "$@"

    popd
  '';

  systemApply = (pkgs.callPackage ../scripts/system-apply.nix {
    configPath = "/persist/source-of-truth";
  }).systemApply;

  # sdrpp_custom =
  #   pkgs
  #   .sdrpp
  #   # .overrideAttrs
  #   # (oldAttrs: {
  #   #   src = pkgs.fetchFromGitHub {
  #   #     owner = "AlexandreRouma";
  #   #     repo = "SDRPlusPlus";
  #   #     rev = "e192cb963b4fb9753b0fcc00685e00697deaaf17";
  #   #     hash = "sha256-HglX8xQoYZbZqgqEL2F16W7K/xKuoEQrBMPacHD+5vc=";
  #   #   };
  #   #   # patches = attrs.patches ++ [../patches/sdrpp/add-radiomicrophones.patch];
  #   # });
  #   .override {sdrplay_source = true;};
in {
  imports = [
    # ../desktop/emacs
    # ../desktop/sway
    # ../rices/hypr

    ../scripts/system-clean.nix
    ../misc/fish.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.fish = {
    enable = true;
    shellInitLast = ''
      starship init fish | source
    '';
  };

  # programs.nushell.enable = true;
  services.vscode-server.enable = true;
  services.vscode-server.enableFHS = true;

  services.gnome-keyring = {
    enable = true;
    components = [ "pkcs11" "secrets" "ssh" ];
  };

  home.packages = with pkgs; [
    # System utils
    hyfetch
    pfetch
    htop
    dool
    sshfs
    pciutils
    file
    eza
    git
    bat
    jq
    unzip
    ripgrep
    usbutils
    openssl
    curl
    wget
    traceroute
    zip
    nixos-shell
    coreutils
    fd
    git-crypt
    lazygit
    gnupg
    fzf
    ipcalc
    iperf3
    zellij
    tmux
    screen
    grc
    devbox
    gay
    ponysay
    blahaj
    dive
    lsof
    lurk
    nix-tree
    yt-dlp
    ffmpeg
    starship
    nvtopPackages.amd
    stable.iozone
    fio
    smartmontools
    parted
    xxd

    # Nix
    nixpkgs-fmt
    # rnix-lsp
    gnumake

    alejandra
    nixd

    # Project management
    devenv
    direnv

    fontconfig
    cmake
    pkg-config
    quickemu
    distrobox

    # Rust
    # rust-analyzer
    clang
    oha

    # Docker
    docker-compose

    # Desktop
    # firefox
    keepassxc
    # chromium
    alacritty
    wezterm
    ghostty

    neovim
    luarocks
    lua

    trunk.zed-editor
    # sdrpp_custom

    # trunk.geekbench
    # prismlauncher

    # Custom
    userApply
    systemApply

    aider-chat
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      "$mod" = "SUPER";
      bind = [ "$mod, F, exec, firefox" ", Print, exec, grimblast copy area" ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
          builtins.concatLists (builtins.genList (x:
            let
              ws = let c = (x + 1) / 10;
              in builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, workspace, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]) 10));
    };
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.fhsWithPackages
      (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
}
