{ config, lib, ... }:
lib.mkIf config.rices.niri.enable {
  programs.kitty = {
    enable = true;
    settings = {
      # Fonts stay stylix (structural, build-time). Colors come from Noctalia's
      # runtime template (see include below + noctalia.nix theme.templates).
      font_family = config.stylix.fonts.monospace.name;
      font_size = config.stylix.fonts.sizes.terminal;

      # Keep auto_reload_config at the default (0 = system default, positive =
      # poll interval in seconds). This enables SIGUSR1 reload, which Noctalia
      # uses to push palette updates into running kitty instances after writing
      # ~/.config/kitty/themes/noctalia.conf. Without it (negative value blocks
      # both the watcher AND SIGUSR1) Noctalia's reload signal is silently
      # ignored, so the theme disappears whenever noctalia.conf is rewritten.
      #
      # The prior -1 was a workaround for inotify exhaustion: HM materializes
      # kitty.conf as a /nix/store symlink, and the __watch_conf__ kitten
      # watches that realpath's parent dir recursively. fs.inotify.max_user_watches
      # is set to 524288, which is enough headroom for the store paths plus dev
      # tools. If Vite/yarn inotify starvation resurfaces, increase the sysctl
      # rather than disabling SIGUSR1.
      auto_reload_config = 0;

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

    # Include Noctalia's runtime-generated palette. Kitty only warns (does not
    # fail) if the file is missing on first boot. Noctalia writes it on first
    # wallpaper apply, then sends SIGUSR1 to reload running kitty instances.
    extraConfig = "include ~/.config/kitty/themes/noctalia.conf";
  };
}
