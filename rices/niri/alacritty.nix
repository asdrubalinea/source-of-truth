{ lib, config, ... }:
lib.mkIf config.rices.niri.enable {
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";

      # Noctalia's runtime template writes a palette file here; alacritty
      # expands ~ and live-reloads on change. Silently ignored on first boot
      # before Noctalia has run its kitty/alacritty apply for the first time.
      general.import = [ "~/.config/alacritty/themes/noctalia.toml" ];

      window = {
        padding = {
          x = 4;
          y = 4;
        };
        decorations = "None";
        dimensions = {
          columns = 160;
          lines = 48;
        };
        dynamic_title = true;
      };

      scrolling = {
        history = 100000;
        multiplier = 10;
      };

      cursor = {
        style = {
          shape = "Beam";
          blinking = "Off";
        };
        thickness = 0.15;
        unfocused_hollow = true;
      };

      bell = {
        animation = "EaseOutExpo";
        duration = 150;
      };
    };
  };
}
