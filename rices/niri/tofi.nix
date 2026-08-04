{ lib
, config
, ...
}:
lib.mkIf config.rices.niri.enable {
  # tofi is this rice's *menu* widget, not its launcher — the launcher is
  # Noctalia. Its only two users are hand-rolled pickers that pipe rows in and
  # read a line out: the marquee's cast/dark menu (./marquee.nix) and the audio
  # output switcher (./niri.nix). They pass rows and a prompt; every decision
  # about how a picker LOOKS lives here.
  #
  # GEOMETRY: always the whole output, never an explicitly-sized card. That is
  # not taste. A sized tofi window renders wrong under niri on tempest's
  # portrait panel (DP-2, 3840x2160 at scale 1.5, transform 270), in two
  # independent ways, both measured off screenshots of the real thing:
  #
  #   - `anchor = center` is not a centre. tofi implements it as "anchor all
  #     four edges" *plus* an explicit size (ANCHOR_CENTER in tofi's
  #     config.c). sway centres a surface like that; niri/smithay pins it to
  #     the top-left of the anchor rect. So the window lands in the panel's
  #     corner — for the marquee picker, inside the band, over the video.
  #   - a sized window takes tofi's wp_viewporter path: it renders a buffer at
  #     the fractional scale and hands the compositor a logical destination
  #     size (main.c ~1600). On that output the result comes out vertically
  #     compressed by roughly 9x — 9.5 px of measured line pitch where 79 px
  #     was asked for, glyphs flattened to a few pixels tall. The text is all
  #     there; none of it is legible.
  #
  # width/height = 0 is tofi's own escape hatch from that path: it warns,
  # disables fractional scaling, sets an integer buffer scale, and lets the
  # compositor scale the surface uniformly. Measured on the same panel: correct
  # and proportional, at the cost of a 1.5x upscale (so, slightly soft). Note
  # that percentages are NOT a substitute — `100%` is still an explicit size
  # and takes the broken viewport path.
  programs.tofi = {
    enable = true;

    settings = {
      width = 0;
      height = 0;

      # With the window the size of the output, padding IS the placement. As
      # fractions so one number works in both orientations: 35% down clears the
      # marquee band on the portrait panel (35% of 2560 > its 810), and 15% in
      # keeps the rows off the bezel.
      padding-top = "35%";
      padding-left = "15%";
      result-spacing = 20;
      num-results = 0; # show every row the caller gave us

      # A border on a full-output window is a frame around the whole screen.
      # (stylix defines both of these with mkDefault, so plain values win.)
      border-width = 0;
      outline-width = 0;

      # stylix sizes tofi from `fonts.sizes.popups`, which is a notification
      # size (10) — unreadable across the room on a 4K panel. mkForce because
      # stylix's definition is not a default. Font family and colours still
      # come from stylix.
      font-size = lib.mkForce 26;

      # …with one exception. stylix paints the selected row in base03 over a
      # base00 background and leaves the unselected ones at base05, so on a dark
      # scheme the highlight is *dimmer* than everything around it and reads as
      # "disabled". Use the prompt's accent instead, which is what tofi's own
      # default does.
      selection-color = lib.mkForce config.lib.stylix.colors.withHashtag.base0A;
    };
  };
}
