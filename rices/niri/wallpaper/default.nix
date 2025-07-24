{ pkgs, ... }: {
  home.file.".wallpaper".source = ./camo.jpeg;
  home.packages = [ pkgs.swww ];
}
