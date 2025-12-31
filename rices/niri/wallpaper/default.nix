{ pkgs, ... }: {
  home.file.".wallpaper".source = ./wallpaper3345.png;
  home.packages = [ pkgs.swww ];
}
