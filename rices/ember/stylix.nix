{
  pkgs,
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable {
  # stylix's gtk target now sets `gtk.gtk4.theme = config.gtk.theme` (adw-gtk3).
  # We deliberately leave gtk4/libadwaita apps unthemed, so override it back to
  # null — mkForce is required because stylix defines a non-null value and the
  # `nullOr submodule` type can't merge null with a value.
  gtk.gtk4.theme = lib.mkForce null;

  stylix = {
    enable = true;
    # Ember 3400K Dark — https://github.com/carpdiem/ember
    # Palette authored to stay distinguishable under the colour-temperature
    # filter tempest runs (wlsunset, homes/tempest/default.nix, night 4000K).
    # oxocarbon-dark's blues/magentas collapse into each other once warmed.
    base16Scheme = ./ember-3400k-dark.yaml;

    # The scheme is dark, but stylix's `polarity` defaults to "either" — and
    # every target that branches on it picks the *light* side of the branch when
    # it isn't "dark". That silently declared a light desktop underneath a dark
    # palette: noctalia's `theme.mode = "light"` (modules/noctalia/hm.nix in the
    # stylix store path), Qt's icon theme = breeze instead of breeze-dark, and
    # `org/gnome/desktop/interface color-scheme = "default"` instead of
    # "prefer-dark" — which is what GTK apps and both browsers read through the
    # portal to decide whether to render dark. It went unnoticed for noctalia
    # because its own settings.toml carried `mode = "dark"` on top; the moment
    # that file was rejected (config_version drift) the light fallback showed.
    polarity = "dark";

    # Icon theme for Qt/KDE apps (Dolphin, Okular, …). Off by default; without
    # it only `hicolor` is present and Dolphin's toolbar/file icons fall back
    # to blanks. Stylix wires this into both gtk.iconTheme and the qtct config.
    icons = {
      enable = true;
      package = pkgs.kdePackages.breeze-icons;
      dark = "breeze-dark";
      light = "breeze";
    };

    # Nothing set a cursor theme, so wlroots fell back to the X11 core cursor
    # (the blocky black arrow) under mango — niri only looked fine because
    # smithay ships a nicer built-in fallback. stylix.cursor drives
    # home.pointerCursor, which is what themes the cursor *clients* draw and
    # exports XCURSOR_THEME/XCURSOR_SIZE; the two compositors draw their own
    # cursor from their own config, so the same name is repeated in
    # compositors/{niri,mango} — keep the three in sync.
    # -Classic is the black variant; -Ice (white) and -Amber (orange) are the
    # other two.
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 20;
    };

    targets = {
      neovim.enable = false;
      vscode.enable = false;
      waybar.enable = false;

      # Terminals are themed by stylix directly (base16 ember-3400k-dark). kitty's
      # target appends `include /nix/store/<hash>-base16.conf` to kitty.conf; that
      # store-root include is fine, but kitty.nix sets `auto_reload_config = -1` so
      # the config-reload watcher never spawns (it watches kitty.conf's realpath
      # parent — /nix/store — recursively, ~470k inotify watches, which exhausted
      # fs.inotify.max_user_watches and broke Vite/yarn with ENOSPC). Colors are
      # build-time static now, so there's nothing to hot-reload.
      alacritty.enable = true;
      kitty.enable = true;
      wezterm.enable = true;
      # fish syntax-highlight colors + OSC palette from the same base16 scheme.
      # (Was off only because Noctalia's runtime terminal palette fought fish's
      # OSC — that relay is gone.)
      fish.enable = true;

      # Qt is handled in qt.nix, not by stylix's qt target: that target is
      # Kvantum-only (warns if you change the style) and its `autoEnable` is gated
      # on `nixosConfig != null`, so it doesn't even apply under standalone HM —
      # plus Kvantum under standalone HM hits home-manager#6565. qt.nix keeps
      # style=Fusion and generates a qtct ColorScheme from config.lib.stylix.colors.
      qt.enable = false;
    };

    fonts = {
      # sizes.terminal is NOT set here. A readable terminal size is a function of
      # the panel it is read on, so it is machine policy and comes from
      # homes/<host>/ (tempest: 16, in homes/tempest/default.nix). This used to be
      # an `if hostname == "tempest" … else if hostname == "orchid"` ladder inside
      # the rice — which put host *names* in a module that is supposed to describe
      # a desktop, and whose orchid arm was dead anyway (orchid runs estradiol,
      # which has its own ladder in rices/estradiol/stylix.nix). Unset, stylix's
      # own default applies. See "machine policy" in CONTEXT.md.

      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      monospace = {
        package = pkgs.maple-mono.truetype;
        name = "Maple Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}
