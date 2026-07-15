{ lib, config, ... }:
lib.mkIf config.rices.niri.enable {
  # Colors come from stylix's alacritty target (see stylix.nix). This module only
  # sets structural/behavioural options.
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";

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
