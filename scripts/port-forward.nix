{ pkgs, ... }:

let
  portForward = pkgs.writeScriptBin "port-forward" ''
    #!${pkgs.stdenv.shell}

    # Check for correct number of arguments
    if [ "$#" -ne 2 ]; then
        echo "Usage: $0 <remote_host> <remote_port>"
        exit 1
    fi

    REMOTE_HOST="$1"
    REMOTE_PORT="$2"

    ssh -L "$REMOTE_PORT:localhost:$REMOTE_PORT" "$REMOTE_HOST"
  '';
in
{
  home.packages = [ portForward ];
}
