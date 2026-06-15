{ config, lib, ... }:
lib.mkIf config.rices.niri.enable {
  programs.kitty = {
    enable = true;
    settings = {
      # Fonts stay stylix (structural, build-time). Colors come from Noctalia's
      # runtime template (see include below + noctalia.nix theme.templates).
      font_family = config.stylix.fonts.monospace.name;
      font_size = config.stylix.fonts.sizes.terminal;

      # Disable kitty's config auto-reload watcher. Home Manager materializes
      # kitty.conf as a symlink whose realpath is a store-root file
      # (/nix/store/<hash>-hm_kittykitty.conf), and kitty's `__watch_conf__`
      # kitten watches each config file's parent dir *recursively* — so the
      # watcher recurses over all of /nix/store (~470k inotify watches),
      # exhausting fs.inotify.max_user_watches and breaking Vite/yarn dev with
      # ENOSPC. A negative value turns the watcher off (boss.py gates it on
      # `auto_reload_config >= 0`).
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

    # Include Noctalia's runtime-generated palette. Kitty expands $HOME in
    # include paths and only warns (does not fail) if the file is missing on
    # first boot — Noctalia writes it on first wallpaper apply. The watcher
    # is off (auto_reload_config = -1) so Noctalia's apply.sh reload-signal
    # path drives live recolors rather than inotify.
    extraConfig = "include $\{HOME}/.config/kitty/themes/noctalia.conf";
  };
}
