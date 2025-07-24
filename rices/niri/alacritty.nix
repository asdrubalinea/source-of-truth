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
          x = 8;
          y = 8;
        };

        dimensions = {
          columns = 160;
          lines = 48;
        };
      };
    };
  };
}
