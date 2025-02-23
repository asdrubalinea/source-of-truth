{
  pkgs,
  ...
}: {
  home = {
    packages = with pkgs; [
      clipman
      grim
      pngquant
      slurp
      swayidle
      tesseract5
      wf-recorder
      wl-clipboard
    ];

    sessionVariables = {
      # XDG Specifications
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_TYPE = "wayland";
      XDG_SESSION_DESKTOP = "Hyprland";

      # QT Variables
      DISABLE_QT5_COMPAT = "0";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
      QT_QPA_PLATFORM = "wayland";
      QT_QPA_PLATFORMTHEME = "qt5ct";
      QT_STYLE_OVERRIDE = "kvantum";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # Toolkit Backend Variables
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      CLUTTER_BACKEND = "wayland";
      GDK_BACKEND = "wayland";
      MOZ_ENABLE_WAYLAND = "1";
    };
  };

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    extraConfig = import ./config.nix;
  };

  services.gammastep = {
    enable = true;
    provider = "geoclue2";
  };
}
