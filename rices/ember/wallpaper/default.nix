{
  config,
  lib,
  pkgs,
  ...
}: let
  c = config.lib.stylix.colors.withHashtag;

  # The ground: a HUD bezel generated from the base16 scheme at build time,
  # because a downloaded image can't track the palette and a photograph is the
  # worst thing to leave on an OLED all day. Corner brackets, graduated edge
  # ticks and a centre reticle — mostly void, on purpose: instrument bezel, not
  # a picture. Measured, 0.14% of pixels sit above the ground colour.
  #
  # 3840x2160 is the largest panel this config drives; noctalia fits it down for
  # the others, and that 0.5x downscale is why no line is thinner than 3px.
  #
  # HIERARCHY BY SIZE, NOT VALUE. Ticks and brackets are both base03. Drawing
  # ticks a step down at base02 made them invisible — base02 is 16/255 above
  # base00, under the discrimination floor on a panel this dark, and there is no
  # usable value between the two. So ticks are subordinated by being short and
  # thin instead, which is the axis that survives both the downscale and the
  # wlsunset warm filter. PNG, not JPEG: thin light lines on near-black are what
  # chroma subsampling rings around.
  hudGround = let
    w = 3840;
    h = 2160;
    inset = 64; # distance from the panel edge to the bracket
    arm = 200; # bracket arm length
    tick = 10; # edge tick length, minor graduation
    majorTick = 24; # every fifth tick, counted out from the centre one
    majorEvery = 5;
    step = 160; # edge tick spacing
    reticle = 28; # centre crosshair arm

    # Ticks along one edge, laid out from the centre outwards so the run stays
    # symmetric on any width and no half-tick lands at the corner. Every fifth
    # is drawn long, so each edge reads as a marked scale rather than a row of
    # identical dashes.
    ticksAlong = {
      count,
      lineAt,
    }:
      lib.concatStringsSep " "
      (lib.genList (
          i: let
            fromCentre = i - (count - 1) / 2;
          in
            lineAt {
              offset =
                fromCentre
                * step
                + (
                  if lib.mod count 2 == 0
                  then step / 2
                  else 0
                );
              len =
                if lib.mod fromCentre majorEvery == 0
                then majorTick
                else tick;
            }
        )
        count);

    hTicks = count: y: dir:
      ticksAlong {
        inherit count;
        lineAt = {
          offset,
          len,
        }: let
          x = w / 2 + offset;
        in "line ${toString x},${toString y} ${toString x},${toString (y + dir * len)}";
      };

    vTicks = count: x: dir:
      ticksAlong {
        inherit count;
        lineAt = {
          offset,
          len,
        }: let
          y = h / 2 + offset;
        in "line ${toString x},${toString y} ${toString (x + dir * len)},${toString y}";
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
  # Wallpaper is drawn by Noctalia (../noctalia.nix), not awww. This module only
  # seeds images into its picker directory so a fresh machine comes up with one.
  # The directory stays writable: `recursive = true` links the files, not the
  # directory, so oled/ accepts hand-dropped images too.
  #
  # oled/ is the rotation pool, so nothing lands there that would sit at high
  # average picture level. Everything in it measured under 0.08 mean gray (via
  # `magick <f> -colorspace Gray -resize 400x400 -format "%[fx:mean]"`) except
  # kawaii-cat-girl at 0.24 — they came off wallhaven filtered
  # `colors=000000 atleast=3840x2160` and then measured, since the colour filter
  # alone only means "black is in the palette" (~1 in 10 hits cleared the bar).
  # Each filename's id suffix is the wallhaven id, so a file traces back to
  # https://wallhaven.cc/w/<id>. The generated ground is what noctalia boots
  # into; the flat directory keeps the bright ones (mean 0.47–0.66) for manual
  # picking, which is fine for an hour and not for an all-day rotation.
  lib.mkIf config.rices.ember.enable {
    home.file."Pictures/Wallpapers/oled" = {
      source = ./oled;
      recursive = true;
    };

    # Inside the pool rather than beside it so noctalia's picker can select it
    # again after you switch away. Not a conflict with the recursive link above:
    # that links each file in ./oled individually, and this name is not one.
    home.file."Pictures/Wallpapers/oled/hud-ground.png".source = hudGround;

    home.file."Pictures/Wallpapers/boeing-747.jpg".source = ./boeing-747.jpg;
    home.file."Pictures/Wallpapers/wallhaven_yqmelx.jpg".source = ./wallhaven_yqmelx.jpg;
    home.file."Pictures/Wallpapers/vintage-car-gta-6-3840x2160-26771.jpg".source = ./vintage-car-gta-6-3840x2160-26771.jpg;
  }
