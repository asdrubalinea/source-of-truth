{ pkgs, inputs, ... }: {
  environment.systemPackages = [
    pkgs.twemoji-color-font
  ];

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      twemoji-color-font
      fira-code
      fira-code-symbols
      nerd-fonts.jetbrains-mono
      nerd-fonts.iosevka-term
      nerd-fonts.symbols-only
      recursive
      comic-mono
      maple-mono.opentype
      inter
      ibm-plex
      stix-two
      lmodern
      (callPackage ../../packages/ioskeley-mono.nix { })
    ] ++ [
      # pkgs.maple-mono
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
