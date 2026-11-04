# claude-notify — Claude Code's Notification hook, plus the jump back to the
# terminal that raised it. One kitty process per OS window on this setup, so
# $KITTY_PID is the compositor client's pid.
#   claude-notify          hook: reads the hook's JSON on stdin
#   claude-notify focus    Mod+C: focus the kitty that notified last
#   claude-notify wait …   internal: the detached half that waits for a click

state="${XDG_RUNTIME_DIR:-/tmp}/claude-notify-last-pid"

focus() {
  local pid=$1 id
  if [ -n "${NIRI_SOCKET:-}" ]; then
    id=$(niri msg -j windows | jq -r --argjson p "$pid" 'first(.[] | select(.pid == $p) | .id) // empty')
    if [ -n "$id" ]; then niri msg action focus-window --id "$id"; fi
  else
    id=$(mmsg get all-clients | jq -r --argjson p "$pid" 'first(.clients[] | select(.pid == $p) | .id) // empty')
    # focusid switches to the client's tag before focusing it.
    if [ -n "$id" ]; then mmsg dispatch focusid "client,$id"; fi
  fi
}

case "${1:-}" in
  focus)
    [ -r "$state" ] || exit 0
    focus "$(cat "$state")"
    ;;
  wait)
    pid=$2
    # shortcut: a click after 30 min (or on the history panel once this exits) does nothing; raise the timeout if that bites.
    action=$(timeout 30m notify-send --wait --action=default=Vai -a kitty -i kitty "Claude Code" "$3") || true
    if [ "$action" = default ] && [ -n "$pid" ]; then focus "$pid"; fi
    ;;
  *)
    body=$(jq -r '"\(.cwd | split("/") | last): \(.message)"')
    pid=${KITTY_PID:-}
    if [ -n "$pid" ]; then echo "$pid" >"$state"; fi
    # Detached: the hook has to return now, the click comes whenever it comes.
    setsid -f "$0" wait "$pid" "$body" </dev/null >/dev/null 2>&1
    ;;
esac
