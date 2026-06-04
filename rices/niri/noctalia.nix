{ inputs, lib, ... }:
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
  };
}
