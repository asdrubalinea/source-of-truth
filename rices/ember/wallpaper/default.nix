{ config, lib, ... }:
# Wallpaper is now drawn by Noctalia (see ../noctalia.nix), not awww. This module
# seeds images into Noctalia's picker directory so a fresh machine comes up with
# a wallpaper instead of Noctalia's bundled default. The directory itself stays
# writable — drop more images in or switch via Noctalia's picker; only these
# files are HM-managed symlinks.
#
# The `oled/` subdirectory is the rotation pool: Noctalia's automation timer
# points at it (../noctalia.nix) and cycles everything inside, so nothing lands
# there that would sit at high average picture level on an OLED panel. Measured
# with `magick <f> -colorspace Gray -resize 400x400 -format "%[fx:mean]"` and a
# 2%-threshold near-black share:
#
#   shinobu-kocho-dark   mean 0.05  near-black 78%
#   mitsuri-kanroji      mean 0.06  near-black 83%
#   kawaii-cat-girl      mean 0.24  near-black 59%
#
# The flat directory keeps the bright ones (mean 0.47–0.66) for manual picking —
# they are fine for an hour, not for an unattended all-day rotation.
lib.mkIf config.rices.ember.enable {
  home.file."Pictures/Wallpapers/oled/shinobu-kocho-dark.png".source = ./shinobu-kocho-dark.png;
  home.file."Pictures/Wallpapers/oled/mitsuri-kanroji-3840x2160-22627.png".source = ./mitsuri-kanroji-3840x2160-22627.png;
  home.file."Pictures/Wallpapers/oled/kawaii-cat-girl-5120x2880-26545.png".source = ./kawaii-cat-girl-5120x2880-26545.png;

  home.file."Pictures/Wallpapers/boeing-747.jpg".source = ./boeing-747.jpg;
  home.file."Pictures/Wallpapers/wallhaven_yqmelx.jpg".source = ./wallhaven_yqmelx.jpg;
  home.file."Pictures/Wallpapers/vintage-car-gta-6-3840x2160-26771.jpg".source = ./vintage-car-gta-6-3840x2160-26771.jpg;
}
