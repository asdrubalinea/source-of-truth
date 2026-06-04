{ inputs, lib, pkgs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  # Noctalia is the "shell" leg of the NNN stack — an all-in-one Quickshell
  # desktop shell (bar + launcher + notifications + lockscreen). On this trial
  # it replaces waybar (bar) and tofi (launcher), both dropped from the rice's
  # default.nix, and supersedes mako (notifications) — force mako off so two
  # notification daemons don't fight over the same dbus name.
  services.mako.enable = lib.mkForce false;

  programs.noctalia-shell = {
    enable = true;

    # ── Theming ──────────────────────────────────────────────────────────────
    # Colors are NOT set here: stylix ships a built-in `noctalia-shell` target
    # (stylix/modules/noctalia-shell/hm.nix) that maps all 16 Material-3 tokens
    # from the active base16 palette and also wires bar/panel opacity + fonts.
    # It auto-activates because programs.noctalia-shell.enable is true. Defining
    # `colors` here would just collide with it — let stylix be the source of
    # truth (matches how the rest of the rice is themed).

    # ── Declarative settings (pins ~/.config/noctalia/settings.json) ─────────
    # These keys don't overlap with the ones stylix's target sets (opacity +
    # fonts), so they merge cleanly. NOTE: pinning settings.json makes the
    # in-app settings GUI non-persistent (read-only store symlink) — but
    # predefinedScheme="" is required regardless: it's what stops Noctalia's
    # ColorSchemeService from regenerating colors.json over stylix's on startup.
    # The bar layout (position + widgets, incl. the five ported readouts) lives
    # in ./noctalia-widgets.nix; this module keeps shell enable + theming.
    settings = {
      colorSchemes = {
        useWallpaperColors = false; # use stylix's colors.json, don't matugen the wallpaper
        predefinedScheme = ""; # empty ⇒ ColorSchemeService won't overwrite colors.json
        darkMode = true; # catppuccin-mocha is a dark scheme
      };

      # swayidle owns lock-on-sleep (see swayidle.nix); avoid a double lock.
      general.lockOnSuspend = false;

      # Weather location. Noctalia geocodes location.name via api.noctalia.dev
      # then fetches from open-meteo. autoLocate MUST be off: its timer does IP
      # geolocation and overwrites location.name with the detected city
      # (LocationService.qml), which would clobber this pin.
      location = {
        name = "Las Palmas";
        autoLocate = false;
      };

      # The niri rice owns the wallpaper: awww (systemd user service in
      # ./wallpaper) draws ~/.wallpaper into niri's backdrop layer. Turn
      # Noctalia's wallpaper off entirely — it renders a per-screen Background
      # PanelWindow (layer surface) that otherwise paints an empty/solid sheet
      # OVER awww's backdrop, so the real wallpaper vanishes. NOTE:
      # noctaliaPerformance.disableWallpaper is the WRONG knob: Background.qml
      # only honours it while the power-saver "performance mode" is active
      # (gated behind noctaliaPerformanceMode). wallpaper.enabled=false is the
      # unconditional switch.
      wallpaper.enabled = false;
    };

    # ── Plugins (pins ~/.config/noctalia/plugins.json) ───────────────────────
    # Screen Toolkit (https://noctalia.dev/plugins/screen-toolkit): a bundle of
    # screenshot / annotate / record / color-pick / OCR / QR / palette / Lens /
    # webcam tools. Like settings.json, this file becomes a read-only store
    # symlink — it's the install *registry*, not the plugin code. On startup the
    # shell sparse-checkouts the enabled plugin's QML from `sourceUrl` into the
    # WRITABLE ~/.config/noctalia/plugins/screen-toolkit/ (not HM-managed), so
    # the code itself is fetched at runtime, not pinned in /nix/store.
    #
    # The plugin's OWN settings (screenshot dir, API keys, search engine) live in
    # plugins/screen-toolkit/settings.json. We deliberately DON'T pin those via
    # `pluginSettings` — leaving that path writable keeps the in-app settings
    # panel functional for the trial. Enshrine into `pluginSettings` later if a
    # config worth keeping emerges (same workflow as the bar; see ADR 0003).
    #
    # Runtime CLI deps are added to home.packages below — the shell scripts the
    # plugin runs need them on PATH.
    plugins = {
      version = 2;
      sources = [
        {
          enabled = true;
          name = "Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        screen-toolkit = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
      };
    };
  };

  # Screen Toolkit runtime dependencies. Only the ones not already in
  # desktop/home-packages.nix (which provides wl-clipboard, imagemagick, curl,
  # ffmpeg, jq, python3) or the system layer (xdg-desktop-portal). pygobject3 —
  # needed by the webcam-mirror tool's python — rides on the global python3
  # interpreter instead (see desktop/home-packages.nix); a second python3 here
  # would collide on bin/python3.
  home.packages = with pkgs; [
    grim # screenshot grabber (wlroots)
    slurp # region/window selection
    hyprpicker # wlroots color picker
    tesseract # OCR engine
    zbar # QR / barcode decode (zbarimg)
    translate-shell # Google Lens / translation backend
    wl-screenrec # hardware-encoded screen recording (wlroots)
    gifski # high-quality GIF encoding
  ];
}
