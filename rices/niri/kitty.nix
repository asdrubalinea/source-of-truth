{ config, ... }:
let
  # base16 palette from stylix (with leading '#'). Inlined here instead of
  # using stylix's kitty target, which would `include` a base16 .conf living at
  # the root of /nix/store — kitty's config watcher watches that file's parent
  # dir recursively, dragging the whole store into inotify (~266k watches per
  # terminal → ENOSPC). See the note in stylix.nix.
  c = config.lib.stylix.colors.withHashtag;
in
{
  programs.kitty = {
    enable = true;
    settings = {
      # Font follows stylix (disabling the kitty target above dropped the
      # font_family/font_size lines stylix used to inject).
      font_family = config.stylix.fonts.monospace.name;
      font_size = config.stylix.fonts.sizes.terminal;

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

      # --- base16 theme (standard base16-kitty mapping) ---
      background = c.base00;
      foreground = c.base05;
      selection_background = c.base05;
      selection_foreground = c.base00;
      url_color = c.base04;
      cursor = c.base05;
      cursor_text_color = c.base00;
      active_border_color = c.base03;
      inactive_border_color = c.base01;
      active_tab_background = c.base00;
      active_tab_foreground = c.base05;
      inactive_tab_background = c.base01;
      inactive_tab_foreground = c.base04;
      tab_bar_background = c.base01;

      # normal
      color0 = c.base00;
      color1 = c.base08;
      color2 = c.base0B;
      color3 = c.base0A;
      color4 = c.base0D;
      color5 = c.base0E;
      color6 = c.base0C;
      color7 = c.base05;
      # bright
      color8 = c.base03;
      color9 = c.base08;
      color10 = c.base0B;
      color11 = c.base0A;
      color12 = c.base0D;
      color13 = c.base0E;
      color14 = c.base0C;
      color15 = c.base07;
    };
  };
}
