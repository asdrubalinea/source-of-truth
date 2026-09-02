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
    };

    # Stylix paints every "selected" text role as base05-on-base04. Ember's
    # base04 (#BDAE93) and base05 (#E8DCC4) are one step apart, so the tab-bar's
    # `+` button and the tab-name text land as cream on cream — a bright blank
    # block. Keep stylix's fill, flip the ink to the ground colour, which is the
    # same dark-on-colour shape ribbon_selected already uses.
    themes = lib.mkIf config.stylix.enable (
      let
        inherit (config.lib.stylix.colors.withHashtag) base00;
        ink = {base = lib.mkForce base00;};
      in {
        stylix.themes.default = {
          text_selected = ink;
          list_selected = ink;
          table_cell_selected = ink;
        };
      }
    );
  };
}
