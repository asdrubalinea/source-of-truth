{ pkgs, ... }:

let
  portForward = pkgs.writeScriptBin "port-forward" ''
    #!${pkgs.stdenv.shell}

    # Check for at least a host and one port.
    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <remote_host> <port1> [<port2> ...]"
        exit 1
    fi

    REMOTE_HOST="$1"
    shift # The rest of the arguments are the ports.

    SSH_ARGS=""
    # Loop through all the port arguments.
    for port in "$@"; do
        # Append an -L option for each port.
        SSH_ARGS="$SSH_ARGS -L $port:localhost:$port"
    done

    # Execute the ssh command with all the forwarding options.
    # 'exec' replaces the shell process with the ssh process.
    exec ssh $SSH_ARGS "$REMOTE_HOST"
  '';
in
{
  home.packages = [ portForward ];
}
