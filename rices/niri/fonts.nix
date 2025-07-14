{ pkgs, inputs, ... }: {
  environment.systemPackages = [
    pkgs.twemoji-color-font
  ];

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      twemoji-color-font
      fira-code
      fira-code-symbols
      nerd-fonts.jetbrains-mono
      nerd-fonts.iosevka-term
      recursive
      comic-mono
    ] ++ [
      pkgs.stable.maple-mono
      # inputs.operator-mono.packages.x86_64-linux.default
    ];
  };
}