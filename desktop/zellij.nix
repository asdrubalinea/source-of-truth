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

      # One line of chrome instead of two. The stock layout stacks a tab bar on
      # top and a status bar on the bottom, and the status bar is mostly a
      # keybinding cheat sheet — the classic decoration-that-isn't-information
      # the rice spends its budget avoiding. `compact` is a built-in layout that
      # folds the tab list and the mode indicator into a single top line, which
      # is the part that answers a question. Ctrl+q etc. still work; only the
      # reminder that they exist is gone.
      default_layout = "compact";
    };

    # Two stylix mappings collapse against this palette.
    #
    # 1. Every "selected" text role is painted base05-on-base04. Ember's base04
    #    (#BDAE93) and base05 (#E8DCC4) are one step apart, so selected text
    #    lands as cream on cream. Keep stylix's fill, flip the ink to the ground
    #    colour — the same dark-on-colour shape ribbon_selected already uses.
    #
    # 2. The tab bar's `+` button is drawn as ribbon_unselected.base on
    #    ribbon_unselected.emphasis_1, and stylix maps *both* to base05 — a
    #    solid cream block with an invisible glyph. Point emphasis_1 at base02
    #    so the button reads as the same raised chip as any unselected ribbon.
    #    emphasis_1 has no other use in the tab or status bars.
    # `or false`, not a bare `config.stylix.enable`: this module is imported by
    # homes without a rice (homes/orchid.nix, homes/ocelot.nix) and those do not
    # import the stylix HM module at all, so the option does not merely evaluate
    # false — the whole `config.stylix` attribute is missing and selecting into
    # it throws. That took homeConfigurations."irene@orchid" down as soon as
    # anything forced home.file.
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
