{
  pkgs,
  inputs,
  ...
}: {
  environment.systemPackages = [
    pkgs.twemoji-color-font
  ];

  fonts = {
    # Every entry here is reachable from something. The list used to carry ten
    # families that nothing in the tree named — fira-code(-symbols),
    # nerd-fonts.{jetbrains-mono,iosevka-term}, recursive, comic-mono, inter,
    # ibm-plex, stix-two, lmodern — plus maple-mono, which stopped being the
    # body face when ./stylix.nix moved to Ioskeley. An unreferenced font is not
    # inert: it is a candidate every fontconfig fallback has to consider, and
    # the reason a missing glyph lands on something surprising.
    packages = with pkgs; [
      # Body face — all three stylix text slots. See ./stylix.nix.
      (callPackage ../../packages/ioskeley-mono.nix {})

      # Display face — the bar and its clock only, pointed at by name in
      # ./noctalia.nix rather than occupying a stylix slot. A 5x6-ish pixel
      # font: crisp at its design size and integer multiples, soft anywhere
      # else, which is why nothing that scales freely gets to use it.
      departure-mono

      # Nerd Font glyph coverage, no letterforms: symbols-only is fallback #2
      # in wezterm's font_with_fallback (./wezterm.nix) and the family
      # desktop/emacs names for nerd-icons. A full patched family would put a
      # second set of letterforms ahead of Ioskeley in the fallback chain.
      nerd-fonts.symbols-only

      # Script coverage and emoji. twemoji is also in systemPackages above so
      # apps that scan a package tree rather than fontconfig can find it.
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      twemoji-color-font

      # Operator Mono is paid and its flake input is commented out in
      # flake.nix; kept here as the note of what it would be called.
      # inputs.operator-mono.packages.x86_64-linux.default
    ];

    fontconfig = {
      enable = true;
      hinting.style = "slight";
      # Grayscale antialiasing, not RGB subpixel. tempest's external is a QD-OLED
      # (MSI MAG 272UP E16) whose triangular subpixel layout fringes text under
      # "rgb" subpixel AA; grayscale is the safe OLED/HiDPI choice. fontconfig
      # can't do this per-monitor, so it also very slightly softens the low-DPI
      # LCD externals — an accepted trade at their densities. See docs/adr/0009.
      subpixel.rgba = "none";
      antialias = true;
    };
  };
}
