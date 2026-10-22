{
  lib,
  config,
  ...
}:
lib.mkIf config.rices.ember.enable (
  let
    colors = config.lib.stylix.colors;

    # KConfig stores colours as decimal "r,g,b" triples.
    rgb = c: "${colors."${c}-rgb-r"},${colors."${c}-rgb-g"},${colors."${c}-rgb-b"}";

    # One KColorScheme "set" — the twelve roles KDE asks for per surface. Only
    # the two backgrounds vary between sets, so they are the arguments.
    set = bg: alt: ''
      BackgroundNormal=${rgb bg}
      BackgroundAlternate=${rgb alt}
      DecorationFocus=${rgb "base0D"}
      DecorationHover=${rgb "base0D"}
      ForegroundNormal=${rgb "base05"}
      ForegroundActive=${rgb "base05"}
      ForegroundInactive=${rgb "base04"}
      ForegroundLink=${rgb "base0D"}
      ForegroundVisited=${rgb "base0E"}
      ForegroundNegative=${rgb "base08"}
      ForegroundNeutral=${rgb "base0A"}
      ForegroundPositive=${rgb "base0B"}
    '';

    inherit (config.stylix.fonts) sansSerif monospace;
    inherit (config.stylix.fonts.sizes) applications desktop terminal;
    font = name: size: "${name},${toString size},-1,5,50,0,0,0,0,0";
  in {
    # KDE apps (Dolphin, Gwenview, Okular, Ark) do NOT take their palette from
    # qt6ct — KConfigWidgets replaces qApp's palette at startup from the
    # [Colors:*] groups of kdeglobals. So ../qt.nix themes plain Qt apps and this
    # file themes KDE ones; both derive from the same base16 scheme so they agree.
    #
    # This is not what stylix.targets.kde does. That target writes an
    # EmberKDark.colors file and points UiSettings.ColorScheme at it, then relies
    # on `plasma-apply-lookandfeel` to copy the colours into kdeglobals. Without a
    # Plasma session nothing ever performs that copy, which is why Dolphin sat on
    # KColorScheme's compiled-in Breeze *light* fallback while its text came from
    # qt6ct's cream — two palettes in one window. The target is off in
    # ./stylix.nix; the colours are written here directly instead.
    #
    # Consequence of owning the file: kdeglobals becomes a read-only store
    # symlink, so KDE apps can no longer persist global settings into it (a
    # Dolphin "single click" toggle, say). Anything worth keeping goes below;
    # per-app state is unaffected, that lives in dolphinrc/gwenviewrc.
    xdg.configFile."kdeglobals".text = ''
      [General]
      ColorScheme=Ember
      Name=Ember
      font=${font sansSerif.name applications}
      fixed=${font monospace.name terminal}
      menuFont=${font sansSerif.name desktop}
      toolBarFont=${font sansSerif.name desktop}
      smallestReadableFont=${font sansSerif.name desktop}

      [UiSettings]
      ColorScheme=Ember

      [Icons]
      Theme=breeze-dark

      [KDE]
      widgetStyle=Fusion
      SingleClick=false
      AnimationDurationFactor=0

      [Colors:Window]
      ${set "base00" "base01"}
      [Colors:View]
      ${set "base00" "base01"}
      [Colors:Button]
      ${set "base01" "base02"}
      [Colors:Tooltip]
      ${set "base01" "base02"}
      [Colors:Header]
      ${set "base01" "base02"}
      [Colors:Complementary]
      ${set "base00" "base01"}
      [Colors:Selection]
      BackgroundNormal=${rgb "base0D"}
      BackgroundAlternate=${rgb "base0D"}
      DecorationFocus=${rgb "base0D"}
      DecorationHover=${rgb "base0D"}
      ForegroundNormal=${rgb "base00"}
      ForegroundActive=${rgb "base00"}
      ForegroundInactive=${rgb "base00"}
      ForegroundLink=${rgb "base00"}
      ForegroundVisited=${rgb "base00"}
      ForegroundNegative=${rgb "base08"}
      ForegroundNeutral=${rgb "base0A"}
      ForegroundPositive=${rgb "base0B"}

      [WM]
      activeBackground=${rgb "base00"}
      activeForeground=${rgb "base05"}
      activeBlend=${rgb "base09"}
      inactiveBackground=${rgb "base00"}
      inactiveForeground=${rgb "base04"}
      inactiveBlend=${rgb "base03"}

      # Stated rather than left to cascade: the defaults layer still holds a
      # Plasma-era ~/.config/kdedefaults, and an unset effect there would tint
      # disabled and inactive text out of the palette. These are Breeze's values.
      [ColorEffects:Disabled]
      Color=${rgb "base02"}
      ColorAmount=0
      ColorEffect=0
      ContrastAmount=0.65
      ContrastEffect=1
      IntensityAmount=0.1
      IntensityEffect=2

      [ColorEffects:Inactive]
      ChangeSelectionColor=true
      Color=${rgb "base03"}
      ColorAmount=0.025
      ColorEffect=2
      ContrastAmount=0.1
      ContrastEffect=2
      IntensityAmount=0
      IntensityEffect=0
    '';
  }
)
