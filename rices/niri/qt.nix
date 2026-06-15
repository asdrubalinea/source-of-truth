{ lib, config, ... }:
lib.mkIf config.rices.niri.enable {
  # Qt platform-theme plumbing for the niri rice.
  #
  # Noctalia's built-in "qt" template writes a QPalette ColorScheme file at
  # runtime (derived from the current wallpaper) to:
  #   ~/.config/qt5ct/colors/noctalia.conf
  #   ~/.config/qt6ct/colors/noctalia.conf
  #
  # This module owns the rest of the qtct stack:
  #   - HM's qt module installs qt5ct/qt6ct packages and sets
  #     QT_QPA_PLATFORMTHEME in the systemd user session.
  #   - xdg.configFile pins the main qtct.conf for each tool to select
  #     style=Fusion + point at Noctalia's color file. Only the [Appearance]
  #     section is managed here; qtct can update other sections (fonts,
  #     interface) via its GUI.
  #   - niri.nix sets QT_QPA_PLATFORMTHEME (and drops QT_STYLE_OVERRIDE) in
  #     the niri session env so apps launched from key binds / tofi-drun also
  #     pick this up (the systemd user session env doesn't reach them).
  #   - Icons: stylix.icons stays enabled (breeze-dark/breeze) for gtk.iconTheme;
  #     qtct.conf's icon_theme wires the same set into Qt apps.

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    # Don't set style.name here — that would export QT_STYLE_OVERRIDE and
    # bypass qtct's style selection entirely. Fusion is set in the qtct.conf
    # below; qtct applies it when QT_QPA_PLATFORMTHEME=qt5ct and no override
    # is present.
  };

  xdg.configFile = {
    "qt6ct/qt6ct.conf".text = ''
      [Appearance]
      color_scheme_path=~/.config/qt6ct/colors/noctalia.conf
      custom_palette=true
      icon_theme=breeze-dark
      standard_dialogs=default
      style=Fusion
    '';

    "qt5ct/qt5ct.conf".text = ''
      [Appearance]
      color_scheme_path=~/.config/qt5ct/colors/noctalia.conf
      custom_palette=true
      icon_theme=breeze-dark
      standard_dialogs=default
      style=Fusion
    '';
  };
}
