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
      # Use one of Noctalia v5's hand-authored built-in themes (set in `theme`
      # below). stylix can't theme v5 yet — its bundled target only drives the
      # dead v4 `programs.noctalia-shell` option, and v5 support is the unmerged
      # PR danth/stylix#2364. A built-in palette is fully tuned for v5's
      # Material-3 token system, so it looks right out of the box — unlike a
      # partial hand-mapped base16 palette, which has to derive the missing tokens
      # and comes out off-hue/low-contrast (that's why an earlier custom-palette
      # attempt looked strange).
      #
      # Built-in names (theme.builtin): Ayu, Catppuccin, Dracula, Eldritch,
      # Gruvbox, Kanagawa, Noctalia, Nord, "Rosé Pine", Tokyo-Night — change the
      # one word to switch. Other sources if you'd rather not use a built-in:
      #   source = "wallpaper"  → derive M3 colors from the wallpaper
      #                           (theme.wallpaper_scheme = "m3-tonal-spot", …)
      #   source = "custom"     → read programs.noctalia.customPalettes.<name>
      #                           (palettes/<name>.json) — where a future stylix
      #                           bump would plug back in.

      # ── Declarative settings (pins ~/.config/noctalia/config.toml) ───────────
      # v5 config is TOML, validated at build time by `noctalia config validate`
      # (programs.noctalia.validateConfig, on by default): a bad VALUE fails the
      # build, an unknown key is a silent warning. The bar layout (position +
      # widgets) lives in ./noctalia-widgets.nix and merges into this same
      # config.toml; this module keeps shell enable, theming, and global shell
      # settings. Pinning config.toml makes the in-app settings GUI
      # non-persistent (read-only store symlink).
      settings = {
        theme = {
          mode = "dark";
          source = "wallpaper";
          wallpaper_scheme = "faithful"; # derive M3 colors from the current wallpaper

          # Live color templates: Noctalia writes per-app palette files at runtime
          # and reloads each app. The gtk3/gtk4 templates DON'T write a standalone
          # file — they rewrite ~/.config/gtk-{3,4}.0/gtk.css in place, appending
          # `@import url("noctalia.css");` to stylix's generated palette. That turns
          # HM's symlink into a real file, which fights `home-manager switch -b
          # backup`; stylix.nix sets `force = true` on those two gtk.css options so
          # HM overwrites in place without a colliding `.backup` (see the long note
          # there). kitty/alacritty instead consume Noctalia's output via a
          # declarative include/import so their structural config stays in Nix and
          # HM never sees a modified file. Qt is now also driven here — the "qt"
          # template writes ~/.config/qt{5,6}ct/colors/noctalia.conf (a QPalette
          # ColorScheme file); qt.nix pins qtct.conf to pick up that file with
          # style=Fusion. wezterm stays on stylix.
          templates = {
            enable_builtin_templates = true;
            builtin_ids = [ "gtk3" "gtk4" "kitty" "alacritty" "qt" ];
            enable_community_templates = false;
            community_ids = [ ];
          };
        };

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
          default.path = "~/Pictures/Wallpapers/wallhaven_yqmelx.jpg";
        };

        brightness.enable_ddcutil = true;

        backdrop.blur_intensity = 0.1;

        shell = {
          font_family = config.stylix.fonts.sansSerif.name;
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
