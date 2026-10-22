# Play the URL on the clipboard in mpv, bound to Mod+Y by both compositor layers
# — hence up here rather than inside one of them (ADR 0012).
#
# The point is keeping video out of the browser: Chrome's VAAPI/VCN decode paints
# blocky artifacts on this machine (docs/av1-vaapi-decode-artifacts.md) while mpv
# decodes in software by default.
#
# A script rather than an inline bind because neither compositor spawns through a
# shell — niri takes an argv list, mango splits on commas — so `mpv "$(wl-paste)"`
# has nothing to expand it. Not a module and not in ./default.nix's imports: a
# plain function, imported for its value like ./compositors/*/window-rules.nix.
#
# Both failure paths notify, because a keybind that spawns a window-less process
# has no other channel: mpv dying at startup looks exactly like the bind not
# firing, and it does die on some videos (YouTube serves a few only over SABR,
# which yt-dlp cannot fetch). The diagnosis has to reach the screen rather than
# a discarded stderr.
{pkgs}: let
  ytDlp = pkgs.callPackage ../../packages/yt-dlp-pot.nix {};
in
  pkgs.writeShellScript "ember-play-clipboard" ''
    set -euo pipefail

    notify=${pkgs.libnotify}/bin/notify-send

    url=$(${pkgs.wl-clipboard}/bin/wl-paste --no-newline || true)

    case "$url" in
      http://* | https://*) ;;
      *)
        # Echoing what was actually read: "no URL" alone cannot tell an empty
        # clipboard from a wl-paste that failed from a text one.
        $notify "mpv" "Not a URL: ''${url:-<clipboard empty>}"
        exit 1
        ;;
    esac

    # Startup is not instant — minting a PO token and probing formats takes
    # several seconds with nothing on screen. -p returns the notification id so
    # the failure path replaces this toast rather than stacking one under it; on
    # success mpv's window is the signal and the toast expires.
    id=$($notify -p -t 30000 "mpv" "Loading video…" || true)

    log=$(${pkgs.coreutils}/bin/mktemp)
    trap '${pkgs.coreutils}/bin/rm -f "$log"' EXIT

    # …and take it down when mpv initialises an output, i.e. when the window
    # appears. mpv prints those lines at default verbosity, so watching the log
    # beats an IPC socket. The 30s expiry above is the backstop for this loop.
    if [ -n "$id" ]; then
      (
        for _ in $(${pkgs.coreutils}/bin/seq 60); do
          if ${pkgs.gnugrep}/bin/grep -qE '^(VO|AO):' "$log" 2>/dev/null; then
            ${pkgs.glib.bin}/bin/gdbus call --session \
              --dest org.freedesktop.Notifications \
              --object-path /org/freedesktop/Notifications \
              --method org.freedesktop.Notifications.CloseNotification "$id" \
              > /dev/null 2>&1 || true
            break
          fi
          ${pkgs.coreutils}/bin/sleep 0.5
        done
      ) &
    fi

    # Named explicitly rather than left to PATH: mpv's ytdl_hook shells out to
    # it, and a compositor-spawned process inherits the session environment, not
    # an interactive shell's. Same reason marquee.nix passes this option. It must
    # be the WRAPPED one — plain pkgs.yt-dlp 403s on almost every video.
    if ! ${pkgs.mpv}/bin/mpv \
      --script-opts=ytdl_hook-ytdl_path=${ytDlp}/bin/yt-dlp \
      -- "$url" > "$log" 2>&1; then
      $notify -r "''${id:-0}" -u critical "mpv failed" "$(${pkgs.coreutils}/bin/tail -n 2 "$log")"
      exit 1
    fi
  ''
