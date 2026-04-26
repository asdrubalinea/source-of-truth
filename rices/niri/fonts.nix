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
    ] ++ [
      # pkgs.maple-mono
      # inputs.operator-mono.packages.x86_64-linux.default
    ];

    fontconfig = {
      enable = true;
      hinting.style = "slight";
      subpixel.rgba = "rgb";
      antialias = true;
    };
  };
}
