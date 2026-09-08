{
  pkgs,
  lib,
  config,
  ...
}: let
  # The rice's body face (CONTEXT.md: "body face / display face"). Also in
  # ./fonts.nix system-wide; declared here too because stylix puts font packages
  # in home.packages, and standalone HM must not depend on the NixOS layer
  # having been switched first.
  ioskeley-mono = pkgs.callPackage ../../packages/ioskeley-mono.nix {};
in
  lib.mkIf config.rices.ember.enable {
    # gtk4/libadwaita apps are deliberately left unthemed. mkForce because
    # stylix's gtk target defines a non-null value and `nullOr submodule` can't
    # merge null with a value.
    gtk.gtk4.theme = lib.mkForce null;

    stylix = {
      enable = true;
      # https://github.com/carpdiem/ember — authored to stay distinguishable
      # under wlsunset's warm filter, where oxocarbon-dark's blues and magentas
      # collapse into each other.
      base16Scheme = ./ember-3400k-dark.yaml;

      # Must be explicit. `polarity` defaults to "either", and every target that
      # branches on it takes the LIGHT side when it isn't "dark" — which
      # silently declared a light desktop under a dark palette (noctalia mode,
      # breeze instead of breeze-dark, and the gnome color-scheme key that GTK
      # apps and both browsers read through the portal).
      polarity = "dark";

      # Without this only `hicolor` is present and Dolphin's icons fall back to
      # blanks. Wired into both gtk.iconTheme and the qtct config.
      icons = {
        enable = true;
        package = pkgs.kdePackages.breeze-icons;
        dark = "breeze-dark";
        light = "breeze";
      };

      # THE one place the pointer is decided: this drives home.pointerCursor for
      # clients, and both compositors read this option for the cursor they draw
      # themselves. Without it wlroots fell back to the blocky X11 core cursor
      # under mango (niri only looked fine because smithay's fallback is nicer).
      #
      # capitaine, not Bibata: Bibata's Modern cut is rounded and glossy, the
      # soft register the bar deliberately left. `-white` is the light-on-dark
      # variant — the bare theme is dark, i.e. an empty outline on base00.
      cursor = {
        # 24 is a design size: capitaine's left_ptr embeds 24/30/36/48/60/72 and
        # nothing smaller, so Bibata's 20 would resample and soften it.
        package = pkgs.capitaine-cursors;
        name = "capitaine-cursors-white";
        size = 24;
      };

      targets = {
        neovim.enable = false;
        vscode.enable = false;
        waybar.enable = false;

        # Terminals are themed by stylix directly. kitty's target appends a
        # store-root include, which is fine, but see kitty.nix for why
        # `auto_reload_config = -1` has to go with it (the watcher walks
        # /nix/store recursively and exhausts inotify).
        alacritty.enable = true;
        kitty.enable = true;
        wezterm.enable = true;
        # (Was off only because Noctalia's runtime palette relay fought fish's
        # OSC — that relay is gone.)
        fish.enable = true;

        # Handled in kde.nix instead: this target only writes a .colors file and
        # a pointer, then relies on `plasma-apply-lookandfeel` to copy the
        # palette into kdeglobals — and there is no Plasma session here to run
        # it, so the colours never landed and Dolphin fell back to Breeze light.
        kde.enable = false;

        # Handled in qt.nix instead: this target is Kvantum-only, its autoEnable
        # is gated on `nixosConfig != null` so it never applies under standalone
        # HM anyway, and Kvantum there hits home-manager#6565.
        qt.enable = false;
      };

      fonts = {
        # sizes.terminal is deliberately unset — a readable terminal size
        # depends on the panel, so it is machine policy and comes from
        # homes/<host>/ (CONTEXT.md: "machine policy").

        # All three text slots are the same face, deliberately: this desktop has
        # ONE body face and it is monospaced. A slot is a *role* ("what
        # non-terminal UI renders in"), not a claim about proportionality, so a
        # mono face in `sansSerif` is not a category error.
        #
        # sansSerif is the slot with reach — noctalia, GTK3/4, Obsidian and Zed
        # chrome all resolve through it, and web body text does too via
        # `fonts.fontconfig.defaultFonts` in ./fonts.nix (stylix writes no
        # fontconfig generic aliases itself). serif has exactly one consumer,
        # Obsidian's textFontFamily, and there is no proportional text left to
        # justify a second face.
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
