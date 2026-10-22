{
  pkgs,
  lib,
  ...
}: let
  # One combine sink fanning the same audio out to every connected Bluetooth
  # headset, for watching something with two pairs of headphones.
  #
  # `pw-cli -m load-module` loads the module into the pw-cli process itself (the
  # man page's "local instance"), so the sink lives exactly as long as that
  # process — no config drop-in, no daemon restart, and stopping the unit is the
  # whole teardown.
  #
  # The targets come from a `stream.rules` regex rather than a MAC list, which
  # also means a headset that connects (or drops and reconnects) after the sink
  # exists is picked up on its own.
  match = "~bluez_output.*";

  due-cuffie = pkgs.writeScriptBin "due-cuffie" ''
    #!${pkgs.stdenv.shell}
    set -eu
    export PATH=${lib.makeBinPath [pkgs.coreutils pkgs.gnugrep pkgs.gnused pkgs.jq pkgs.wireplumber pkgs.systemd]}

    unit=due-cuffie
    sink=due_cuffie
    match="''${DUE_CUFFIE_MATCH-${match}}"
    state="''${XDG_RUNTIME_DIR:-/tmp}/due-cuffie.prev"

    pw_cli=${pkgs.pipewire}/bin/pw-cli
    pw_dump=${pkgs.pipewire}/bin/pw-dump

    is_on() { systemctl --user --quiet is-active "$unit" 2>/dev/null; }

    # Node id for a node.name; empty when that node is not in the graph.
    id_of() {
      "$pw_dump" | jq -r --arg n "$1" \
        'first(.[] | select(.info.props["node.name"] == $n) | .id) // empty'
    }

    # The sinks $match currently selects, one node.name per line.
    targets() {
      "$pw_dump" \
        | jq -r '.[] | select(.info.props["media.class"] == "Audio/Sink") | .info.props["node.name"]' \
        | grep -E "''${match#"~"}" || true
    }

    start() {
      if is_on; then
        echo "due-cuffie: already on" >&2
        return 0
      fi

      n=$(targets | wc -l)
      if [ "$n" -eq 0 ]; then
        echo "due-cuffie: nothing matches $match — connect the headphones first" >&2
        exit 1
      fi
      if [ "$n" -lt 2 ]; then
        echo "due-cuffie: only $n sink matches so far; the rest join as they connect" >&2
      fi

      # combine.latency-compensate aligns the streams on the latency each sink
      # *reports*, which cannot see the delay inside an earbud's own DSP. Off by
      # default because for two different headsets it is a coin flip whether it
      # improves lip sync or just adds buffering; DUE_CUFFIE_COMPENSATE=1 to try.
      compensate=false
      if [ -n "''${DUE_CUFFIE_COMPENSATE-}" ]; then
        compensate=true
      fi

      # Remember where audio was going so stop can put it back.
      wpctl inspect @DEFAULT_AUDIO_SINK@ \
        | sed -n 's/.*[[:space:]]node\.name = "\(.*\)"/\1/p' > "$state" || true

      # Transient unit rather than a pidfile: free journald logging, and stop /
      # status come from systemd. --collect keeps a crash from leaving a failed
      # unit that blocks the next start.
      systemd-run --user --collect --quiet \
        --unit="$unit" --description="Combine sink over $match" \
        "$pw_cli" -m load-module libpipewire-module-combine-stream \
        "{ combine.mode = sink
           node.name = $sink
           node.description = \"Due cuffie\"
           combine.latency-compensate = $compensate
           combine.props = { audio.position = [ FL FR ] }
           stream.rules = [ { matches = [ { media.class = \"Audio/Sink\" node.name = \"$match\" } ]
                              actions = { create-stream = { } } } ] }"

      i=0
      while [ -z "$(id_of "$sink")" ]; do
        i=$((i + 1))
        if [ "$i" -ge 25 ]; then
          echo "due-cuffie: sink never appeared — journalctl --user -u $unit -e" >&2
          exit 1
        fi
        sleep 0.2
      done

      # Any node with a node.link-group is filed under wpctl's "Filters", not
      # "Sinks" — so this is invisible in the usual sink list and has to be
      # selected by id.
      wpctl set-default "$(id_of "$sink")"
      echo "due-cuffie: on -> $(targets | tr '\n' ' ')" >&2
    }

    stop() {
      if ! is_on; then
        echo "due-cuffie: already off" >&2
        return 0
      fi
      systemctl --user stop "$unit"

      # set-default writes a *persistent* default, so leaving it pointed at the
      # combine sink means the next start silently steals the audio again.
      prev=$(cat "$state" 2>/dev/null || true)
      rm -f "$state"
      back=""
      if [ -n "$prev" ]; then
        back=$(id_of "$prev")
      fi
      if [ -n "$back" ]; then
        wpctl set-default "$back"
      fi
      echo "due-cuffie: off''${back:+ (back to $prev)}" >&2
    }

    case "''${1-toggle}" in
      on | start) start ;;
      off | stop) stop ;;
      toggle) if is_on; then stop; else start; fi ;;
      status)
        if is_on; then
          echo "on -> $(targets | tr '\n' ' ')"
        else
          echo off
        fi
        ;;
      log) exec journalctl --user -u "$unit" -e ;;
      *)
        echo "usage: due-cuffie [toggle|on|off|status|log]" >&2
        exit 1
        ;;
    esac
  '';
in {home.packages = [due-cuffie];}
