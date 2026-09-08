{
  inputs,
  pkgs,
  lib,
  ...
}: let
  # SDRangel's OpenGL widgets segfault under Qt's Wayland plugin, which the
  # rice's global QT_QPA_PLATFORM=wayland selects. Pin this one app to XWayland
  # (niri runs xwayland-satellite, so `xcb` connects fine and the GL widgets are
  # stable). Must be --set, not --set-default, to beat the inherited value.
  sdrangel-xwayland = pkgs.symlinkJoin {
    name = "sdrangel-xwayland";
    paths = [pkgs.sdrangel];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/sdrangel --set QT_QPA_PLATFORM xcb";
  };
in {
  # Deliberately NOT imported, though still in the tree: rices/estradiol,
  # desktop/emacs, desktop/warp.nix, packages/cider-2.nix.
  imports = [
    # Desktop environment and theming
    inputs.stylix.homeModules.stylix

    ../../rices/ember # the ember rice (declares rices.ember.*; enabled below)
    ./monitors.nix # machine policy: monitor identities + layout (kanshi)
    ./lights.nix # machine policy: the desk strip follows the idle timers
    ./soft-reboot.nix # machine policy: Mod+Shift+R soft-reboot trigger (autologin gate lives in hosts/tempest/system/session.nix)
    # ./speakers.nix — built-in speaker DSP correction, off: leaks onto AirPods

    # Applications and tools
    ../../desktop/zed-editor
    ../../desktop/vscode.nix
    ../../desktop/helix.nix
    ../../desktop/mail
    ../../desktop/tmux.nix
    ../../desktop/zellij.nix
    ../../desktop/obsidian.nix
    ../../desktop/hn-tui.nix
    ../../desktop/home-packages.nix
    ../../desktop/yt-dlp.nix
    ../../desktop/mimeapps.nix
    ../../desktop/telegram-sandbox.nix

    # System utilities. Applying and cleaning is `nh` (enabled in
    # hosts/tempest/default.nix): `nh os switch`, `nh home switch -b backup`.
    ../../scripts/update-home.nix
    ../../scripts/port-forward.nix
    ../../scripts/claude-sandboxed.nix
    ../../scripts/cage.nix
    ../../scripts/ocelot.nix
    ../../scripts/keep-awake.nix
    ../../scripts/ps5-audio.nix
    ../../scripts/due-cuffie.nix
    ../../scripts/sitrep.nix

    # Shell and configuration
    ../../misc/fish.nix
  ];

  # Activate the ember rice; its machine policy stays out here (ADR 0004).
  # `rices.ember.marquee` (ADR 0011) is machine policy too and lives in
  # ./monitors.nix rather than here, derived from that file's `oledMount` switch:
  # the band exists only because the QD-OLED is mounted portrait.
  rices.ember.enable = true;

  # Both compositor layers side by side — the session is picked at the greeter
  # per login, not at rebuild time. There is no "current" one here; the
  # soft-reboot autologin is the only thing that names a default (niri).
  # See ADR 0012.
  rices.ember.niri.enable = true;
  rices.ember.mango.enable = true;

  # Machine policy: a readable terminal size on THIS machine's panels. The rice
  # deliberately leaves this unset rather than branching on hostname.
  stylix.fonts.sizes.terminal = 16;

  # Machine policy: where this machine is. Stated once, consumed twice —
  # wlsunset below needs a lat/long, Noctalia geocodes a place name. The rice
  # owns only the invariant that Noctalia must not re-locate itself by IP.
  programs.noctalia.settings.location.address = "Las Palmas, Spain";

  home = {
    username = "irene";
    homeDirectory = "/home/irene";
    stateVersion = "23.05";

    packages = [
      sdrangel-xwayland # RTL-SDR Blog V4 frontend, XWayland-wrapped (see above + hardware/rtl-sdr.nix)
      pkgs.sdrpp # SDR++ — runs native Wayland fine (GLFW, no wrapper); links rtl-sdr-osmocom (V4-capable)
    ];

    # hyfetch (aliased to neofetch/fetch), preset for the lesbian pride flag.
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
  };

  home.sessionVariables = {
    EDITOR = "${pkgs.helix}/bin/hx";

    # distrobox probes podman, then docker, then lilipod — and both of the first
    # two are enabled on this host, so leave nothing to the probe. Pinning
    # podman (the rootless one that shares $HOME under irene's uid) also means a
    # broken podman says so instead of quietly using the rootful daemon.
    DBX_CONTAINER_MANAGER = "podman";
  };

  programs = {
    home-manager.enable = true;

    git = {
      enable = true;
      signing.format = null;
      settings.user = {
        name = "Irene";
        email = "git@irene.foo";
      };
    };

    ssh = {
      enable = true;
      # Opt out of HM's soon-to-be-removed default `Host *` block; its values
      # just mirror ssh's own built-in defaults.
      enableDefaultConfig = false;

      # `ocelot` writes one stanza per dev VM into ~/.ssh/config.d/ (ADR 0013),
      # which is what makes everything that speaks ssh work by name,
      # `port-forward ocelot-<name> 3000` included. It has to be declared here
      # because HM owns ~/.ssh/config as a store symlink, so nothing can append
      # at runtime. A glob matching nothing is not an error, so this is inert
      # until the first ocelot exists.
      includes = ["config.d/*"];
      settings = {
        # wezterm sets TERM=wezterm locally, and remote hosts without that
        # terminfo entry drop TUI apps to dumb-terminal mode — no readline, no
        # arrow keys. sshd always honours the client-sent TERM, so override it
        # to something every host knows. The more specific blocks below still
        # win for their hosts.
        "*" = {
          SetEnv = {
            TERM = "xterm-256color";
          };
        };
        # Port 443 via altssh, so pushes work on networks that firewall 22.
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

    nix-index = {
      enable = true;
      enableFishIntegration = true;
    };

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

        # The right prompt is a readout column: flush-right, glanced at, never
        # read as prose. Both modules are off by default in starship and so are
        # absent from `$all` above — `status` prints only when non-zero, which
        # is the point (a failure that scrolled off is otherwise invisible), and
        # `time` isn't redundant with the bar's clock because the bar auto-hides
        # for burn-in (ADR 0009), leaving scrollback as the only place "when did
        # this run" is answerable — including in a log paste.
        #
        # Styles are ANSI names, never hexes: the terminal palette is ember's
        # (principle 4). bright-black is base03.
        right_format = "$status$time";
        status = {
          disabled = false;
          format = "[$status]($style) ";
          style = "bold red";
        };
        time = {
          disabled = false;
          format = "[$time]($style)";
          time_format = "%H:%M:%S";
          style = "bright-black";
        };
      };
    };
  };

  # The only colour-temperature filter on this host. redshift is gone: its
  # `randr` backend has no X display under niri, so it exited 1 on every start
  # and systemd restart-looped it forever.
  services.wlsunset = {
    enable = true;
    latitude = 28.1235; # Las Palmas de Gran Canaria, Spain
    longitude = -15.4363;
  };

  # Keep the Wayland client services alive across a compositor restart.
  #
  # A compositor going away pulls the socket out from under every client service
  # at once, and systemd's stock policy (RestartSec=100ms, 5 tries in 10s) burns
  # all five retries inside half a second — long before a new compositor exists.
  # Then the unit stops for good: swayidle exited 253 five times in 1.2s and sat
  # dead for three hours, so nothing in rices/ember/swayidle.nix ran at all.
  # Worse, a start-limit-hit unit ends up `inactive (dead)`, not `failed`, so it
  # never shows in `systemctl --user --failed` and the list looked clean.
  #
  # So retry indefinitely and slowly: StartLimitIntervalSec=0 kills the rate
  # limiter and 2s makes an unbounded retry cheap. PartOf=graphical-session.target
  # still stops these on a real logout, so nothing spins once the session is
  # genuinely over.
  #
  # wlsunset is the only Restart this block sets — it ships Restart=no, so one
  # disconnect ends it for the session. swayidle and kanshi already carry
  # Restart=always, and noctalia gets it in rices/ember/noctalia.nix (it fails a
  # different way, a clean exit 0 that on-failure ignores); noctalia is listed
  # here for the limiter only.
  #
  # ponytail: this trades the start limiter's one virtue — giving up loudly on a
  # permanently broken command — for a log line every 2s. A unit flapping for a
  # non-compositor reason now retries forever; `journalctl --user -u <unit>` is
  # where that shows up.
  systemd.user.services = lib.mkMerge [
    (lib.genAttrs ["swayidle" "kanshi" "wlsunset" "noctalia" "wayland-pipewire-idle-inhibit"] (_: {
      Unit.StartLimitIntervalSec = 0;
      Service.RestartSec = 2;
    }))
    {wlsunset.Service.Restart = lib.mkForce "always";}
  ];
}
