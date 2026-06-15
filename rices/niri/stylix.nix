{ pkgs
, hostname
, lib
, config
, ...
}:
lib.mkIf config.rices.niri.enable {
  # stylix's gtk target now sets `gtk.gtk4.theme = config.gtk.theme` (adw-gtk3).
  # We deliberately leave gtk4/libadwaita apps unthemed, so override it back to
  # null — mkForce is required because stylix defines a non-null value and the
  # `nullOr submodule` type can't merge null with a value.
  gtk.gtk4.theme = lib.mkForce null;

  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";

    # Icon theme for Qt/KDE apps (Dolphin, Okular, …). Off by default; without
    # it only `hicolor` is present and Dolphin's toolbar/file icons fall back
    # to blanks. Stylix wires this into both gtk.iconTheme and the qtct config.
    icons = {
      enable = true;
      package = pkgs.kdePackages.breeze-icons;
      dark = "breeze-dark";
      light = "breeze";
    };

    targets = {
      neovim.enable = false;
      # Colors handed to Noctalia's runtime template (see alacritty.nix +
      # noctalia.nix theme.templates). Stylix still owns fonts/icons/Qt/wezterm.
      alacritty.enable = false;
      # Disabled on purpose: stylix's kitty target emits
      #   include /nix/store/<hash>-base16-<scheme>.conf
      # into kitty.conf. We inline the palette into programs.kitty.settings
      # from config.lib.stylix.colors instead (see kitty.nix) — same theme,
      # no store-root include.
      #
      # NOTE: removing this include does NOT bound kitty's inotify watches —
      # that was a misdiagnosis. kitty's config-reload watcher
      # (`kitten __watch_conf__`) watches each config file's parent directory
      # *recursively*, and Home Manager materializes kitty.conf itself as a
      # symlink whose realpath is a store-root file
      # (/nix/store/<hash>-hm_kittykitty.conf). So kitty recurses over all of
      # /nix/store (~470k watches) regardless of any include, exhausting
      # fs.inotify.max_user_watches and breaking Vite/yarn dev with ENOSPC.
      # The actual fix is `auto_reload_config = -1` in kitty.nix, which stops
      # the watcher from spawning. This target stays off for theme reasons.
      kitty.enable = false;
      wezterm.enable = true;
      vscode.enable = false;
      waybar.enable = false;
      # Qt theming is now owned by qt.nix + Noctalia's "qt" built-in template
      # (wallpaper-derived M3 palette → ~/.config/qt{5,6}ct/colors/noctalia.conf,
      # style=Fusion). Stylix's qt target would write a static base16 qtct config
      # selecting Kvantum, which conflicts with our managed conf and pins the
      # wrong style — keep it off.
      qt.enable = false;
    };

    fonts = {
      sizes = {
        terminal =
          if hostname == "tempest"
          then 16
          else if hostname == "orchid"
          then 22
          else 18;
      };

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
