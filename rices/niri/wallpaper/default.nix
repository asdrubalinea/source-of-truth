{ config, lib, ... }:
# Wallpaper is now drawn by Noctalia (see ../noctalia.nix), not awww. This module
# just seeds a starter image into Noctalia's picker directory so a fresh machine
# comes up with a wallpaper instead of Noctalia's bundled default. The directory
# itself stays writable — drop more images in or switch via Noctalia's picker;
# only this one file is an HM-managed symlink.
lib.mkIf config.rices.niri.enable {
  home.file."Pictures/Wallpapers/boeing-747.jpg".source = ./boeing-747.jpg;
  home.file."Pictures/Wallpapers/wallhaven_yqmelx.jpg".source = ./wallhaven_yqmelx.jpg;
  home.file."Pictures/Wallpapers/shinobu-kocho-dark.png".source = ./shinobu-kocho-dark.png;
}
