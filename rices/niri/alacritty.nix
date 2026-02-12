{ ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
      general = {
        live_config_reload = true;
      };

      cursor = {
        thickness = 0.15;
        unfocused_hollow = true;
        vi_mode_style = "Beam";

        style = {
          blinking = "Off";
          shape = "Beam";
        };
      };

      env = {
        TERM = "xterm-256color";
      };

      font = {
        # Font configuration handled by stylix
      };

      window = {
        dynamic_title = true;
        title = "Alacritty";
        decorations = "buttonless";

        padding = {
          x = 4;
          y = 4;
        };

        dimensions = {
          columns = 160;
          lines = 48;
        };
      };
    };
  };

  programs.kitty = {
    enable = true;
    settings = {
      dynamic_title = true;
      term = "xterm-256color";
      cursor_shape = "beam";
      cursor_blink_interval = 0;
      cursor_stop_blinking_after = 0;
      cursor_beam_thickness = 1.5;
      cursor_unfocused_hollow = true;
      window_padding_width = 4;
      initial_window_width = "160c";
      initial_window_height = "48c";
    };
  };
}
