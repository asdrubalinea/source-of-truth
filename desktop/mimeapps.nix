{ ... }:
let
  gwenview = "org.kde.gwenview.desktop";

  # Image types Gwenview advertises in its .desktop MimeType field. Mapping
  # all of them keeps "open image" consistent regardless of format.
  imageTypes = [
    "image/png"
    "image/jpeg"
    "image/gif"
    "image/webp"
    "image/x-webp"
    "image/avif"
    "image/heif"
    "image/jxl"
    "image/bmp"
    "image/tiff"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/x-icns"
    "image/x-ico"
    "image/x-eps"
    "image/x-psd"
    "image/x-tga"
    "image/x-xcf"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
    "image/openraster"
  ];
in
{
  # Default-application map. Migrated from the previously app-generated
  # ~/.config/mimeapps.list so defaults live in source control. Home Manager
  # writes this file read-only, so GUI "set as default" no longer sticks —
  # change defaults here instead.
  #
  # (The old list also pointed discord:// at vesktop, which is currently
  # disabled in home-packages.nix; dropped until vesktop is re-enabled.)
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      {
        # Web browser
        "x-scheme-handler/http" = "zen-beta.desktop";
        "x-scheme-handler/https" = "zen-beta.desktop";
        "x-scheme-handler/chrome" = "zen-beta.desktop";
        "text/html" = "zen-beta.desktop";
        "application/xhtml+xml" = "zen-beta.desktop";
        "application/x-extension-htm" = "zen-beta.desktop";
        "application/x-extension-html" = "zen-beta.desktop";
        "application/x-extension-shtml" = "zen-beta.desktop";
        "application/x-extension-xhtml" = "zen-beta.desktop";
        "application/x-extension-xht" = "zen-beta.desktop";

        # Misc URL scheme handlers
        "x-scheme-handler/about" = "google-chrome.desktop";
        "x-scheme-handler/unknown" = "google-chrome.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        "x-scheme-handler/sgnl" = "signal.desktop";
        "x-scheme-handler/signalcaptcha" = "signal.desktop";
        "x-scheme-handler/postman" = "Postman.desktop";
        "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";

        # Documents
        "application/pdf" = "okularApplication_pdf.desktop";
      }
      # Images -> Gwenview
      // builtins.listToAttrs (map
        (t: {
          name = t;
          value = gwenview;
        })
        imageTypes);
  };

  # KService application catalog for Dolphin (and any other KDE file manager)
  # under niri. Without this, double-clicking a file in Dolphin pops the
  # "Open With" picker every time and ignores the defaults above — even though
  # `xdg-mime query default image/jpeg` correctly returns Gwenview.
  #
  # Why: KIO resolves a mimetype's handler through KService, whose application
  # catalog is built by kbuildsycoca6 from an XDG menu file named
  # `${XDG_MENU_PREFIX}applications.menu`. A Plasma session exports
  # XDG_MENU_PREFIX=plasma- and ships plasma-applications.menu; the niri session
  # sets neither the variable nor any menu file, so kbuildsycoca6 enumerates
  # ZERO apps and KService can offer no handler for any type → the picker.
  # (Verified with `kbuildsycoca6 --menutest`: 62 apps listed with this file,
  # 0 without.) mimeapps.list itself is read fine; the catalog it points into is
  # simply empty. Providing the standard "include everything" menu — matching
  # the unset/empty prefix — repopulates it. Inert on a real Plasma session,
  # which reads plasma-applications.menu instead.
  xdg.configFile."menus/applications.menu".text = ''
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN" "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <Include>
        <All/>
      </Include>
    </Menu>
  '';
}
