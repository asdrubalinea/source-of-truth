{ pkgs, ... }:

let
  # Hold off automatic idle/suspend (and lid-close suspend) via a logind
  # inhibitor lock. With no args it blocks until interrupted (Ctrl-C releases
  # the lock); with args it holds the lock only while the given command runs.
  keep-awake = pkgs.writeScriptBin "keep-awake" ''
    #!${pkgs.stdenv.shell}
    inhibit=${pkgs.systemd}/bin/systemd-inhibit
    if [ "$#" -eq 0 ]; then
      echo "keeping system awake (lid stays awake too) — Ctrl-C to release" >&2
      exec "$inhibit" --what=idle:sleep:handle-lid-switch \
        --who=keep-awake --why="manual keep-awake" \
        sleep infinity
    else
      exec "$inhibit" --what=idle:sleep:handle-lid-switch \
        --who=keep-awake --why="keep-awake: $*" \
        "$@"
    fi
  '';
in
{ home.packages = [ keep-awake ]; }
