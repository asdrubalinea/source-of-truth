# Called with `c` = config.lib.stylix.colors.withHashtag (see ./niri.nix). The
# file is a function rather than a plain list only so the screencast-target rule
# below can take its colours from the palette instead of restating hexes — see
# principle 4 in docs/ember-visual-language.md.
c: [
  {
    # Square window corners (all windows — no `matches` ⇒ catch-all), DERIVED
    # from the bar's edge treatment: this used to be 12.0 on all four to match
    # the floating Noctalia bar's radius, and the bar is now flush and square
    # (rices/ember/noctalia-widgets.nix). See "bar" in CONTEXT.md — the bar is
    # the one place that value is decided; this follows it.
    #
    # Deliberately still stated rather than deleted. Without the rule niri falls
    # back to its own default, and this file should say what the corners are —
    # the pairing with clip-to-geometry below is the whole point: 0 corners with
    # clipping on means an app that draws its own rounded corners (GTK4 dialogs,
    # Electron) gets squared off with the rest instead of being the one window on
    # screen with a curve.
    geometry-corner-radius = {
      top-left = 0.0;
      top-right = 0.0;
      bottom-right = 0.0;
      bottom-left = 0.0;
    };
    clip-to-geometry = true;
  }
  {
    matches = [
      {is-floating = true;}
    ];
    shadow.enable = true;
  }
  {
    matches = [
      {
        is-window-cast-target = true;
      }
    ];
    # A window being screencast is the one state that has earned a colour: it
    # is transient, it is a fact you want answered at a glance, and base08 is
    # what the mango layer already uses for its urgent border (see
    # ../mango/mango.nix). These used to be four hand-typed catppuccin-ish
    # hexes, which is the bug principle 4 describes — they belonged to no
    # palette and could not follow the scheme. Alphas match the layout borders
    # in ./niri.nix: 73 for the lit half of a pair, 26 for the unlit one.
    border = {
      active.color = c.base08 + "73";
      inactive.color = c.base01 + "26";
    };
    shadow = {
      color = c.base08 + "40";
    };
    tab-indicator = {
      active.color = c.base08 + "73";
      inactive.color = c.base01 + "26";
    };
  }
  {
    matches = [{app-id = "org.telegram.desktop";}];
    block-out-from = "screencast";
  }
  {
    # Telegram scratchpad geometry: float it, centered, at ~55%×85% of the
    # working area (proportional so it adapts to any output). niri centers new
    # floating windows by default, so default-floating-position is deliberately
    # omitted (a known niri bug also ignores it under open-floating —
    # niri-wm/niri#3420). The block-out-from rule above still applies; both
    # match the same app-id. See docs/adr/0006-niri-scratchpad-via-nirius.md.
    matches = [{app-id = "org.telegram.desktop";}];
    open-floating = true;
    default-column-width = {
      proportion = 0.55;
    };
    default-window-height = {
      proportion = 0.85;
    };
  }
  {
    # Floating terminal scratchpad (Mod+Shift+Return): a near-fullscreen floating
    # wezterm, sized as a proportion of the working area so it adapts to any
    # output. niri centers new floating windows by default, so
    # default-floating-position is omitted (see the Telegram rule above). The
    # app-id comes from wezterm's `--class scratchpad-terminal`. See
    # rices/ember/compositors/niri/niri.nix (terminalScratchpad).
    matches = [{app-id = "scratchpad-terminal";}];
    open-floating = true;
    default-column-width = {
      proportion = 0.9;
    };
    default-window-height = {
      proportion = 0.9;
    };
  }
  {
    # Instrument panel (Mod+I): a floating, transient `sitrep`. Sized as a
    # proportion so it adapts to any output; open-focused because the readout is
    # dismissed by a keypress, and an unfocused window would send it elsewhere.
    # The app-id comes from wezterm's `--class sitrep-hud`; see
    # rices/ember/sitrep-hud.nix.
    matches = [{app-id = "sitrep-hud";}];
    open-floating = true;
    open-focused = true;
    default-column-width = {
      proportion = 0.6;
    };
    default-window-height = {
      proportion = 0.85;
    };
  }
  {
    matches = [{app-id = "app.drey.PaperPlane";}];
    block-out-from = "screencast";
  }
  {
    matches = [
      {app-id = "zen";}
      {app-id = "firefox";}
      {app-id = "chromium-browser";}
      {app-id = "xdg-desktop-portal-gtk";}
    ];
    scroll-factor = 1.0;
  }
  {
    matches = [
      {app-id = "zen";}
      {app-id = "firefox";}
      {app-id = "chromium-browser";}
      {app-id = "edge";}
    ];
    open-maximized = true;
  }
  {
    matches = [{app-id = "^drift-screensaver$";}];
    open-fullscreen = true;
    open-focused = true;
  }
  {
    matches = [
      {
        app-id = "firefox";
        title = "Picture-in-Picture";
      }
    ];
    open-floating = true;
    default-floating-position = {
      x = 32;
      y = 32;
      relative-to = "bottom-right";
    };
    default-column-width = {
      fixed = 480;
    };
    default-window-height = {
      fixed = 270;
    };
  }
  {
    matches = [
      {
        app-id = "zen";
        title = "Picture-in-Picture";
      }
    ];
    open-floating = true;
    default-floating-position = {
      x = 32;
      y = 32;
      relative-to = "bottom-right";
    };
    default-column-width = {
      fixed = 480;
    };
    default-window-height = {
      fixed = 270;
    };
  }
  {
    matches = [{title = "Picture in picture";}];
    open-floating = true;
    default-floating-position = {
      x = 32;
      y = 32;
      relative-to = "bottom-right";
    };
  }
  {
    matches = [{title = "Discord Popout";}];
    open-floating = true;
    default-floating-position = {
      x = 32;
      y = 32;
      relative-to = "bottom-right";
    };
  }
  {
    matches = [{app-id = "io.github.fsobolev.Cavalier";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "dialog";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "popup";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "task_dialog";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "gcr-prompter";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "file-roller";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "org.gnome.FileRoller";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "nm-connection-editor";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "xdg-desktop-portal-gtk";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "org.kde.polkit-kde-authentication-agent-1";}];
    open-floating = true;
  }
  {
    matches = [{app-id = "pinentry";}];
    open-floating = true;
  }
  {
    matches = [{title = "Progress";}];
    open-floating = true;
  }
  {
    matches = [{title = "File Operations";}];
    open-floating = true;
  }
  {
    matches = [{title = "Copying";}];
    open-floating = true;
  }
  {
    matches = [{title = "Moving";}];
    open-floating = true;
  }
  {
    matches = [{title = "Properties";}];
    open-floating = true;
  }
  {
    matches = [{title = "Downloads";}];
    open-floating = true;
  }
  {
    matches = [{title = "file progress";}];
    open-floating = true;
  }
  {
    matches = [{title = "Confirm";}];
    open-floating = true;
  }
  {
    matches = [{title = "Authentication Required";}];
    open-floating = true;
  }
  {
    matches = [{title = "Notice";}];
    open-floating = true;
  }
  {
    matches = [{title = "Warning";}];
    open-floating = true;
  }
  {
    matches = [{title = "Error";}];
    open-floating = true;
  }
  {
    # Emacs popup frames (magit, *Help*, *compilation*, vterm, claude…) —
    # see display-buffer-alist in desktop/emacs/init.el. They tile as a
    # side column at full column height; project frames keep their default
    # behavior because they don't carry the popup: prefix.
    matches = [
      {
        app-id = "^emacs$";
        title = "^popup:";
      }
    ];
    default-column-width = {
      fixed = 1100;
    };
  }
]
