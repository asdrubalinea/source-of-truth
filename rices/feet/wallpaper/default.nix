{ pkgs, ... }: {
  home.file.".wallpaper".source = ./feet.jpg;
  home.packages = [pkgs.swww];
}
