{ pkgs, hostname, ... }:
{
  stylix = {
    enable = true;
    autoEnable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/rose-pine.yaml";

    targets = {
      neovim.enable = false;
      ghostty.enable = true;
    };

    fonts = {
      sizes = {
        terminal =
          if hostname == "tempest" then
            16
          else if hostname == "orchid" then
            20
          else
            16;
      };

      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };

      monospace = {
        package = pkgs.comic-mono;
        name = "Maple Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
}