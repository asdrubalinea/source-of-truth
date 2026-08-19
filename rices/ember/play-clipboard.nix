# Play the URL on the clipboard in mpv. Bound to Mod+Y by both compositor layers,
# which is why it lives up here rather than inside one of them (ADR 0012).
#
# The point is to keep video out of the browser: Chrome's VAAPI/VCN decode paints
# blocky artifacts on this machine (docs/av1-vaapi-decode-artifacts.md), while mpv
# decodes in software by default. Copy a YouTube link, hit the key.
#
# A script rather than an inline bind because neither compositor runs its spawn
# through a shell — niri's takes an argv list, mango's splits the line on commas —
# so `mpv "$(wl-paste)"` has nothing to expand it. Not a module and not in
# ./default.nix's imports: it is a plain function, imported for its value the way
# ./compositors/*/window-rules.nix are.
#
# Both failure paths notify. A keybind that spawns a window-less process has no
# other channel: mpv dying during startup looks exactly like the bind not firing,
# and mpv does die on some videos — YouTube serves a few only over SABR, which
# yt-dlp cannot fetch (the stream URLs it gets back carry `rqh=1` and 403), so the
# right diagnosis has to reach the screen rather than a discarded stderr.
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

    # Startup is not instant — yt-dlp has to mint a PO token and probe formats, so
    # several seconds pass with nothing on screen. -p returns the notification's id
    # so the failure path can replace this toast in place rather than stack a second
    # one under it; on success mpv's own window is the signal and the toast expires.
    id=$($notify -p -t 30000 "mpv" "Loading video…" || true)

    log=$(${pkgs.coreutils}/bin/mktemp)
    trap '${pkgs.coreutils}/bin/rm -f "$log"' EXIT

    # …and take it down again the moment mpv initialises an output, which is when
    # the window appears and the toast has nothing left to say. mpv prints those
    # two lines at default verbosity, so watching the log beats asking mpv over an
    # IPC socket. The 30s expiry above is only the backstop for this loop giving up.
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

    # yt-dlp is named explicitly instead of being left to PATH: mpv's ytdl_hook
    # shells out to it, and a compositor-spawned process inherits the session
    # environment, not an interactive shell's. Same reason
    # ./compositors/niri/marquee.nix passes this option. It has to be the wrapped
    # one — plain pkgs.yt-dlp 403s on almost every video now, see
    # ../../packages/yt-dlp-pot.nix.
    if ! ${pkgs.mpv}/bin/mpv \
      --script-opts=ytdl_hook-ytdl_path=${ytDlp}/bin/yt-dlp \
      -- "$url" > "$log" 2>&1; then
      $notify -r "''${id:-0}" -u critical "mpv failed" "$(${pkgs.coreutils}/bin/tail -n 2 "$log")"
      exit 1
    fi
  ''
