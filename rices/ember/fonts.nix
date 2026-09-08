{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    pkgs.twemoji-color-font
  ];

  fonts = {
    # Every entry here is reachable from something, and the list is kept that
    # way on purpose: an unreferenced font is not inert, it's a candidate every
    # fontconfig fallback has to consider, and the reason a missing glyph lands
    # on something surprising. (Ten unreferenced families were removed.)
    packages = with pkgs; [
      # Body face — all three stylix text slots. See ./stylix.nix.
      (callPackage ../../packages/ioskeley-mono.nix {})

      # Display face — the bar only, pointed at by name in ./noctalia.nix rather
      # than occupying a stylix slot. A pixel font: crisp at its design size and
      # integer multiples, soft anywhere else, which is why nothing that scales
      # freely gets to use it.
      departure-mono

      # Glyph coverage, no letterforms: fallback #2 in wezterm's
      # font_with_fallback, and the family emacs names for nerd-icons. A full
      # patched family would put a second set of letterforms ahead of Ioskeley.
      nerd-fonts.symbols-only

      # Script coverage and emoji. twemoji is also in systemPackages above so
      # apps that scan a package tree rather than fontconfig can find it.
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      twemoji-color-font
    ];

    fontconfig = {
      enable = true;

      # Required, not cosmetic. NixOS' default `defaultFonts` names DejaVu,
      # which this host does not install — the only copy fontconfig can see is
      # the single-file dejavu-fonts-minimal pulled in by fontconfig itself. So
      # anything asking for a generic got a family whose file doesn't exist, and
      # how that failed depended on the toolkit: Qt/Pango fell back silently,
      # cairo didn't (Noctalia logged "font_face status is: file not found" and
      # rendered tofu in the sysmon tooltip values, whose family it hardcodes to
      # "monospace").
      #
      # ./stylix.nix declares these same roles, but stylix writes no fontconfig
      # aliases — only per-app font settings. This is the same decision restated
      # where fontconfig can act on it.
      defaultFonts = {
        monospace = ["Ioskeley Mono"];
        sansSerif = ["Ioskeley Mono"];
        serif = ["Ioskeley Mono"];
        emoji = ["Noto Color Emoji"];
      };

      hinting.style = "slight";
      # Grayscale, not RGB subpixel: the external QD-OLED's triangular subpixel
      # layout fringes text under "rgb". fontconfig can't do this per-monitor,
      # so it also very slightly softens the low-DPI externals — accepted trade
      # at their densities. See ADR 0009.
      subpixel.rgba = "none";
      antialias = true;
    };
  };
}
