{
  config,
  lib,
  ...
}:
lib.mkIf config.rices.ember.enable {
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
      # Block, not beam. A beam is the GUI-text-field cursor; a block is the one
      # a terminal has always had, and it is the only shape that shows you which
      # CELL you are on rather than which gap between cells. Blinking stays off
      # (interval 0). cursor_beam_thickness went with the beam.
      cursor_shape = "block";
      cursor_blink_interval = 0;
      cursor_stop_blinking_after = 0;
      cursor_unfocused_hollow = true;
      # 12, matching wezterm/alacritty/konsole — see ./wezterm.nix for
      # why, and why all four move together.
      window_padding_width = 12;
      initial_window_width = "160c";
      initial_window_height = "48c";
      scrollback_lines = 100000;
      wheel_scroll_multiplier = 10;
      # Touchpad (high-precision) scroll, on top of the compositor's own
      # scroll factor. Lower = slower.
      touch_scroll_multiplier = "1.0";
      # Both compositors tile and draw borders; no client-side titlebar.
      hide_window_decorations = true;
    };
    # Carried over from ./wezterm.nix: ALT+<digit> / ALT+Tab for tabs (Super
    # belongs to the compositor, bare CTRL+letters to tmux), and Ctrl/Super+
    # Backspace as ESC+^H, which prompt_toolkit TUIs read as delete-word.
    keybindings =
      {
        "alt+tab" = "goto_tab -1";
        "alt+0" = "goto_tab 999";
        "ctrl+backspace" = "send_text all \\x1b\\x08";
        "super+backspace" = "send_text all \\x1b\\x08";
      }
      // lib.listToAttrs (map (i: {
        name = "alt+${toString i}";
        value = "goto_tab ${toString i}";
      }) (lib.range 1 9));
  };
}
