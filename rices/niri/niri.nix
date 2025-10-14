{ pkgs
, inputs
, hostname
, ...
}:

{
  programs.niri.settings = {
    # Input configuration
    input = {
      keyboard = {
        xkb = {
          layout = "us";
          variant = "intl";
        };
      };

      touchpad = {
        tap = true;
        natural-scroll = true;
      };

      mouse = {
        natural-scroll = false;
      };
    };

    # Output/Monitor configuration
    outputs =
      if hostname == "orchid" then {
        "HDMI-A-1" = {
          mode = { width = 3440; height = 1440; refresh = 75.0; };
          position = { x = 0; y = 0; };
        };
        "DP-2" = {
          mode = { width = 2560; height = 1440; refresh = 60.0; };
          position = { x = 3440; y = 0; };
        };
      } else if hostname == "tempest" then {
        "eDP-1" = {
          mode = { width = 2880; height = 1920; refresh = 120.0; };
          scale = 2.0;
          position = { x = 0; y = 0; };
        };
        "DP-1" = {
          mode = { width = 3440; height = 1440; refresh = 100.0; };
        };
      } else { };

    # Layout configuration
    layout = {
      gaps = 5;
    };

    # Prefer no client-side decorations
    # prefer-no-csd = true;

    # Animations (conditional on host)
    # animations =
    #   if hostname == "orchid" then {
    #     slowdown = 1.0;
    #   } else {
    #     slowdown = 0.0;
    #   };

    # Spawn commands at startup
    spawn-at-startup = [
      { command = [ "${pkgs.waybar}/bin/waybar" ]; }
      { command = [ "${pkgs.swww}/bin/swww-daemon" ]; }
      { command = [ "${pkgs.swww}/bin/swww" "img" "~/.wallpaper" ]; }
    ];

    # Keybindings
    binds = with pkgs; {
      # Terminal and launcher
      "Mod+Return".action.spawn = [ "${wezterm}/bin/wezerm" ];
      "Mod+Space".action.spawn = [ "${tofi}/bin/tofi-drun" "--drun-launch=true" ];

      # Window management
      "Mod+Q".action.close-window = { };
      "Mod+F".action.fullscreen-window = { };

      # Focus movement
      "Mod+Left".action.focus-column-left = { };
      "Mod+Right".action.focus-column-right = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Down".action.focus-window-down = { };

      # Move windows
      "Mod+Shift+Left".action.move-column-left = { };
      "Mod+Shift+Right".action.move-column-right = { };
      "Mod+Shift+Up".action.move-window-up = { };
      "Mod+Shift+Down".action.move-window-down = { };

      # Browser
      "Mod+Shift+B".action.spawn = [ "${inputs.zen-browser.packages.x86_64-linux.beta}/bin/zen-beta" ];

      # Screenshots (using niri's built-in UI)
      "Mod+Shift+S".action.screenshot = { };
      "Mod+Shift+D".action.screenshot-screen = { };

      # Workspaces 1-10
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;
      "Mod+0".action.focus-workspace = 10;

      # Move to workspaces 1-10
      "Mod+Shift+1".action.move-window-to-workspace = 1;
      "Mod+Shift+2".action.move-window-to-workspace = 2;
      "Mod+Shift+3".action.move-window-to-workspace = 3;
      "Mod+Shift+4".action.move-window-to-workspace = 4;
      "Mod+Shift+5".action.move-window-to-workspace = 5;
      "Mod+Shift+6".action.move-window-to-workspace = 6;
      "Mod+Shift+7".action.move-window-to-workspace = 7;
      "Mod+Shift+8".action.move-window-to-workspace = 8;
      "Mod+Shift+9".action.move-window-to-workspace = 9;
      "Mod+Shift+0".action.move-window-to-workspace = 10;

      # Media keys
      "XF86AudioRaiseVolume".action.spawn = [ "${pamixer}/bin/pamixer" "-i" "5" ];
      "XF86AudioLowerVolume".action.spawn = [ "${pamixer}/bin/pamixer" "-d" "5" ];
      "XF86AudioMute".action.spawn = [ "${pamixer}/bin/pamixer" "--toggle-mute" ];
      "XF86MonBrightnessUp".action.spawn = [ "${brightnessctl}/bin/brightnessctl" "set" "5%+" ];
      "XF86MonBrightnessDown".action.spawn = [ "${brightnessctl}/bin/brightnessctl" "set" "5%-" ];

      # Media control
      "XF86AudioPlay".action.spawn = [ "${playerctl}/bin/playerctl" "play-pause" ];
      "XF86AudioNext".action.spawn = [ "${playerctl}/bin/playerctl" "next" ];
      "XF86AudioPrev".action.spawn = [ "${playerctl}/bin/playerctl" "previous" ];

      # Toggle floating (niri alternative - use center-column)
      # "Mod+Shift+Space".action.center-column = { };

      "Mod+E".action.toggle-overview = {};

      # Quit niri
      "Mod+Shift+E".action.quit.skip-confirmation = true;
    };
  };
}
