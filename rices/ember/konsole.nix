{
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable (
  let
    colors = config.lib.stylix.colors;

    # Konsole reads colours as decimal "r,g,b" triples, one per KConfig section.
    rgb = c: "${colors."${c}-rgb-r"},${colors."${c}-rgb-g"},${colors."${c}-rgb-b"}";

    section = name: base: ''
      [${name}]
      Color=${rgb base}
    '';

    # The ANSI 16 in base16 order (base16 spec §"terminal colours"): the normal
    # eight are base00/08/0B/0A/0D/0E/0C/05, and the intense eight lift black to
    # base03 and white to base07 while leaving the hues alone — base16 has one
    # shade per hue, and inventing a second would put colours in the terminal
    # that exist nowhere else in the rice.
    normal = ["base00" "base08" "base0B" "base0A" "base0D" "base0E" "base0C" "base05"];
    intense = ["base03" "base08" "base0B" "base0A" "base0D" "base0E" "base0C" "base07"];

    colorScheme =
      ''
        # Generated from the stylix base16 scheme (see ./stylix.nix). Konsole is
        # not a stylix target, so unlike kitty/alacritty/wezterm it gets its
        # palette written out here.
      ''
      + section "Background" "base00"
      + section "BackgroundIntense" "base00"
      + section "BackgroundFaint" "base00"
      + section "Foreground" "base05"
      + section "ForegroundIntense" "base07"
      + section "ForegroundFaint" "base04"
      + lib.concatImapStrings (i: c: section "Color${toString (i - 1)}" c) normal
      + lib.concatImapStrings (i: c: section "Color${toString (i - 1)}Intense" c) intense
      + lib.concatImapStrings (i: c: section "Color${toString (i - 1)}Faint" c) normal
      + ''
        [General]
        Description=Ember
        Opacity=1
        Wallpaper=
      '';

    inherit (config.stylix.fonts) monospace;
    inherit (config.stylix.fonts.sizes) terminal;
  in {
    # Konsole exists here for one reason: Dolphin's F4 terminal panel embeds the
    # Konsole KPart and shows "Konsole is not installed" without it. The KPart
    # reads the *default profile*, so the profile below is what themes the panel
    # — it is not just for the standalone app.
    xdg.dataFile = {
      "konsole/Ember.colorscheme".text = colorScheme;
      "konsole/Ember.profile".text = ''
        [Appearance]
        ColorScheme=Ember
        Font=${monospace.name},${toString terminal},-1,5,50,0,0,0,0,0

        [General]
        Name=Ember
        Parent=FALLBACK/
        # 12, matching wezterm/kitty/alacritty — see ./wezterm.nix for why, and
        # why all four move together.
        TerminalMargin=12

        [Cursor Options]
        # Steady block, matching kitty/alacritty/wezterm — see ./kitty.nix for
        # the reasoning. Both keys already hold these values by default in
        # Konsole; they are stated because a cursor change is a rice-wide
        # behavioural change (docs/ember-visual-language.md, "A terminal"), and a
        # default that agrees by accident is not a config that will follow.
        CursorShape=0

        [Terminal Features]
        BlinkingCursorEnabled=false

        [Scrolling]
        HistoryMode=2
      '';
    };

    xdg.configFile."konsolerc".text = ''
      [Desktop Entry]
      DefaultProfile=Ember.profile
    '';
  }
)
