{
  lib,
  config,
  ...
}: {
  programs.zellij = {
    enable = true;
    settings = {
      show_welcome_banner = false;
      show_startup_tips = false;
      pane_frames = false;
      simplified_ui = true;

      # One line of chrome instead of two. The stock layout adds a bottom status
      # bar that is mostly a keybinding cheat sheet — decoration that isn't
      # information. `compact` folds the tab list and mode indicator into one top
      # line, which is the part that answers a question. The keys still work;
      # only the reminder that they exist is gone.
      default_layout = "compact";
    };

    # Two stylix mappings collapse against this palette:
    #
    # 1. Every "selected" role is base05-on-base04, and those are one step apart
    #    here — cream on cream. Keep stylix's fill, flip the ink to the ground,
    #    the same dark-on-colour shape ribbon_selected already uses.
    # 2. The tab bar's `+` is ribbon_unselected.base on .emphasis_1 and stylix
    #    maps BOTH to base05 — a solid cream block with an invisible glyph.
    #    Pointing emphasis_1 at base02 makes it read as the same raised chip as
    #    any unselected ribbon; it has no other use in either bar.
    #
    # `or false`, not a bare `config.stylix.enable`: this module is imported by
    # homes without a rice, which don't import the stylix HM module at all — so
    # the option doesn't merely evaluate false, the whole `config.stylix`
    # attribute is missing and selecting into it THROWS. That took
    # homeConfigurations."irene@orchid" down as soon as anything forced
    # home.file.
    themes = lib.mkIf (config.stylix.enable or false) (
      let
        inherit (config.lib.stylix.colors.withHashtag) base00 base02;
        ink = {base = lib.mkForce base00;};
      in {
        stylix.themes.default = {
          text_selected = ink;
          list_selected = ink;
          table_cell_selected = ink;
          ribbon_unselected.emphasis_1 = lib.mkForce base02;
        };
      }
    );
  };
}
