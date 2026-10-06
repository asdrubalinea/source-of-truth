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
    # ./lights.nix # machine policy: the desk strip follows the idle timers
    ./soft-reboot.nix # machine policy: Mod+Shift+R soft-reboot trigger (autologin gate lives in hosts/tempest/system/session.nix)
    # ./speakers.nix — built-in speaker DSP correction, off: leaks onto AirPods

    # Applications and tools
    ../../desktop/zed-editor
    # ../../desktop/vscode.nix
    ../../desktop/helix.nix
    ../../desktop/flow.nix
    ../../desktop/mail
    ../../desktop/tmux.nix
    ../../desktop/zellij.nix
    ../../desktop/obsidian.nix
    ../../desktop/hn-tui.nix
    ../../desktop/home-packages.nix
    ../../desktop/opencode.nix
    ../../desktop/ssh.nix
    ../../desktop/starship.nix
    ../../desktop/yt-dlp.nix
    ../../desktop/mimeapps.nix
    ../../desktop/telegram-sandbox.nix
    ../../desktop/hyfetch.nix

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

    nix-index = {
      enable = true;
      enableFishIntegration = true;
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
