{pkgs, ...}: let
  portForward = pkgs.writeScriptBin "port-forward" ''
    #!${pkgs.stdenv.shell}

    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <remote_host> <port1> [<port2> ...]"
        exit 1
    fi

    REMOTE_HOST="$1"
    shift

    # Each remaining argument becomes an -L <port>:localhost:<port>, so the
    # local and remote port numbers are always the same — that is the whole
    # convention this wrapper exists to encode.
    SSH_ARGS=""
    for port in "$@"; do
        SSH_ARGS="$SSH_ARGS -L $port:localhost:$port"
    done

    exec ssh $SSH_ARGS "$REMOTE_HOST"
  '';
in {
  home.packages = [portForward];
}
