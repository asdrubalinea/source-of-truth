{ pkgs, config, ... }:

let
  screen-toggle = pkgs.writeScriptBin "screen-toggle" ''
    #!${pkgs.stdenv.shell}
    read lcd < /tmp/lcd

    if [ "$lcd" -eq "0" ]; then
      swaymsg "output * dpms on"
      echo 1 > /tmp/lcd
    else
      swaymsg "output * dpms off"
      echo 0 > /tmp/lcd
    fi
  '';

  cfg = config.wayland.windowManager.sway.config;
  wallpaper = "${config.xdg.configHome}/wallpaper";

in
{

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    # extraOptions = [ "--unsupported-gpu" ];

    config = {
      modifier = "Mod4";
      terminal = "alacritty";
      menu = "rofi -show run";

      left = "h";
      down = "j";
      up = "k";
      right = "l";

      # output = { "*" = { bg = "${wallpaper} fill"; }; };

      colors = {
        focused = rec {
          border = "#a9b665";
          background = "#a9b665";
          text = "#a9b665";
          indicator = "#a9b665";
          childBorder = background;
        };

        focusedInactive = rec {
          border = "#7daea3";
          background = "#7daea3";
          text = "#7daea3";
          indicator = "#7daea3";
          childBorder = background;
        };

        unfocused = rec {
          border = "#7daea3";
          background = "#7daea3";
          text = "#7daea3";
          indicator = "#7daea3";
          childBorder = background;
        };

        urgent = rec {
          border = "#ff5555";
          background = "#ff5555";
          text = "#ff5555";
          indicator = "#ff5555";
          childBorder = background;
        };
      };

      input = {
        "1739:32552:MSFT0001:00_06CB:7F28_Touchpad" = {
          left_handed = "disabled";
          tap = "enabled";
          natural_scroll = "disabled";
          dwt = "enabled";
          accel_profile = "adaptive";
          pointer_accel = "-0.1";
        };

        "*" = { xkb_layout = "us"; };
      };

      gaps.inner = 12;
      window.border = 1;
      floating.border = 1;

      keybindings = {
        # Basics
        "${cfg.modifier}+Return" = "exec ${cfg.terminal}";
        "${cfg.modifier}+Shift+Return" = "exec ${cfg.terminal} -t Scratch";
        "${cfg.modifier}+c" = "exec ${pkgs.chromium}/bin/chromium";
        "${cfg.modifier}+o" = "exec ${pkgs.emacs}/bin/emacsclient --create-frame";
        "${cfg.modifier}+q" = "kill";
        "${cfg.modifier}+d" = "exec ${cfg.menu}";
        "${cfg.modifier}+Shift+c" = "reload";
        "${cfg.modifier}+Shift+e" =
          "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -b 'Yes, exit sway' 'swaymsg exit'";

        # Focus
        "${cfg.modifier}+${cfg.left}" = "focus left";
        "${cfg.modifier}+${cfg.down}" = "focus down";
        "${cfg.modifier}+${cfg.up}" = "focus up";
        "${cfg.modifier}+${cfg.right}" = "focus right";

        "${cfg.modifier}+Left" = "focus left";
        "${cfg.modifier}+Down" = "focus down";
        "${cfg.modifier}+Up" = "focus up";
        "${cfg.modifier}+Right" = "focus right";

        # Moving
        "${cfg.modifier}+Shift+${cfg.left}" = "move left";
        "${cfg.modifier}+Shift+${cfg.down}" = "move down";
        "${cfg.modifier}+Shift+${cfg.up}" = "move up";
        "${cfg.modifier}+Shift+${cfg.right}" = "move right";

        "${cfg.modifier}+Shift+Left" = "move left";
        "${cfg.modifier}+Shift+Down" = "move down";
        "${cfg.modifier}+Shift+Up" = "move up";
        "${cfg.modifier}+Shift+Right" = "move right";

        # Workspaces
        "${cfg.modifier}+1" = "workspace number 1";
        "${cfg.modifier}+2" = "workspace number 2";
        "${cfg.modifier}+3" = "workspace number 3";
        "${cfg.modifier}+4" = "workspace number 4";
        "${cfg.modifier}+5" = "workspace number 5";
        "${cfg.modifier}+6" = "workspace number 6";
        "${cfg.modifier}+7" = "workspace number 7";
        "${cfg.modifier}+8" = "workspace number 8";
        "${cfg.modifier}+9" = "workspace number 9";
        "${cfg.modifier}+0" = "workspace number 10";

        "${cfg.modifier}+Shift+1" = "move container to workspace number 1";
        "${cfg.modifier}+Shift+2" = "move container to workspace number 2";
        "${cfg.modifier}+Shift+3" = "move container to workspace number 3";
        "${cfg.modifier}+Shift+4" = "move container to workspace number 4";
        "${cfg.modifier}+Shift+5" = "move container to workspace number 5";
        "${cfg.modifier}+Shift+6" = "move container to workspace number 6";
        "${cfg.modifier}+Shift+7" = "move container to workspace number 7";
        "${cfg.modifier}+Shift+8" = "move container to workspace number 8";
        "${cfg.modifier}+Shift+9" = "move container to workspace number 9";
        "${cfg.modifier}+Shift+0" = "move container to workspace number 10";

        # Splits
        "${cfg.modifier}+b" = "splith";
        "${cfg.modifier}+v" = "splitv";

        # Layouts
        "${cfg.modifier}+s" = "layout stacking";
        "${cfg.modifier}+t" = "layout tabbed";
        "${cfg.modifier}+e" = "layout toggle split";
        "${cfg.modifier}+f" = "fullscreen toggle";

        "${cfg.modifier}+a" = "focus parent";

        "${cfg.modifier}+Shift+space" = "floating toggle";
        "${cfg.modifier}+space" = "focus mode_toggle";

        # Scratchpad
        "${cfg.modifier}+Shift+minus" = "move scratchpad";
        "${cfg.modifier}+minus" = "scratchpad show";

        # Resize mode
        "${cfg.modifier}+r" = "mode resize";

        # Media keys
        "XF86Calculator" = "exec ${screen-toggle}/bin/screen-toggle";
      };

      window.commands = [
        {
          criteria = { app_id = "mpv"; };
          command = "floating enable, move position center";
        }
        {
          criteria = { title = "Scratch"; };
          command = "floating enable, move position center";
        }
      ];

      focus = { followMouse = true; };
      bars = [{ command = "waybar"; }];

      assigns = {
        "9" = [{ app_id = "keepassxc"; }];
        "10" = [{ app_id = "telegram-desktop"; }];
      };

      startup = [
        {
          command =
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          always = true;
        }

        {
          command = "${pkgs.wlsunset}/bin/wlsunset -l 45.27 -L 9.09";
          always = true;
        }

        {
          command = "${pkgs.mako}/bin/mako";
          always = false;
        }

        {
          command = ''
            ${pkgs.swayidle}/bin/swayidle -w \
              timeout 600 'swaymsg "output * dpms off"' \
              resume 'swaymsg "output * dpms on"'
          '';
          always = false;
        }
      ];
    };
  };

  xdg.configFile."waybar" = {
    source = ./waybar;
    recursive = true;
  };

  # xdg.configFile."wallpaper".source = ./wallpaper;

  home.packages = with pkgs; [
    swayidle
    # xwayland # for legacy apps
    waybar # status bar
    mako # notification daemon
    grim # screenshot
    wlsunset
    rofi-wayland
    wl-clipboard

    hicolor-icon-theme

    # screen-toggle
  ];

  # Handle external displays
  services.kanshi = {
    enable = true;
  };

}
