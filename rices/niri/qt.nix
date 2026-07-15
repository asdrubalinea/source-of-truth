{ lib, config, ... }:
lib.mkIf config.rices.niri.enable (
  let
    inherit (config.lib.stylix.colors.withHashtag)
      base00 base01 base02 base03 base04 base05 base07 base0D base0E;

    # A qtct ColorScheme is 22 QPalette roles, in the fixed order qt5ct/qt6ct
    # expect (documented inline below). We derive them from the stylix base16
    # palette (catppuccin-mocha, set in stylix.nix) so Qt apps rendered with the
    # Fusion style match gtk/terminals/noctalia. This replaces the file Noctalia's
    # "qt" runtime template used to write at ~/.config/qt{5,6}ct/colors/noctalia.conf.
    paletteRow = lib.concatStringsSep ", " [
      base05 base01 base03 base02 base00 base01 # windowText button light midlight dark mid
      base05 base07 base05 base00 base00 base00 # text brightText buttonText base window shadow
      base0D base00 base0D base0E base01 base00 # highlight highlightedText link linkVisited alternateBase <unused>
      base01 base05 base04 base0D #               toolTipBase toolTipText placeholderText accent
    ];

    colorScheme = ''
      [ColorScheme]
      # Generated from the stylix base16 scheme (see rices/niri/stylix.nix).
      # Role order: windowText, button, light, midlight, dark, mid, text,
      # brightText, buttonText, base, window, shadow, highlight, highlightedText,
      # link, linkVisited, alternateBase, <unused>, toolTipBase, toolTipText,
      # placeholderText, accent
      active_colors=${paletteRow}
      inactive_colors=${paletteRow}
      disabled_colors=${paletteRow}
    '';

    # dir is "qt5ct" or "qt6ct" — the ColorScheme lives beside each tool's conf.
    qtctConf = dir: ''
      [Appearance]
      color_scheme_path=~/.config/${dir}/colors/stylix.conf
      custom_palette=true
      icon_theme=breeze-dark
      standard_dialogs=default
      style=Fusion
    '';
  in
  {
    # Qt platform-theme plumbing for the niri rice.
    #
    # We do NOT use stylix's qt target: it is Kvantum-only (warns on any other
    # style) and its autoEnable is gated on `nixosConfig != null`, so it doesn't
    # apply under standalone HM anyway — and Kvantum under standalone HM trips
    # home-manager#6565. Instead qtct selects style=Fusion and reads the base16
    # ColorScheme generated above.
    #
    # The rest of the stack:
    #   - HM's qt module installs qt5ct/qt6ct and sets QT_QPA_PLATFORMTHEME in the
    #     systemd user session.
    #   - niri.nix sets QT_QPA_PLATFORMTHEME (and drops QT_STYLE_OVERRIDE) in the
    #     niri session env so apps launched from key binds / launcher pick it up.
    #   - Icons: stylix.icons stays enabled (breeze-dark/breeze) for gtk.iconTheme;
    #     qtct.conf's icon_theme wires the same set into Qt apps.
    qt = {
      enable = true;
      platformTheme.name = "qtct";
      # Don't set style.name here — that would export QT_STYLE_OVERRIDE and bypass
      # qtct's style selection. Fusion is set in the qtct.conf below.
    };

    xdg.configFile = {
      "qt6ct/colors/stylix.conf".text = colorScheme;
      "qt5ct/colors/stylix.conf".text = colorScheme;
      "qt6ct/qt6ct.conf".text = qtctConf "qt6ct";
      "qt5ct/qt5ct.conf".text = qtctConf "qt5ct";
    };
  }
)
