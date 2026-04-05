{ pkgs, ... }:
{
  programs.wezterm = {
    enable = true;
    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      config.term = "xterm-256color"

      -- Bell: play a sound via paplay since SystemBeep doesn't work on Wayland
      config.audible_bell = "Disabled"
      config.visual_bell = {
        fade_in_function = "EaseIn",
        fade_in_duration_ms = 75,
        fade_out_function = "EaseOut",
        fade_out_duration_ms = 75,
      }

      wezterm.on("bell", function(window, pane)
        wezterm.background_child_process({
          "${pkgs.libcanberra-gtk3}/bin/canberra-gtk-play", "-i", "bell",
        })
      end)

      -- Cursor
      config.default_cursor_style = "SteadyBar"

      -- Window
      config.window_padding = {
        left = 4,
        right = 4,
        top = 4,
        bottom = 4,
      }
      config.initial_cols = 160
      config.initial_rows = 48
      config.window_decorations = "NONE"

      return config
    '';
  };
}
