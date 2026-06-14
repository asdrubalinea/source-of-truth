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
          mode = "dark"; # use Catppuccin's dark (Mocha) variant
          source = "builtin";
          builtin = "Catppuccin"; # coheres with the rest of the rice (stylix base16 = catppuccin-mocha)
        };

        # Keep the shell font in step with the rest of the rice (stylix owns the
        # family; see rices/niri/stylix.nix). v5 has a single shell font_family —
        # sysmon's old per-widget monospace toggle is gone.
        shell.font_family = config.stylix.fonts.sansSerif.name;

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
          default.path = "~/Pictures/Wallpapers/boeing-747.jpg";
        };
      };
    };

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
