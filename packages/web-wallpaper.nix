{
  python3Packages,
  wrapGAppsHook3,
  gobject-introspection,
  gtk3,
  gtk-layer-shell,
  glib-networking,
  webkitgtk_4_1,
}:
# `web-wallpaper <url>` — a web page as the wallpaper, via ./web-wallpaper.py.
python3Packages.buildPythonApplication {
  pname = "web-wallpaper";
  version = "0.1";
  pyproject = false;
  dontUnpack = true;

  nativeBuildInputs = [wrapGAppsHook3 gobject-introspection];
  # glib-networking is GIO's TLS module: without it every https page is "TLS support is not available".
  buildInputs = [gtk3 gtk-layer-shell webkitgtk_4_1 glib-networking];
  dependencies = [python3Packages.pygobject3];

  installPhase = "install -Dm755 ${./web-wallpaper.py} $out/bin/web-wallpaper";

  # One wrapper, not two: hand the GApps typelib/schema env to the Python wrap.
  dontWrapGApps = true;
  preFixup = ''makeWrapperArgs+=("''${gappsWrapperArgs[@]}")'';

  meta.mainProgram = "web-wallpaper";
}
