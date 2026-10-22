# Prepended by packages/helium.nix: HELIUM, SYNCTHING_CONFIG, FOLDER.
#
# The profile is a syncthing folder shared with the other desktop. Starting the
# browser on top of a half-synced profile means SQLite files from two different
# moments; so: wait until the folder is idle and nothing is still needed from
# the peer, then start. After the browser quits, scan and wait until the peer
# has caught up, so it's safe to shut this machine down.

api() {
  curl -fsS -m 3 -H "X-API-Key: $apikey" "http://127.0.0.1:8384/rest/$1" "${@:2}"
}

# Chromium hands a second invocation's arguments to the running instance and
# exits, so a URL opened from elsewhere while the browser is up needs no gate
# and must not trigger the post-quit wait either.
if pgrep -f "/opt/helium/helium" >/dev/null; then
  exec "$HELIUM" "$@"
fi

# No syncthing here (or not up yet): plain browser.
if [ ! -r "$SYNCTHING_CONFIG" ]; then
  exec "$HELIUM" "$@"
fi
apikey=$(grep -o '<apikey>[^<]*' "$SYNCTHING_CONFIG" | head -1 | cut -c9-)
if ! api "system/ping" >/dev/null 2>&1; then
  exec "$HELIUM" "$@"
fi

# A peer that connected a moment ago hasn't finished exchanging indexes yet, so
# the folder can look idle while changes are about to arrive. Give it a beat.
newest=$(api "system/connections" | jq -r '[.connections[] | select(.connected) | .startedAt] | max // empty' || true)
if [ -n "$newest" ] && started=$(date -d "$newest" +%s 2>/dev/null); then
  age=$(( $(date +%s) - started ))
  if [ "$age" -lt 10 ]; then
    sleep $((10 - age))
  fi
fi

deadline=$((SECONDS + 120))
notified=0
while :; do
  status=$(api "db/status?folder=$FOLDER") || break
  state=$(jq -r '.state' <<<"$status")
  need=$(jq -r '.needTotalItems' <<<"$status")
  if [ "$state" = idle ] && [ "$need" = 0 ]; then
    break
  fi
  if [ "$notified" = 0 ]; then
    notify-send -a Helium "Helium" "Waiting for the profile to finish syncing ($state, $need items left)…"
    notified=1
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    notify-send -u critical -a Helium "Helium" "Profile still syncing after 2 minutes ($state, $need items). Starting anyway — the other host may have newer state."
    break
  fi
  sleep 2
done
if [ "$notified" = 1 ] && [ "$SECONDS" -lt "$deadline" ]; then
  notify-send -a Helium "Helium" "Profile synced, starting."
fi

rc=0
"$HELIUM" "$@" || rc=$?

# Quit: push this session's state out before the machine goes away.
api "db/scan?folder=$FOLDER" -X POST >/dev/null 2>&1 || exit "$rc"
mapfile -t peers < <(api "config/folders/$FOLDER" | jq -r '.devices[].deviceID' || true)
myid=$(api "system/status" | jq -r '.myID' || true)
deadline=$((SECONDS + 300))
pending=1
while [ "$SECONDS" -lt "$deadline" ]; do
  pending=0
  for peer in "${peers[@]}"; do
    [ "$peer" = "$myid" ] && continue
    # Not connected: nothing to wait for; the folder syncs when they next meet.
    api "system/connections" | jq -e --arg p "$peer" '.connections[$p].connected' >/dev/null 2>&1 || continue
    done_pct=$(api "db/completion?folder=$FOLDER&device=$peer" | jq -r '.completion' || echo 0)
    if [ "$done_pct" != "100" ]; then
      pending=1
    fi
  done
  [ "$pending" = 0 ] && break
  sleep 3
done
if [ "$pending" = 0 ]; then
  notify-send -a Helium "Helium" "Profile handed off: the other host has this session's state."
else
  notify-send -u critical -a Helium "Helium" "Profile still being pushed to the other host after 5 minutes — keep this machine up a little longer."
fi
exit "$rc"
