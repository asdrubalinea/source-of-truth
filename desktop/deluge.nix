# Default Trackers is linked by ngosang/trackerslist. It preserves existing
# trackers, skips private torrents, and also handles torrents restored at startup.
{
  config,
  lib,
  pkgs,
  ...
}: let
  plugin = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/stefantalpalaru/deluge-default-trackers/c799ed6bba561c646e86e1ab878d025f4b6d5876/egg/DefaultTrackers-0.6-py3.12.egg";
    hash = "sha256-LBjhR+u/k+lYlxqdeKd1CKtS6Z2f+v89iK+kwCYO6HM=";
  };
in {
  # The egg contains Python source; upstream documents renaming its Python tag
  # to match Deluge's interpreter. Keep it in step with nixpkgs' Python.
  xdg.configFile."deluge/plugins/DefaultTrackers-0.6-py${pkgs.python3.pythonVersion}.egg".source = plugin;

  # Deluge rewrites these files, so merge the managed settings into writable
  # files instead of linking core.conf or the plugin's cache into the store.
  home.activation.delugeTrackers = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if ${pkgs.procps}/bin/pgrep -u "$(${pkgs.coreutils}/bin/id -u)" -f '(^|/)[.]?deluge(d|-gtk)?(-wrapped)?([[:space:]]|$)' >/dev/null; then
      echo "Deluge is running; close it and activate Home Manager again to configure Default Trackers." >&2
    else
      run ${pkgs.python3}/bin/python3 ${./deluge/configure.py} ${lib.escapeShellArg "${config.xdg.configHome}/deluge"}
    fi
  '';
}
