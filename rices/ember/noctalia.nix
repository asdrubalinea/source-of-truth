{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: {
  imports = [inputs.noctalia.homeModules.default];

  config = lib.mkIf config.rices.ember.enable {
    # Noctalia is the "shell" leg of the NNN stack — an all-in-one desktop shell
    # (bar + launcher + notifications + lockscreen). It replaces waybar, dropped
    # from the rice's default.nix, and takes the launcher role off tofi — which
    # stays imported (./tofi.nix) as the rice's *menu* widget, for the marquee's
    # cast picker and the audio-output switcher. It also supersedes mako
    # (notifications) — force mako off so two notification daemons don't fight
    # over the same dbus name.
    services.mako.enable = lib.mkForce false;

    programs.noctalia = {
      enable = true;

      # Run noctalia as a supervised systemd user service (the module wires up
      # Restart=on-failure, PartOf/After/WantedBy graphical-session.target) rather
      # than a bare, unsupervised niri spawn-at-startup. v5.0.0 is an unreleased
      # dev build of the C++ rewrite (the stable release line is still v4.x) and
      # segfaults deterministically — same fault offset every time, typically
      # around output hotplug / session teardown, which this docked+suspend setup
      # hits constantly. As a service a crash self-heals in ~1s; as a niri child it
      # just left a dead bar until a manual relaunch (which re-crashed). The
      # spawn-at-startup entry in compositors/niri/niri.nix is removed so it isn't double-launched.
      systemd.enable = true;

      # ── Theming ────────────────────────────────────────────────────────────
      # Colors come from stylix. The stylix bump landed the noctalia v5 target
      # (danth/stylix#2364 — see modules/noctalia/hm.nix in the stylix store
      # path): it maps the base16 scheme (ember-3400k-dark, set in stylix.nix)
      # into noctalia's Material-3 tokens as a `custom_palette`, and sets
      # theme.source = "custom" / theme.mode from stylix polarity. We just consume
      # that here — no source/mode override — which is the whole reason this rice
      # used to hand-drive colors (wallpaper-derived) instead.
      #
      # stylix also themes the apps themselves directly (its gtk / kitty /
      # alacritty / wezterm / fish targets, plus the qtct ColorScheme generated in
      # qt.nix), so noctalia no longer relays colors to other apps — there is no
      # theme.templates block here anymore, and the per-app `force = true`
      # workarounds that the runtime templates required are gone.

      # ── Declarative settings (pins ~/.config/noctalia/config.toml) ───────────
      # v5 config is TOML, validated at build time by `noctalia config validate`
      # (programs.noctalia.validateConfig, on by default): a bad VALUE fails the
      # build, an unknown key is a silent warning. The bar layout (position +
      # widgets) lives in ./noctalia-widgets.nix and merges into this same
      # config.toml; this module keeps shell enable, theming, and global shell
      # settings. Pinning config.toml makes the in-app settings GUI
      # non-persistent (read-only store symlink).
      settings = {
        # theme.* (source / mode / custom_palette / customPalettes / shell
        # .font_family / wallpaper.default.path) is entirely owned by the stylix
        # noctalia target — see the Theming note above.

        # Weather / Night-Light / auto-theme location. `auto_locate` MUST stay off
        # or its IP-geolocation timer overwrites whatever address is set — that is
        # the rice's half of this, and the only half that is about the desktop.
        #
        # The address itself is machine policy: where the machine lives is not a
        # property of the rice, and this host already states it once, as the
        # wlsunset coordinates in homes/tempest/default.nix. `location.address` is
        # set right beside them so the two can't drift apart. It is geocoded via
        # api.noctalia.dev, so it is a place name rather than a lat/long pair.
        location.auto_locate = false;

        # Noctalia owns the wallpaper (replacing the old awww service). It draws a
        # background-layer surface (namespace "noctalia-wallpaper") that ignores
        # exclusive zones — niri's layer-rule in compositors/niri/niri.nix reparents it into niri's
        # backdrop.
        #
        # v5 only renders a surface when it has a PERSISTED image path:
        # createInstance → getWallpaperPath(connector) returns the per-monitor
        # override else `default.path`, and if that's empty it never loads an
        # image — there is NO "pick the first/random file from `directory`"
        # fallback at startup (the directory only feeds the random/automation
        # feature). The picker writes the live choice into the writable
        # ~/.local/state/noctalia/settings.toml (as wallpaper.default/monitors/
        # last .path), which deep-merges OVER this read-only config.toml. So when
        # that runtime state is reset — which is exactly what the v5 update did,
        # by relocating the state store — nothing is left to show and the desktop
        # comes up blank.
        #
        # Pin `default.path` to the seeded starter image (./wallpaper) so there's
        # always a deterministic fallback; the picker still overrides it at
        # runtime via settings.toml.
        wallpaper = {
          enabled = true;
          # Point the picker/rotation at the curated OLED pool, not the whole
          # library — ~/Pictures/Wallpapers also holds hand-dropped images that
          # were never measured (several sit at 54–93% mean luminance), and
          # automation would happily park one of those on the panel all day.
          # ../wallpaper/default.nix seeds oled/ and records the measurements.
          directory = "~/Pictures/Wallpapers/oled";

          # Rotation off by request — synthwave-grid stays put. The OLED
          # argument for cycling still holds in principle (same subpixels, same
          # level, all day), but this image is 3% mean on a true-#000 field, so
          # the lit fraction is small and mostly thin lines; burn-in risk is
          # about as low as a static image gets in this pool.
          automation.enabled = false;

          # The stylix target also pins wallpaper.default.path (to its own
          # `image`) at normal priority, so mkForce the rice's chosen image to
          # win. With automation off nothing rewrites this at runtime any more,
          # but the state settings.toml still deep-merges over it, so the
          # picker remains the way to change wallpaper live — this is what a
          # fresh state store comes up with.
          default.path = lib.mkForce "~/Pictures/Wallpapers/oled/synthwave-grid-ml3jm8.jpg";
        };

        brightness.enable_ddcutil = true;

        backdrop.blur_intensity = 0.1;

        # wezterm asks for toasts that never go away. Captured from its live
        # Notify call: app_name="wezterm", urgency=critical, expire_timeout=0 —
        # and 0 is the spec's "never expire" (-1 is "daemon default"), so
        # noctalia was right to keep them up. wezterm has no knob for this; the
        # only notification-related field in its config schema is
        # notification_handling.
        #
        # A matched filter with allow_permanent = false rewrites timeout 0 to
        # noctalia's kDefaultNotificationTimeout (6s); add override_duration
        # (milliseconds) here to choose a different one. `match` is a
        # case-insensitive token compared against app name, desktop entry or
        # category, so "wezterm" hits the app name. Every other filter field
        # (show_toast / save_history / play_sound) defaults true, so this only
        # changes the expiry.
        notification.filter.wezterm = {
          match = "wezterm";
          allow_permanent = false;
        };

        shell = {
          # font_family is set by the stylix noctalia target (fonts.sansSerif.name).
          # Off since the negative struts in compositors/niri/niri.nix: windows now reach the
          # display edges and already round themselves at radius 12
          # (window-rules.nix geometry-corner-radius). Noctalia's screen-corner
          # overlay masks a second, differently-sized curve on top of that, so
          # the two radii visibly disagree at every corner. One rounding wins.
          screen_corners.enabled = false;

          # Noctalia's clipboard history is on by default and "adopts orphaned
          # selections" — it takes Wayland selection ownership so content
          # survives the source app exiting. That adoption raced every copy:
          # Gecko/Chromium announce a selection and serve empty data for ~6ms
          # before filling it in, noctalia read that empty/previous value and
          # re-offered it as its own, the app re-asserted, and the two ping-ponged
          # ~6 times per Ctrl+C. Whichever won the last round decided what you
          # pasted, so the first copy often yielded the PREVIOUS selection.
          # Verified by removal: with noctalia stopped the ping-pong vanished
          # entirely; with this false, 49 adoptions/hour dropped to 0 and history
          # still records. Trade-off kept deliberately: clipboard content now
          # dies with the source app, which is plain Wayland behaviour.
          clipboard_keep_from_closed_apps = false;
        };
      };
    };

    # A systemd user service only inherits the handful of vars the compositor pushes via
    # `systemctl --user import-environment` (WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP,
    # DBUS_SESSION_BUS_ADDRESS, XAUTHORITY) — NOT the compositor’s per-session `env`
    # block. So re-export the two vars noctalia actually needs that live there:
    #   - NOCTALIA_PAM_SERVICE: without it the lockscreen falls back to PAM "login"
    #     → "setuid failed" → can never unlock (see the comment in compositors/niri/niri.nix).
    #   - QT_QPA_PLATFORM=wayland: keep the Qt platform explicit, as in both layers.
    systemd.user.services.noctalia.Service.Environment = [
      "NOCTALIA_PAM_SERVICE=noctalia"
      "QT_QPA_PLATFORM=wayland"
    ];

    # The module's Restart=on-failure (see the comment above) only covers the
    # segfault case. It does NOT cover losing the compositor, because noctalia
    # handles that *gracefully* and exits 0:
    #
    #   10:36:49 noctalia[22246]: [main] Wayland display closed during failed to
    #            read Wayland events; shutting down (display_error=32 (Broken pipe))
    #
    # systemd sees a clean exit, on-failure declines to act, and there is not even
    # a "Scheduled restart job" line in the journal — the bar is simply gone until
    # a manual `systemctl --user start noctalia`. That is what happened when mango
    # was restarted on 2026-08-19: noctalia stayed down for the 93 seconds until it
    # was started by hand.
    #
    # Restart=always covers both exits with one word. It does not fight an explicit
    # `systemctl --user stop` (systemd never restarts after an intentional stop), so
    # the only behaviour this gives up is letting noctalia quit itself on purpose —
    # which for the session's bar/shell is not a thing we want anyway. Paired with
    # StartLimitIntervalSec=0 in homes/tempest/default.nix so a relaunch storm can't
    # trip the start limiter and make it permanent.
    systemd.user.services.noctalia.Service.Restart = lib.mkForce "always";

    # Screenshot / annotate / record / OCR tooling. These were the runtime deps
    # of the v4 "Screen Toolkit" Noctalia plugin. v5 manages plugins differently
    # — a `[plugins]` table in config.toml plus `noctalia msg plugins …` at
    # runtime, cloned from the official/community plugin repos — so it's no longer
    # a home-manager option. The plugin isn't re-declared here yet; the CLI tools
    # stay because they're generally useful for screenshots/recording.
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
