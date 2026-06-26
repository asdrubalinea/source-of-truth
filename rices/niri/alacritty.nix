{ lib, config, ... }:
lib.mkIf config.rices.niri.enable {
  # Noctalia's runtime "alacritty" builtin template writes its palette to
  # themes/noctalia.toml AND rewrites ~/.config/alacritty/alacritty.toml in place
  # to wire up the `general.import` below. Since HM already generates that exact
  # import line, the rewrite produces byte-identical content — but it replaces
  # HM's read-only store symlink with a real file. On the next `home-manager
  # switch -b backup` HM finds that real file in the way of its symlink and tries
  # to move it to alacritty.toml.backup; the previous run's read-only backup is
  # still there, so `mv` prompts ("replace ... overriding mode 0444?") and the
  # switch hangs. `force = true` makes HM overwrite the file in place with no
  # backup step, restoring the symlink cleanly; Noctalia re-touches it to
  # identical content on its next theme apply. Same fix as gtk.css in stylix.nix.
  xdg.configFile."alacritty/alacritty.toml".force = true;

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
