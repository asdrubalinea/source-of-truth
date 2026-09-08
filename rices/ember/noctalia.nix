{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [inputs.noctalia.homeModules.default];

  config = lib.mkIf config.rices.ember.enable {
    # Noctalia is the shell leg of the NNN stack: bar, launcher, notifications,
    # wallpaper. It replaced waybar and took the launcher role off tofi (which
    # stays as the rice's *menu* widget). It supersedes mako too, so force mako
    # off rather than have two daemons fight over the dbus name.
    services.mako.enable = lib.mkForce false;

    programs.noctalia = {
      enable = true;

      # Supervised, not a bare compositor spawn: v5.0.0 is an unreleased dev
      # build that segfaults deterministically around output hotplug, which a
      # docked+suspend setup hits constantly. As a service it self-heals in ~1s.
      # The spawn-at-startup entry in compositors/niri/niri.nix is removed so it
      # isn't double-launched.
      systemd.enable = true;

      # Colors come from stylix, which since danth/stylix#2364 maps the base16
      # scheme into noctalia's Material-3 tokens and owns every theme.* key
      # (source/mode/custom_palette/font_family/wallpaper.default.path). Nothing
      # to override here — this is why the rice no longer hand-drives colors.
      # stylix also themes the apps directly, so there is no theme.templates
      # relay any more, and the per-app `force = true` workarounds it needed are
      # gone.

      # Declarative config.toml, validated at build time (a bad value fails the
      # build, an unknown key only warns). Bar layout lives in
      # ./noctalia-widgets.nix and merges into this same file. Pinning it makes
      # the in-app settings GUI non-persistent — it's a read-only store symlink.
      settings = {
        # MUST stay off, or the IP-geolocation timer overwrites the address.
        # The address itself is machine policy and lives beside the wlsunset
        # coordinates in homes/tempest/default.nix so the two can't drift.
        location.auto_locate = false;

        # Noctalia owns the wallpaper (replacing awww), drawing a
        # background-layer surface that niri's layer-rule reparents into its
        # backdrop.
        wallpaper = {
          enabled = true;
          # The curated OLED pool, not the whole library — ~/Pictures/Wallpapers
          # also holds unmeasured hand-dropped images (some at 54–93% mean
          # luminance) that automation would happily park on the panel all day.
          directory = "~/Pictures/Wallpapers/oled";

          # Off by request — the ground stays put. Cycling would raise the
          # burn-in risk it exists to lower: the generated ground has less
          # static content than any photograph in the pool.
          automation.enabled = false;

          # v5 renders NOTHING without a persisted image path — there is no
          # "pick one from `directory`" startup fallback, which is why the
          # desktop came up blank when the v5 update relocated the state store.
          # So pin a deterministic fallback. mkForce because the stylix target
          # also pins this at normal priority. The picker still overrides it
          # live via ~/.local/state/noctalia/settings.toml, which deep-merges
          # over this file.
          default.path = lib.mkForce "~/Pictures/Wallpapers/oled/hud-ground.png";

          # `fit`, not the default `crop`: the ground carries marks at its edges
          # and crop scales-to-cover and discards the overflow, throwing them
          # away on any non-16:9 panel. The letterbox is invisible because
          # fill_color is the image's own ground. Cost is an inset frame on
          # non-16:9 panels (~150px on eDP-1, ~440px on the ultrawide);
          # `stretch` hugs the edge instead, at up to 1.34:1 line weight.
          fill_mode = "fit";
          fill_color = config.lib.stylix.colors.withHashtag.base00;
        };

        brightness.enable_ddcutil = true;

        # (`backdrop.blur_intensity` was here and did nothing — backdrop.enabled
        # is false, so there is no surface to blur.)

        # wezterm sends urgency=critical with expire_timeout=0, which the spec
        # defines as "never expire", so noctalia was right to keep the toasts
        # up; wezterm has no knob for it. allow_permanent = false rewrites the 0
        # to noctalia's 6s default (add override_duration in ms for another).
        # `match` is a case-insensitive token against app name / desktop entry /
        # category, and every other filter field defaults true.
        notification.filter.wezterm = {
          match = "wezterm";
          allow_permanent = false;
        };

        shell = {
          # THE DISPLAY FACE, and the only surface that gets it (see CONTEXT.md).
          # A pixel font suits a readout you glance at, not a buffer you read
          # for an hour — hence pointed here rather than put in a stylix slot,
          # which would drag GTK and every editor's chrome along. mkForce
          # because the stylix target sets this from fonts.sansSerif, now the
          # body face. Installed in ./fonts.nix; named by string as it occupies
          # no stylix slot. If it looks fuzzy the knob is
          # `bar.default.font_scale` in ./noctalia-widgets.nix, not this.
          font_family = lib.mkForce "Departure Mono";

          # Off since the negative struts: windows now reach the display edges
          # and already round at radius 12, and this overlay masks a second,
          # differently-sized curve on top. One rounding wins.
          screen_corners.enabled = false;

          # Noctalia "adopts orphaned selections", which raced every copy:
          # Gecko/Chromium serve empty data for ~6ms after announcing a
          # selection, noctalia re-offered that stale value as its own, and the
          # two ping-ponged ~6x per Ctrl+C — so the first copy often pasted the
          # PREVIOUS selection. With this false, 49 adoptions/hour went to 0 and
          # history still records. Deliberate trade: clipboard content now dies
          # with the source app, which is plain Wayland behaviour.
          clipboard_keep_from_closed_apps = false;
        };
      };
    };

    # A user service inherits only what the compositor pushes via
    # `import-environment`, NOT the compositor's per-session `env` block. So
    # re-export the two vars noctalia needs from there. Without
    # NOCTALIA_PAM_SERVICE the lockscreen falls back to PAM "login" → "setuid
    # failed" → can never unlock.
    systemd.user.services.noctalia.Service.Environment = [
      "NOCTALIA_PAM_SERVICE=noctalia"
      "QT_QPA_PLATFORM=wayland"
    ];

    # The module's Restart=on-failure covers the segfault but NOT losing the
    # compositor, which noctalia handles gracefully and exits 0 for — systemd
    # declines to act and the bar is simply gone until started by hand (93s of
    # that on 2026-08-19). `always` covers both exits and still won't fight an
    # explicit `systemctl --user stop`. Paired with StartLimitIntervalSec=0 in
    # homes/tempest/default.nix so a relaunch storm can't make it permanent.
    systemd.user.services.noctalia.Service.Restart = lib.mkForce "always";

    # Runtime deps of the v4 "Screen Toolkit" plugin. v5 manages plugins through
    # config.toml + `noctalia msg plugins`, so it's no longer an HM option and
    # the plugin isn't re-declared yet; these stay as generally useful tools.
    home.packages = with pkgs; [
      grim # screenshot grabber (wlroots)
      slurp # region/window selection
      hyprpicker # wlroots color picker
      tesseract # OCR engine
      zbar # QR / barcode decode (zbarimg)
      translate-shell # Google Lens / translation backend
      wl-screenrec # hardware-encoded screen recording (wlroots)
      gifski # high-quality GIF encoding
    ];
  };
}
