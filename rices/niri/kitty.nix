{ config, lib, ... }:
lib.mkIf config.rices.niri.enable {
  programs.kitty = {
    enable = true;
    settings = {
      # Fonts and colors both come from stylix's kitty target (see stylix.nix):
      # it sets programs.kitty.font from stylix fonts and appends the base16
      # color include to kitty.conf. This module only sets behaviour.

      # -1 disables the config-reload watcher entirely (both the inotify watch
      # AND SIGUSR1 reload). Colors are build-time static now — nothing pushes
      # runtime config changes — so the watcher is pure downside: it watches
      # kitty.conf's realpath parent (/nix/store) *recursively* (~470k watches),
      # which exhausted fs.inotify.max_user_watches and broke Vite/yarn (ENOSPC).
      auto_reload_config = -1;

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
      scrollback_lines = 100000;
      wheel_scroll_multiplier = 10;
    };
  };
}
