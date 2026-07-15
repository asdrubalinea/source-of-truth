{
  inputs,
  pkgs,
  ...
}: let
  # SDRangel segfaults under Qt's Wayland platform plugin (its OpenGL spectrum/
  # scope widgets crash on startup); the global QT_QPA_PLATFORM=wayland from the
  # niri rice (rices/niri/niri.nix) is what selects that plugin. Pin just this
  # app to XWayland — niri runs xwayland-satellite, so `xcb` connects fine and
  # the GL widgets are stable there. (Verified: SIGSEGV on wayland, clean on
  # xcb.) Must be --set, not --set-default, to override the inherited wayland.
  sdrangel-xwayland = pkgs.symlinkJoin {
    name = "sdrangel-xwayland";
    paths = [pkgs.sdrangel];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/sdrangel --set QT_QPA_PLATFORM xcb";
  };
in {
  imports = [
    # Desktop environment and theming
    inputs.hyprland.homeManagerModules.default
    inputs.stylix.homeModules.stylix

    # ../../rices/estradiol
    ../../rices/niri # the niri rice (declares rices.niri.*; enabled below)
    ./monitors.nix # machine policy: monitor identities + layout (kanshi)
    ./soft-reboot.nix # machine policy: Mod+Shift+R soft-reboot trigger (autologin gate lives in hosts/tempest/system/session.nix)
    # ./speakers.nix # machine policy: built-in speaker DSP correction (EasyEffects) — disabled: leaks onto AirPods

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
    ../../scripts/keep-awake.nix

    # Shell and configuration
    ../../misc/fish.nix
  ];

  # Activate the niri rice. Its machine policy stays out here: monitor layout is
  # ./monitors.nix. See docs/adr/0004-niri-rice-as-enable-module.md.
  rices.niri.enable = true;

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";

    packages = [
      sdrangel-xwayland # RTL-SDR Blog V4 frontend, XWayland-wrapped (see let-binding above + hardware/rtl-sdr.nix)
      pkgs.sdrpp # SDR++ — runs native Wayland fine (GLFW, no wrapper); links rtl-sdr-osmocom (V4-capable)
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
