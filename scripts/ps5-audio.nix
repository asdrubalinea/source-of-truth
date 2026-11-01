# Loop a hardware line-in into whatever sink is current, so a console playing
# natively on the monitor is heard on the headphones.
#
# Machine policy comes from the importing home: `capture` is the PipeWire
# node.name of the input the monitor's analog out is plugged into, `missing`
# is what to say when it is absent. Both of today's inputs are genuine stereo
# captures (2ch FL/FR), so there is no port switching or channel remapping.
#
# Total latency is dominated by the headphones' Bluetooth codec buffer
# (~150-250ms), which no amount of graph tuning touches — so the loopback
# targets a relaxed 20ms rather than chasing a small quantum and risking
# xruns. Still lower than routing PS5 audio through a chiaki stream, which
# stacks Opus encode + network + jitter buffer on top of the same tail.
{
  capture,
  missing,
}: {pkgs, ...}: let
  ps5-audio = pkgs.writeScriptBin "ps5-audio" ''
    #!${pkgs.stdenv.shell}
    set -eu

    unit=ps5-audio
    capture=${capture}
    systemctl=${pkgs.systemd}/bin/systemctl
    systemd_run=${pkgs.systemd}/bin/systemd-run
    pw_dump=${pkgs.pipewire}/bin/pw-dump
    pw_loopback=${pkgs.pipewire}/bin/pw-loopback

    is_on() { "$systemctl" --user --quiet is-active "$unit" 2>/dev/null; }

    start() {
      if is_on; then
        echo "ps5-audio: already on" >&2
        return 0
      fi
      if ! "$pw_dump" | grep -qF "$capture"; then
        echo "ps5-audio: ${missing}" >&2
        exit 1
      fi
      # No -P: pw-loopback then follows the default sink, so the route survives
      # headphone reconnects (whose node ids change) without hardcoding a MAC.
      # Override with PS5_AUDIO_SINK=<node.name> to pin a specific sink.
      set -- -n "$unit" -C "$capture" --latency 20
      if [ -n "''${PS5_AUDIO_SINK-}" ]; then
        set -- "$@" -P "$PS5_AUDIO_SINK"
      fi
      # Transient unit rather than a pidfile: free journald logging, and stop /
      # status come from systemd. --collect keeps a crash from leaving a failed
      # unit that blocks the next start.
      "$systemd_run" --user --collect --quiet \
        --unit="$unit" --description="PS5 line-in loopback" \
        "$pw_loopback" "$@"
      echo "ps5-audio: on (line-in -> ''${PS5_AUDIO_SINK-default sink})" >&2
    }

    stop() {
      if is_on; then
        "$systemctl" --user stop "$unit"
        echo "ps5-audio: off" >&2
      else
        echo "ps5-audio: already off" >&2
      fi
    }

    case "''${1-toggle}" in
      on | start) start ;;
      off | stop) stop ;;
      toggle) if is_on; then stop; else start; fi ;;
      status)
        if is_on; then echo "on"; else echo "off"; fi
        ;;
      log) exec ${pkgs.systemd}/bin/journalctl --user -u "$unit" -e ;;
      *)
        echo "usage: ps5-audio [toggle|on|off|status|log]" >&2
        exit 1
        ;;
    esac
  '';
in {home.packages = [ps5-audio];}
