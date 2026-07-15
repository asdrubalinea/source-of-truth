{ inputs, lib, pkgs, config, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf config.rices.niri.enable {
    # Noctalia is the "shell" leg of the NNN stack — an all-in-one desktop shell
    # (bar + launcher + notifications + lockscreen). It replaces waybar (bar) and
    # tofi (launcher), both dropped from the rice's default.nix, and supersedes
    # mako (notifications) — force mako off so two notification daemons don't
    # fight over the same dbus name.
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
      # spawn-at-startup entry in niri.nix is removed so it isn't double-launched.
      systemd.enable = true;

      # ── Theming ────────────────────────────────────────────────────────────
      # Colors come from stylix. The stylix bump landed the noctalia v5 target
      # (danth/stylix#2364 — see modules/noctalia/hm.nix in the stylix store
      # path): it maps the base16 scheme (catppuccin-mocha, set in stylix.nix)
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

        # Weather / Night-Light / auto-theme location. `address` is geocoded via
        # api.noctalia.dev; auto_locate MUST stay off or its IP-geolocation timer
        # overwrites it.
        location = {
          address = "Las Palmas, Spain";
          auto_locate = false;
        };

        # Noctalia owns the wallpaper (replacing the old awww service). It draws a
        # background-layer surface (namespace "noctalia-wallpaper") that ignores
        # exclusive zones — niri's layer-rule in niri.nix reparents it into niri's
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
          directory = "~/Pictures/Wallpapers";
          # The stylix target also pins wallpaper.default.path (to its own `image`)
          # at normal priority, so mkForce the rice's seeded starter image to win.
          default.path = lib.mkForce "~/Pictures/Wallpapers/wallhaven_yqmelx.jpg";
        };

        brightness.enable_ddcutil = true;

        backdrop.blur_intensity = 0.1;

        shell = {
          # font_family is set by the stylix noctalia target (fonts.sansSerif.name).
          screen_corners.enabled = true;
        };
      };
    };

    # A systemd user service only inherits the handful of vars niri pushes via
    # `systemctl --user import-environment` (WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP,
    # DBUS_SESSION_BUS_ADDRESS, XAUTHORITY) — NOT niri's per-process `environment`
    # block. So re-export the two vars noctalia actually needs that live there:
    #   - NOCTALIA_PAM_SERVICE: without it the lockscreen falls back to PAM "login"
    #     → "setuid failed" → can never unlock (see the comment in niri.nix).
    #   - QT_QPA_PLATFORM=wayland: keep the Qt platform explicit, as under niri.
    systemd.user.services.noctalia.Service.Environment = [
      "NOCTALIA_PAM_SERVICE=noctalia"
      "QT_QPA_PLATFORM=wayland"
    ];

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
