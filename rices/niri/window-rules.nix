[
  {
    # Rounded window corners (all windows — no `matches` ⇒ catch-all) to match
    # the floating Noctalia bar's rounded corners (bar frameRadius = 12).
    # clip-to-geometry rounds the window surface itself, not just niri's border,
    # so app content doesn't square off the corners.
    geometry-corner-radius = {
      top-left = 12.0;
      top-right = 12.0;
      bottom-right = 12.0;
      bottom-left = 12.0;
    };
    clip-to-geometry = true;
  }
  {
    matches = [
      { is-floating = true; }
    ];
    shadow.enable = true;
  }
  {
    matches = [
      {
        is-window-cast-target = true;
      }
    ];
    border = {
      active.color = "#ff4466";
      inactive.color = "#7d0d2d";
    };
    shadow = {
      color = "#7d0d2d70";
    };
    tab-indicator = {
      active.color = "#f38ba8";
      inactive.color = "#7d0d2d";
    };
  }
  {
    matches = [{ app-id = "org.telegram.desktop"; }];
    block-out-from = "screencast";
  }
  {
    matches = [{ app-id = "app.drey.PaperPlane"; }];
    block-out-from = "screencast";
  }
  {
    matches = [
      { app-id = "zen"; }
      { app-id = "firefox"; }
      { app-id = "chromium-browser"; }
      { app-id = "xdg-desktop-portal-gtk"; }
    ];
    scroll-factor = 1.0;
  }
  {
    matches = [
      { app-id = "zen"; }
      { app-id = "firefox"; }
      { app-id = "chromium-browser"; }
      { app-id = "edge"; }
    ];
    open-maximized = true;
  }
  {
    matches = [{ app-id = "^drift-screensaver$"; }];
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
    matches = [{ title = "Picture in picture"; }];
    open-floating = true;
    default-floating-position = {
      x = 32;
      y = 32;
      relative-to = "bottom-right";
    };
  }
  {
    matches = [{ title = "Discord Popout"; }];
    open-floating = true;
    default-floating-position = {
      x = 32;
      y = 32;
      relative-to = "bottom-right";
    };
  }
  {
    matches = [{ app-id = "io.github.fsobolev.Cavalier"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "dialog"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "popup"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "task_dialog"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "gcr-prompter"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "file-roller"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "org.gnome.FileRoller"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "nm-connection-editor"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "xdg-desktop-portal-gtk"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "org.kde.polkit-kde-authentication-agent-1"; }];
    open-floating = true;
  }
  {
    matches = [{ app-id = "pinentry"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Progress"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "File Operations"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Copying"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Moving"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Properties"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Downloads"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "file progress"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Confirm"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Authentication Required"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Notice"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Warning"; }];
    open-floating = true;
  }
  {
    matches = [{ title = "Error"; }];
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
