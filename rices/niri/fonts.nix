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
      recursive
      comic-mono
      maple-mono.opentype
    ] ++ [
      # pkgs.maple-mono
      # inputs.operator-mono.packages.x86_64-linux.default
    ];
  };
}
