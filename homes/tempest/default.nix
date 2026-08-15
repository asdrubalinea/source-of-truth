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
    ../../desktop/zellij.nix
    # ../../desktop/warp.nix
    ../../desktop/home-packages.nix
    ../../desktop/mimeapps.nix
    ../../desktop/telegram-sandbox.nix

    # System utilities
    # Applying and cleaning is `nh` (enabled in hosts/tempest/default.nix):
    # `nh os switch`, `nh home switch -b backup`, `nh clean all`.
    ../../scripts/update-home.nix
    ../../scripts/port-forward.nix
    ../../scripts/claude-sandboxed.nix
    ../../scripts/cage.nix
    ../../scripts/keep-awake.nix
    ../../scripts/ps5-audio.nix
    ../../scripts/sitrep.nix

    # Shell and configuration
    ../../misc/fish.nix
  ];

  # Activate the niri rice. Its machine policy stays out here: monitor layout is
  # ./monitors.nix. See docs/adr/0004-niri-rice-as-enable-module.md.
  #
  # `rices.niri.marquee` (docs/adr/0011) is machine policy too, and it lives in
  # ./monitors.nix rather than here: the band exists only because the QD-OLED is
  # mounted portrait, so it is derived from that file's `oledMount` switch
  # alongside the panel's rotation and logical size, off the one panel-identity
  # binding both need.
  rices.niri.enable = true;

  # Machine policy: readable terminal size on THIS machine's panels. A font size
  # is a function of the display it is read on, so the rice deliberately leaves
  # `stylix.fonts.sizes.terminal` unset (see rices/niri/stylix.nix) rather than
  # branching on hostname inside itself.
  stylix.fonts.sizes.terminal = 16;

  # Machine policy: where this machine is. Stated once, consumed twice — wlsunset
  # (below) needs a lat/long to compute sunset; Noctalia geocodes a place name via
  # api.noctalia.dev for its weather / night-light / auto-theme. The rice owns only
  # the invariant that Noctalia must not re-locate itself by IP
  # (`location.auto_locate = false`, rices/niri/noctalia.nix).
  programs.noctalia.settings.location.address = "Las Palmas, Spain";

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";

    packages = [
      sdrangel-xwayland # RTL-SDR Blog V4 frontend, XWayland-wrapped (see let-binding above + hardware/rtl-sdr.nix)
      pkgs.sdrpp # SDR++ — runs native Wayland fine (GLFW, no wrapper); links rtl-sdr-osmocom (V4-capable)
      # (pkgs.callPackage ../../packages/cider-2.nix { })
    ];

    # Pre-configure hyfetch (aliased to "neofetch" and "fetch") for the
    # lesbian pride flag. The config file is consumed by hyfetch --gen and
    # on every run; see https://github.com/hyfetch-project/hyfetch.
    file.".config/hyfetch.json" = {
      text = builtins.toJSON {
        preset = "lesbian";
        mode = "rgb";
        auto_detect_light_dark = false;
        light_dark = "dark";
        lightness = null;
        color_align.mode = "horizontal";
        backend = "neofetch";
        args = null;
        distro = null;
        pride_month_disable = false;
        custom_ascii_path = null;
        custom_presets = null;
        palette_glyph = null;
        palette_type = null;
      };
    };

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

    # distrobox autodetects a container manager by probing podman, then docker,
    # then lilipod. Both podman and docker are enabled on this host
    # (hosts/tempest/system/virtualization.nix), so leave nothing to the probe:
    # pin podman, which is the rootless one that shares $HOME under irene's uid.
    # If podman is broken, distrobox now says so instead of quietly building the
    # box under the rootful docker daemon.
    DBX_CONTAINER_MANAGER = "podman";
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

    # Reach GitLab.com over its alternate git+ssh port (443 via
    # altssh.gitlab.com) so pushes still work on networks that firewall
    # port 22. See:
    # https://about.gitlab.com/blog/gitlab-dot-com-now-supports-an-alternate-git-plus-ssh-port/
    ssh = {
      enable = true;
      # Opt out of HM's soon-to-be-removed default `Host *` block; its values
      # just mirror ssh's own built-in defaults, so there's nothing to keep.
      enableDefaultConfig = false;
      settings = {
        # Locally wezterm sets TERM=wezterm; remote hosts that lack the wezterm
        # terminfo entry (anything not running hydra/orchid's wezterm.terminfo)
        # then drop TUI apps like the mysql client to dumb-terminal mode — no
        # readline, no arrow keys, no tab completion. sshd always honours the
        # client-sent TERM (no AcceptEnv needed), so override it to a term every
        # host knows. The gitlab.com/github.com blocks below are more specific
        # and still win for their hosts.
        "*" = {
          SetEnv = {
            TERM = "xterm-256color";
          };
        };
        "gitlab.com" = {
          HostName = "altssh.gitlab.com";
          User = "git";
          Port = 443;
          IPQoS = "none";
        };
        "github.com" = {
          HostName = "ssh.github.com";
          User = "git";
          Port = 443;
          IPQoS = "none";
        };
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

  # (mako removed — rices/niri/noctalia.nix mkForce-disables it; Noctalia owns
  # notifications on this host, so the block only looked live.)

  # The only colour-temperature filter on this host. redshift used to be enabled
  # too (services/redshift.nix) but its `randr` backend has no X display under
  # niri: it exited 1 on every start and systemd restart-looped it forever.
  services.wlsunset = {
    enable = true;
    latitude = 28.1235; # Las Palmas de Gran Canaria, Spain
    longitude = -15.4363;
  };
}
