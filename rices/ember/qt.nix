{
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable (
  let
    inherit
      (config.lib.stylix.colors.withHashtag)
      base00
      base01
      base02
      base03
      base04
      base05
      base07
      base0D
      base0E
      ;

    # A qtct ColorScheme is 22 QPalette roles in a fixed order (listed below),
    # derived here from the stylix base16 palette so Qt apps under the Fusion
    # style match gtk/terminals/noctalia. Replaces the file Noctalia's old "qt"
    # runtime template used to write.
    paletteRow = lib.concatStringsSep ", " [
      base05
      base01
      base03
      base02
      base00
      base01 # windowText button light midlight dark mid
      base05
      base07
      base05
      base00
      base00
      base00 # text brightText buttonText base window shadow
      base0D
      base00
      base0D
      base0E
      base01
      base00 # highlight highlightedText link linkVisited alternateBase <unused>
      base01
      base05
      base04
      base0D #               toolTipBase toolTipText placeholderText accent
    ];

    colorScheme = ''
      [ColorScheme]
      # Generated from the stylix base16 scheme (see rices/ember/stylix.nix).
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
  in {
    # Qt platform-theme plumbing. NOT stylix's qt target: it is Kvantum-only,
    # its autoEnable is gated on `nixosConfig != null` so it never applies under
    # standalone HM, and Kvantum there trips home-manager#6565. qtct selects
    # style=Fusion and reads the ColorScheme generated above instead.
    #
    # The rest of the stack: HM's qt module installs qt5ct/qt6ct and sets
    # QT_QPA_PLATFORMTHEME in the systemd user session; each compositor layer
    # sets it again in its own session env, so apps launched from key binds pick
    # it up; and stylix.icons stays enabled for gtk.iconTheme, with qtct.conf's
    # icon_theme wiring the same set into Qt apps.
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
