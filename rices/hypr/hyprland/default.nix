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

  systemd.user.services.swaybg = let
    wallpaper = builtins.fetchurl rec {
      name = "wallpaper-${sha256}.png";
      url = "https://image-1.uhdpaper.com/wallpaper/anime-girl-playing-game-4k-wallpaper-uhdpaper.com-162@1@n.jpg";
      sha256 = "17bnw0b342bhg9j70ni085aiypzp6jlrjq2r983sinffaljvqz3l";
    };
  in {
    Unit = {
      Description = "Wayland wallpaper daemon";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };

    Service = {
      ExecStart = "${pkgs.swaybg}/bin/swaybg --mode fill --image ${wallpaper}";
      Restart = "on-failure";
    };

    Install.WantedBy = ["graphical-session.target"];
  };
}
