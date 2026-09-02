{
  config,
  lib,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;

  # The ground: a HUD bezel generated from the base16 scheme at build time. It
  # exists because a downloaded image can't track the palette and a photograph
  # is the worst thing to leave on an OLED all day — measured, 0.13% of pixels
  # sit above the ground colour (about 10.6k of 8.3M), all of them thin lines,
  # and it re-renders itself whenever ../ember-3400k-dark.yaml changes.
  #
  # Note which number that is. The pool table below measures mean gray against
  # true black, and by that yardstick this image reads 0.032 — the same as a
  # blank base00 canvas, because base00 IS 0.032 and the marks are too sparse to
  # move it. The pool's photographs are on true #000 grounds, so their means
  # describe content; this one's describes the palette. "Lit fraction above the
  # ground" is the only figure that compares the marks to anything.
  #
  # WHAT IT IS: corner brackets, tick marks down the four edges, and a small
  # centre reticle. Mostly void, on purpose — the brief was a workstation
  # backdrop, not a picture, so it should read as instrument bezel and then stop
  # asking for attention.
  #
  # 3840x2160 because that is the largest panel this config drives; noctalia
  # scales it down for the others with fill_mode = "fit" (../noctalia.nix
  # explains the aspect-ratio trade). That downscale is why no line is thinner
  # than 3px: the smallest panel is 1920x1080, i.e. 0.5x, and a 2px line lands
  # there as a 1px line at half opacity, which is a smudge rather than a mark.
  #
  # HIERARCHY BY SIZE, NOT BY VALUE. Brackets and ticks are both base03. The
  # first cut drew the ticks a step down at base02 to subordinate them, and they
  # came out invisible — base02 is 16/255 above base00 in every channel, which is
  # under the discrimination floor on a panel this dark. There is no usable value
  # between the two, so the ticks are subordinated by being short (10px against a
  # 200px arm) and thin (3px against 4px) instead. That is the more robust axis
  # anyway: it survives the 0.5x downscale and the wlsunset warm filter, neither
  # of which preserves a 16-step value difference.
  #
  # PNG, not JPEG: thin light lines on near-black are exactly what JPEG's chroma
  # subsampling rings around, and a flat black field costs almost nothing to
  # store losslessly.
  hudGround = let
    w = 3840;
    h = 2160;
    inset = 64; # distance from the panel edge to the bracket
    arm = 200; # bracket arm length
    tick = 10; # edge tick length
    step = 160; # edge tick spacing
    reticle = 28; # centre crosshair arm

    # Ticks along one edge, laid out from the centre outwards so the run stays
    # symmetric on any width and no half-tick lands at the corner.
    ticksAlong = {
      count,
      lineAt,
    }:
      lib.concatMapStringsSep " " lineAt
      (lib.genList (i:
        (i - (count - 1) / 2)
        * step
        + (
          if lib.mod count 2 == 0
          then step / 2
          else 0
        ))
      count);

    hTicks = count: y: dir:
      ticksAlong {
        inherit count;
        lineAt = dx: let
          x = w / 2 + dx;
        in "line ${toString x},${toString y} ${toString x},${toString (y + dir * tick)}";
      };

    vTicks = count: x: dir:
      ticksAlong {
        inherit count;
        lineAt = dy: let
          y = h / 2 + dy;
        in "line ${toString x},${toString y} ${toString (x + dir * tick)},${toString y}";
      };

    # One bracket: two arms meeting at (x,y), running `sx`/`sy` pixels inward.
    bracket = x: y: sx: sy:
      "line ${toString x},${toString y} ${toString (x + sx * arm)},${toString y} "
      + "line ${toString x},${toString y} ${toString x},${toString (y + sy * arm)}";
  in
    pkgs.runCommand "ember-hud-ground.png" {
      nativeBuildInputs = [pkgs.imagemagick];
    } ''
      magick -size ${toString w}x${toString h} canvas:'${c.base00}' \
        -fill none \
        \
        -stroke '${c.base03}' -strokewidth 4 -draw "${
        bracket inset inset 1 1
      } ${
        bracket (w - inset) inset (-1) 1
      } ${
        bracket inset (h - inset) 1 (-1)
      } ${
        bracket (w - inset) (h - inset) (-1) (-1)
      }" \
        \
        -stroke '${c.base03}' -strokewidth 3 -draw "${
        hTicks 19 0 1
      } ${
        hTicks 19 h (-1)
      } ${
        vTicks 11 0 1
      } ${
        vTicks 11 w (-1)
      }" \
        \
        -stroke '${c.base09}' -strokewidth 3 -draw "\
          line ${toString (w / 2 - reticle)},${toString (h / 2)} ${toString (w / 2 - 6)},${toString (h / 2)} \
          line ${toString (w / 2 + 6)},${toString (h / 2)} ${toString (w / 2 + reticle)},${toString (h / 2)} \
          line ${toString (w / 2)},${toString (h / 2 - reticle)} ${toString (w / 2)},${toString (h / 2 - 6)} \
          line ${toString (w / 2)},${toString (h / 2 + 6)} ${toString (w / 2)},${toString (h / 2 + reticle)}" \
        \
        -define png:color-type=2 "$out"
    '';
in
  # Wallpaper is drawn by Noctalia (see ../noctalia.nix), not awww. This module
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
  #   hud-ground (generated)  mean 0.03  — see the note above: that is base00,
  #                                        not content. 0.13% lit above ground.
  #   red-eyes-void           mean 0.01  near-black 97%
  #   ghost-girl-smoke        mean 0.01  near-black 90%
  #   spiderverse-glitch      mean 0.02  near-black 91%
  #   defender-in-the-dark    mean 0.02  near-black 94%
  #   liquid-metal            mean 0.02  near-black 78%
  #   samurai-red-sun         mean 0.03  near-black 91%
  #   hooded-monochrome       mean 0.03  near-black 88%
  #   violet-choker           mean 0.04  near-black 84%
  #   powder-burst            mean 0.04  near-black 82%
  #   synthwave-grid          mean 0.05  near-black 68%
  #   shinobu-kocho-dark      mean 0.05  near-black 78%
  #   batman-monochrome       mean 0.06  near-black 83%
  #   mitsuri-kanroji         mean 0.06  near-black 83%
  #   black-hole              mean 0.08  near-black 80%
  #   kawaii-cat-girl         mean 0.24  near-black 59%
  #
  # The photographs came off wallhaven filtered `colors=000000 atleast=3840x2160`
  # and then measured — the colour filter alone only means "black is in the
  # palette", so roughly 1 in 10 hits actually cleared the bar above. The id
  # suffix in each filename is the wallhaven id, so a file traces back to
  # https://wallhaven.cc/w/<id>. The pool is kept for manual picking; the
  # generated ground is what ../noctalia.nix boots into.
  #
  # The flat directory keeps the bright ones (mean 0.47–0.66) for manual picking —
  # they are fine for an hour, not for an unattended all-day rotation.
  lib.mkIf config.rices.ember.enable {
    home.file."Pictures/Wallpapers/oled" = {
      source = ./oled;
      recursive = true;
    };

    # Sits inside the pool rather than beside it so Noctalia's picker (whose
    # directory is oled/) can select it again after you switch away. Not a
    # conflict with the recursive link above: that links each file in ./oled
    # individually, and this name is not one of them.
    home.file."Pictures/Wallpapers/oled/hud-ground.png".source = hudGround;

    home.file."Pictures/Wallpapers/boeing-747.jpg".source = ./boeing-747.jpg;
    home.file."Pictures/Wallpapers/wallhaven_yqmelx.jpg".source = ./wallhaven_yqmelx.jpg;
    home.file."Pictures/Wallpapers/vintage-car-gta-6-3840x2160-26771.jpg".source = ./vintage-car-gta-6-3840x2160-26771.jpg;
  }
