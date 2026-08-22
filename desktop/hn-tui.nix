{
  pkgs,
  config,
  ...
}: let
  toml = (pkgs.formats.toml {}).generate;

  inherit
    (config.lib.stylix.colors.withHashtag)
    base00
    base01
    base02
    base03
    base04
    base05
    base06
    base07
    base08
    base09
    base0A
    base0B
    base0C
    base0D
    base0E
    ;
in {
  home.packages = [pkgs.hackernews-tui];

  # hackernews-tui has no dark mode switch — it has one theme, and the built-in
  # default is HN's light cream (#f6f6ef on #242424). Recolouring it from the
  # stylix scheme takes both halves: `palette` (the 4-bit ANSI set the whole UI
  # draws from) *and* the handful of `component_style` defaults that hardcode
  # black-on-light hex instead of naming a palette entry — header, matched
  # highlight, link ids and the code blocks are invisible on a dark background
  # if left at their defaults. Anything not listed here keeps its default, which
  # is fine because the default already resolves through the palette.
  xdg.configFile."hn-tui.toml".source = toml "hn-tui.toml" {
    theme = {
      palette = {
        background = base00;
        foreground = base05;
        selection_background = base02;
        selection_foreground = base06;

        black = base00;
        red = base08;
        green = base0B;
        yellow = base0A;
        blue = base0D;
        magenta = base0E;
        cyan = base0C;
        white = base05;

        light_black = base03;
        light_red = base08;
        light_green = base0B;
        light_yellow = base0A;
        light_blue = base0D;
        light_magenta = base0E;
        light_cyan = base0C;
        light_white = base07;
      };

      component_style = {
        title_bar = {
          back = base09; # HN's orange bar, in the scheme's own orange
          front = base00;
          effect = "bold";
        };
        matched_highlight = {
          front = base00;
          back = base0A;
        };
        metadata.front = base04;
        loading_bar = {
          front = base0A;
          back = base0D;
        };

        header = {
          front = base0D;
          effect = "bold";
        };
        quote.front = base04;
        single_code_block = {
          front = base05;
          back = base01;
        };
        multiline_code_block = {
          front = base04;
          effect = "bold";
        };
        link.front = base0D;
        link_id = {
          front = base00;
          back = base0A;
        };

        current_story_tag.front = base07;
        ask_hn = {
          front = base08;
          effect = "bold";
        };
        tell_hn = {
          front = base0A;
          effect = "bold";
        };
        show_hn = {
          front = base0D;
          effect = "bold";
        };
        launch_hn = {
          front = base0B;
          effect = "bold";
        };
      };
    };
  };
}
