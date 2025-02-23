{ ... }: {
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
        size = 20.0;

        bold = {
          family = "IosevkaTerm Nerd Font";
          style = "Bold";
        };

        bold_italic = {
          family = "IosevkaTerm Nerd Font";
          style = "Bold Italic";
        };

        italic = {
          family = "IosevkaTerm Nerd Font";
          style = "Italic";
        };

        normal = {
          family = "IosevkaTerm Nerd Font";
          style = "Regular";
        };
      };

      window = {
        dynamic_title = true;
        title = "Alacritty";
        decorations = "buttonless";
        opacity = 0.99;

        padding = {
          x = 5;
          y = 5;
        };

        dimensions = {
          columns = 160;
          lines = 48;
        };
      };

      # Synthwave 84
      colors = {
        primary = {
          foreground = "#ffffff";
          background = "#13111a";
        };

        normal = {
          black = "#262335";
          red = "#fe4450";
          green = "#72f1b8";
          yellow = "#f3e70f";
          blue = "#03edf9";
          magenta = "#ff7edb";
          cyan = "#03edf9";
          white = "#ffffff";
        };

        bright = {
          black = "#614d85";
          red = "#fe4450";
          green = "#72f1b8";
          yellow = "#fede5d";
          blue = "#03edf9";
          magenta = "#ff7edb";
          cyan = "#03edf9";
          white = "#ffffff";
        };
      };

      # # Challenger deep
      # colors = {
      #   primary = {
      #     background = "0x1b182c";
      #     foreground = "0xcbe3e7";
      #   };

      #   normal = {
      #     black = "0x100e23";
      #     red = "0xff8080";
      #     green = "0x95ffa4";
      #     yellow = "0xffe9aa";
      #     blue = "0x91ddff";
      #     magenta = "0xc991e1";
      #     cyan = "0xaaffe4";
      #     white = "0xcbe3e7";
      #   };

      #   bright = {
      #     black = "0x565575";
      #     red = "0xff5458";
      #     green = "0x62d196";
      #     yellow = "0xffb378";
      #     blue = "0x65b2ff";
      #     magenta = "0x906cff";
      #     cyan = "0x63f2f1";
      #     white = "0xa6b3cc";
      #   };
      # };
    };
  };
}
