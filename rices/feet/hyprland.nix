{ pkgs, ... }: {
  home.packages = with pkgs; [ geoclue2 ];
  services.redshift = {
    enable = true;
    provider = "geoclue2";
  };

  wayland.windowManager.hyprland = {
    enable = true;

    # so that we use the version from NixOS
    package = null;
    portalPackage = null;

    settings = {
      debug.disable_logs = false;

      # Variables
      "$terminal" = "${pkgs.alacritty}/bin/alacritty";
      "$browser" = "${pkgs.flatpak}/bin/flatpak run app.zen_browser.zen";
      "$menu" = "${pkgs.tofi}/bin/tofi-run | xargs hyprctl dispatch exec --";
      "$mainMod" = "SUPER";

      "$redAlpha" = "f38ba8";
      "$yellowAlpha" = "f9e2af";
      "$peachAlpha" = "fab387";
      "$tealAlpha" = "94e2d5";
      "$skyAlpha" = "89dceb";
      "$mauveAlpha" = "cba6f7";

      exec-once = [
        "${pkgs.waybar}/bin/waybar &"
        "${pkgs.swww}/bin/swww-daemon &"
      ];

      exec = [
        "${pkgs.swww}/bin/swww img ~/.wallpaper"
      ];

      # Environment variables
      env = [
        # "XCURSOR_SIZE,48"
        # "XCURSOR_THEM,ccgruv"
        # "HYPRCURSOR_THEME,gruv"
        # "HYPRCURSOR_SIZE,48"
      ];

      xwayland = {
        force_zero_scaling = true;
      };

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;

        "col.active_border" = "rgba($redAlphaee) rgba($yellowAlphaee) rgba($peachAlphaee) 30deg";
        "col.inactive_border" = "rgba($mauveAlphaaa) rgba($tealAlphaee) rgba($skyAlphaee) 30deg";

        resize_on_border = true;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 5;
        active_opacity = 1.0;
        inactive_opacity = 1.0;

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          vibrancy = 0.1696;
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 5, myBezier"
          "windowsOut, 1, 5, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 2, default"
          "workspaces, 1, 3, default"
          "borderangle, 1, 100, linear, loop"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        permanent_direction_override = true;
      };

      master = {
        new_status = "master";
      };

      misc = {
        force_default_wallpaper = -1;
        disable_hyprland_logo = false;
      };

      input = {
        kb_layout = "us";
        kb_variant = "intl";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        follow_mouse = 1;
        sensitivity = -1.0;

        touchpad = {
          natural_scroll = true;
        };
      };

      gestures = {
        workspace_swipe = false;
      };

      # Keybindings
      bind = [
        "$mainMod, return, exec, $terminal"
        "ALT, space, exec, $menu"
        "$mainMod, space, exec, $menu"

        "$mainMod, Q, killactive,"
        # "$mainMod, M, exit,"
        "$SUPER_SHIFT, space, togglefloating,"
        # "$mainMod, P, pseudo,"
        # "$mainMod, J, togglesplit,"
        # "$mainMod, D, exec, vesktop"

        "$SUPER_SHIFT, B, exec, $browser"
        "$SUPER_SHIFT, S, exec, ${pkgs.hyprshot}/bin/hyprshot -m output --clipboard-only"
        "$mainMod, F, fullscreen"
        "$mainMod, v, layoutmsg, preselect d"
        "$mainMod, h, layoutmsg, preselect r"
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$SUPER_SHIFT, left, movewindow, l"
        "$SUPER_SHIFT, right, movewindow, r"
        "$SUPER_SHIFT, up, movewindow, u"
        "$SUPER_SHIFT, down, movewindow, d"

        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      bindl = [
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
        ", XF86AudioNext, exec, playerctl next"
      ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      workspace = [
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
        "10"
      ];
    };
  };
}
