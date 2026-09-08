{
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable {
  # tofi is this rice's *menu* widget, not its launcher — that's Noctalia. Its
  # only users are hand-rolled pickers that pipe rows in and read a line out
  # (the marquee's cast menu, the audio output switcher). They pass rows and a
  # prompt; every decision about how a picker LOOKS lives here.
  #
  # GEOMETRY: always the whole output, never a sized card. Not taste — a sized
  # tofi window is broken under niri on the portrait panel, twice over:
  #
  #   - `anchor = center` isn't one. tofi implements it as "anchor all four
  #     edges" plus an explicit size; sway centres such a surface, niri/smithay
  #     pins it to the anchor rect's top-left, so it lands in the corner.
  #   - a sized window takes tofi's wp_viewporter path and comes out vertically
  #     compressed by ~9x on that output. The text is all there; none of it is
  #     legible.
  #
  # width/height = 0 is tofi's own escape hatch: it disables fractional scaling,
  # sets an integer buffer scale, and lets the compositor scale uniformly — at
  # the cost of a slightly soft 1.5x upscale. Percentages are NOT a substitute;
  # `100%` is still an explicit size and takes the broken path.
  programs.tofi = {
    enable = true;

    settings = {
      width = 0;
      height = 0;

      # With the window the size of the output, padding IS the placement. As
      # fractions, so one number works in both orientations: 35% down clears the
      # marquee band on the portrait panel, 15% in keeps rows off the bezel.
      padding-top = "35%";
      padding-left = "15%";
      result-spacing = 20;
      num-results = 0; # show every row the caller gave us

      # A border on a full-output window is a frame around the whole screen.
      # (stylix uses mkDefault for both, so plain values win.)
      border-width = 0;
      outline-width = 0;

      # stylix sizes tofi from `fonts.sizes.popups` — a notification size (10),
      # unreadable across the room on a 4K panel. mkForce because that
      # definition is not a default. Family and colours still come from stylix.
      font-size = lib.mkForce 26;

      # …except this: stylix paints the selected row base03 over base00 while
      # unselected rows stay base05, so on a dark scheme the highlight is
      # *dimmer* than its surroundings and reads as "disabled". Use the accent,
      # as tofi's own default does.
      selection-color = lib.mkForce config.lib.stylix.colors.withHashtag.base0A;
    };
  };
}
