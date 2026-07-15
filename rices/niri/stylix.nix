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
      vscode.enable = false;
      waybar.enable = false;

      # Terminals are themed by stylix directly (base16 catppuccin-mocha). kitty's
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
