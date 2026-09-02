{
  pkgs,
  lib,
  config,
  ...
}: let
  # The rice's body face — see "body face / display face" in CONTEXT.md. Also
  # installed system-wide in ./fonts.nix; declared here too because stylix puts
  # its font packages in home.packages, and standalone HM must not depend on the
  # NixOS layer having been switched first.
  ioskeley-mono = pkgs.callPackage ../../packages/ioskeley-mono.nix {};
in
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
      #
      # capitaine-cursors, not Bibata: Bibata's Modern cut is a rounded, glossy
      # pointer, which is the same soft register the bar's radius used to be in
      # and now isn't. Capitaine is flat and hard-edged and its hotspot tip is
      # an actual point. `-white` is the light-on-dark variant — the bare
      # `capitaine-cursors` theme in the same package is the dark one, which on
      # a base00 ground is an outline with nothing inside it.
      cursor = {
        # 24, not Bibata's 20: capitaine's left_ptr embeds 24/30/36/48/60/72 and
        # nothing smaller, so 20 would have XCursor resample the 24px bitmap and
        # hand back a soft pointer. 24 is a design size — see "legible size
        # range" in CONTEXT.md.
        package = pkgs.capitaine-cursors;
        name = "capitaine-cursors-white";
        size = 24;
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

        # All three text slots are the same face, deliberately. This desktop has
        # ONE body face (CONTEXT.md: "body face / display face") and it is
        # monospaced — Ioskeley Mono, an Iosevka cut shaped after Berkeley Mono.
        # A slot here is a *role* ("what non-terminal UI renders in"), not a
        # claim about proportionality, so putting a mono face in `sansSerif` is
        # not a category error: it is how you say "the interface reads like the
        # terminal does".
        #
        # sansSerif is the slot with reach — noctalia, GTK3, GTK4, Obsidian's
        # interface and Zed's chrome all resolve through it. Web page body text
        # does NOT: stylix writes no fontconfig generic aliases on this host
        # (~/.config/fontconfig/conf.d is empty; /etc/fonts/conf.d/52-nixos-
        # default-fonts.conf still says DejaVu), so a page asking for
        # `font-family: sans-serif` is unaffected by this.
        #
        # serif has exactly one consumer, Obsidian's `textFontFamily`. There is
        # no proportional text left on the desktop to justify a second face, so
        # it points at the same one rather than at a face nothing else uses.
        serif = {
          package = ioskeley-mono;
          name = "Ioskeley Mono";
        };

        sansSerif = {
          package = ioskeley-mono;
          name = "Ioskeley Mono";
        };

        monospace = {
          package = ioskeley-mono;
          name = "Ioskeley Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  }
