{
  config,
  lib,
  ...
}:
# Wallpaper is now drawn by Noctalia (see ../noctalia.nix), not awww. This module
# seeds images into Noctalia's picker directory so a fresh machine comes up with
# a wallpaper instead of Noctalia's bundled default. The directory itself stays
# writable — drop more images in or switch via Noctalia's picker; only these
# files are HM-managed symlinks (`recursive = true` links the files, not the
# directory, so `oled/` accepts hand-dropped images too).
#
# The `oled/` subdirectory is the rotation pool: Noctalia's automation timer
# points at it (../noctalia.nix) and cycles everything inside, so nothing lands
# there that would sit at high average picture level on an OLED panel. Measured
# with `magick <f> -colorspace Gray -resize 400x400 -format "%[fx:mean]"` and a
# 2%-threshold near-black share:
#
#   red-eyes-void          mean 0.01  near-black 97%
#   ghost-girl-smoke       mean 0.01  near-black 90%
#   spiderverse-glitch     mean 0.02  near-black 91%
#   defender-in-the-dark   mean 0.02  near-black 94%
#   liquid-metal           mean 0.02  near-black 78%
#   samurai-red-sun        mean 0.03  near-black 91%
#   hooded-monochrome      mean 0.03  near-black 88%
#   violet-choker          mean 0.04  near-black 84%
#   powder-burst           mean 0.04  near-black 82%
#   synthwave-grid         mean 0.05  near-black 68%
#   shinobu-kocho-dark     mean 0.05  near-black 78%
#   batman-monochrome      mean 0.06  near-black 83%
#   mitsuri-kanroji        mean 0.06  near-black 83%
#   black-hole             mean 0.08  near-black 80%
#   kawaii-cat-girl        mean 0.24  near-black 59%
#
# The new arrivals came off wallhaven filtered `colors=000000 atleast=3840x2160`
# and then measured — the colour filter alone only means "black is in the
# palette", so roughly 1 in 10 hits actually cleared the bar above. The id
# suffix in each filename is the wallhaven id, so a file traces back to
# https://wallhaven.cc/w/<id>.
#
# The flat directory keeps the bright ones (mean 0.47–0.66) for manual picking —
# they are fine for an hour, not for an unattended all-day rotation.
lib.mkIf config.rices.ember.enable {
  home.file."Pictures/Wallpapers/oled" = {
    source = ./oled;
    recursive = true;
  };

  home.file."Pictures/Wallpapers/boeing-747.jpg".source = ./boeing-747.jpg;
  home.file."Pictures/Wallpapers/wallhaven_yqmelx.jpg".source = ./wallhaven_yqmelx.jpg;
  home.file."Pictures/Wallpapers/vintage-car-gta-6-3840x2160-26771.jpg".source = ./vintage-car-gta-6-3840x2160-26771.jpg;
}
