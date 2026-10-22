{
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable {
  # Colors come from stylix's alacritty target (see stylix.nix). This module only
  # sets structural/behavioural options.
  programs.alacritty = {
    enable = true;
    settings = {
      env.TERM = "xterm-256color";

      window = {
        # 12, matching wezterm/kitty/konsole — see ./wezterm.nix for why, and
        # why all four move together.
        padding = {
          x = 12;
          y = 12;
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

      # Block, not beam — see ./kitty.nix for why. `thickness` went with the
      # beam: alacritty only applies it to Beam and Underline.
      cursor = {
        style = {
          shape = "Block";
          blinking = "Off";
        };
        unfocused_hollow = true;
      };

      bell = {
        animation = "EaseOutExpo";
        duration = 150;
      };
    };
  };
}
