{ pkgs, ... }: {
  home.file.".wallpaper".source = ./girl-cats.jpg;
  home.packages = [pkgs.swww];
}
