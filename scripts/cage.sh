#!/usr/bin/env bash
# Isolated persistent sandbox: bubblewrap + zellij.
#
#   cage                      start OR attach to a session named from cwd
#   cage <name>               same, named session
#   cage start [name]         start a new isolated sandbox
#   cage agent [name]         alias for start (kept for backwards compat)
#   cage attach [name]        attach if running, otherwise start
#   cage stop <name>          stop a sandboxed session (refuses host sessions)
#   cage stop-all             stop every sandboxed session (host zellij untouched)
#   cage list                 list sessions, marking sandboxed vs host
#
#   Options (may appear anywhere):
#     --net                    share the host network (DEFAULT; opencode needs it)
#     --nonet                  isolate the network (fully offline sandbox)
#
# Every sandbox is isolated: the home directory is a fresh tmpfs, only the
# launch-time working directory is writable from the host, and the runtime
# dir is restricted to the zellij socket (no ssh-agent/dbus/Wayland/gnupg).
# ~/.nix-profile, ~/.config/opencode and the opencode auth file are bound
# in read-only. ~/.hermes (hermes' whole config/auth/sessions dir) is
# bound read-write, like ~/.pi, so sandboxed hermes persists state.
# Claude Code (~/.claude, ~/.claude.json) and Codex (~/.codex) are also
# bound read-write so their auth, config and session history persist.
# ~/.config/fish (including aliases) is bound read-only and
# ~/.local/share/fish (shell history) is bound read-write so fish inside
# the sandbox has the same aliases and persistent history as the host.
#
# Everything run inside the attached zellij session (nix develop, opencode,
# builds, ...) descends from a bwrap namespace, so it is confined to the
# sandbox automatically. The zellij server socket lives under
# $XDG_RUNTIME_DIR, which is bind-mounted rw host <-> sandbox: a zellij
# client attached from the host reaches the server that runs INSIDE the
# namespace, so every pane/window it spawns is sandboxed.
#
# Lifecycle: a session belongs to the invocation that created it (the one
# running bwrap). When that client detaches it is PID 1 of the namespaces,
# and the kernel tears the whole PID namespace down on its exit, so the
# session ends automatically on detach. --die-with-parent additionally
# tears the sandbox down if the launching shell or terminal dies. There is
# no way to leave an orphaned namespace behind.
set -euo pipefail

usage() {
  echo "usage: cage [start|attach|agent|list|stop|stop-all] [name] [--net|--nonet]" >&2
}

# Derive a default session name from the current working directory (basename)
# when the user does not supply one.  This way `cage` from different directories
# creates separate sandbox sessions instead of all attaching to a single
# "sandbox" session.  Users who want a custom name can still run `cage <name>`.
default_session_name() {
  basename "$PWD"
}

# Parse positionals (subcommand, name) and flag options. The network flag
# only matters at session creation; re-attaching reuses the existing mounts.
POS=()
NET=net
for a in "$@"; do
  case "$a" in
    --net) NET=net ;;
    --nonet) NET=nonet ;;
    --) ;;
    --*)
      echo "cage: unknown option: $a" >&2
      usage
      exit 1
      ;;
    *) POS+=("$a") ;;
  esac
done

ACTION="${POS[0]:-}"
NAME="${POS[1]:-}"

case "$ACTION" in
  start|attach|list|stop|stop-all) ;;
  agent)
    ACTION="start"
    NAME="${NAME:-agent}"
    ;;
  "")
    ACTION="attach"
    NAME="${NAME:-$(default_session_name)}"
    ;;
  *)
    # Short form: `cage <name>` means start-or-attach a named session.
    NAME="$ACTION"
    ACTION="attach"
    ;;
esac
NAME="${NAME:-$(default_session_name)}"

sandbox_cmd() {
  local cwd="$1"
  shift
  local shift_args=("$@")
  [ -n "$XDG_RUNTIME_DIR" ] || {
    echo "cage: XDG_RUNTIME_DIR is not set" >&2
    exit 1
  }
  # The zellij socket dir must exist on the host BEFORE the bind (bwrap
  # requires the source path to exist); create it on first use.
  mkdir -p "$XDG_RUNTIME_DIR/zellij"

  local bargs=(
    --die-with-parent
    --unshare-user --unshare-pid --unshare-ipc --unshare-uts
    --hostname "sandbox-$NAME"
    --setenv SANDBOXED cage
    --proc /proc
    --dev-bind /dev /dev
    --tmpfs /tmp
    # Host dev shells can point TMPDIR below /tmp. That path disappears when
    # the sandbox replaces /tmp, so always use the sandbox-local tmpfs root.
    --setenv TMPDIR /tmp
    --ro-bind /sys /sys
    --ro-bind /bin /bin
    --ro-bind /usr/bin /usr/bin
    --ro-bind /nix/store /nix/store
    --ro-bind /nix /nix
    --ro-bind /etc /etc
    --ro-bind /run/current-system /run/current-system
    --ro-bind /run/wrappers /run/wrappers
    --bind "$XDG_RUNTIME_DIR/zellij" "$XDG_RUNTIME_DIR/zellij"
    # Wayland socket: bind-mount the compositor's socket so sandboxed tools
    # (wl-copy/wl-paste for clipboard, grim/slurp for screenshots) can
    # interact with the host display server. Deliberately opt-in via
    # --bind-try: when WAYLAND_DISPLAY is unset (e.g. SSH session) or the
    # socket path doesn't exist, the mount is silently skipped — no leak on
    # headless usage.
    --bind-try "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    --tmpfs "$HOME"
    --ro-bind-try "$HOME/.nix-profile" "$HOME/.nix-profile"
    --ro-bind-try "$HOME/.local/share/opencode/auth.json" \
      "$HOME/.local/share/opencode/auth.json"
    # opencode caches plugins/model-lists here; without it opencode
    # re-resolves @latest plugins from the npm registry on every fresh
    # sandbox (several seconds of cold-start). Bound read-write so
    # sandboxed opencode can refresh it; it holds no credentials.
    --bind-try "$HOME/.cache" "$HOME/.cache"
    --bind "$cwd" "$cwd"
    --chdir "$cwd"
    --setenv HOME "$HOME"
    --setenv USER "$USER"
  )
  # Bring the host's git config (~/.config/git, holding user.name/user.email
  # and the global gitignore) along read-only so commits made in the sandbox
  # carry the same identity as the host. Read-only: sandboxed repos should
  # override per-repo, not mutate the host's global config.
  if [ -d "$HOME/.config/git" ]; then
    bargs+=(--ro-bind "$HOME/.config/git" "$HOME/.config/git")
  fi
  # Bring the host's zellij config (theme, keybinds, welcome-banner toggle) read-only
  # so every sandbox session respects the user's zellij preferences from the start.
  if [ -d "$HOME/.config/zellij" ]; then
    bargs+=(--ro-bind "$HOME/.config/zellij" "$HOME/.config/zellij")
  fi
  # Bring the host's fish shell config (aliases, prompt, key bindings, theme,
  # plugin configs) along read-only so fish inside the sandbox starts with the
  # same aliases and interactive setup as the host. The config.fish is a
  # symlink into /nix/store which is already mounted ro in the sandbox.
  if [ -d "$HOME/.config/fish" ]; then
    bargs+=(--ro-bind "$HOME/.config/fish" "$HOME/.config/fish")
  fi
  # Fish shell history (~/.local/share/fish/fish_history) is bound read-write
  # so history typed in the sandbox persists across sessions and is shared
  # with the host. It holds no credentials; just command history.
  if [ -d "$HOME/.local/share/fish" ]; then
    bargs+=(--bind "$HOME/.local/share/fish" "$HOME/.local/share/fish")
  fi
  # Bring the host's opencode config (opencode.jsonc, agents, commands,
  # plugins, ...) along read-only so sandboxed opencode starts with the
  # usual setup, still without exposing the writable HOME.
  if [ -d "$HOME/.config/opencode" ]; then
    bargs+=(--ro-bind "$HOME/.config/opencode" "$HOME/.config/opencode")
  fi
  # Same for Pi: its whole config dir (~/.pi, holding agent/auth.json,
  # agent/settings.json, agent/models.json, sessions and tools) is bound
  # read-write so sandboxed `pi` can persist sessions and tool state.
  if [ -d "$HOME/.pi" ]; then
    bargs+=(--bind "$HOME/.pi" "$HOME/.pi")
  fi
  # Hermes (hermes-agent): its entire home (~/.hermes, holding config.yaml,
  # auth.json, sessions, cron, logs and skills) is bound read-write so
  # sandboxed `hermes` can persist sessions and auth state across runs.
  if [ -d "$HOME/.hermes" ]; then
    bargs+=(--bind "$HOME/.hermes" "$HOME/.hermes")
  fi
  # Claude Code: its data dir (~/.claude, holding config.json, auth,
  # projects history) and the legacy ~/.claude.json blob are bound
  # read-write so sandboxed `claude` keeps credentials and history.
  if [ -d "$HOME/.claude" ]; then
    bargs+=(--bind "$HOME/.claude" "$HOME/.claude")
  fi
  bargs+=(--bind-try "$HOME/.claude.json" "$HOME/.claude.json")
  # Codex CLI: its whole data dir (~/.codex, holding config.toml,
  # auth.json and sessions) is bound read-write so sandboxed `codex`
  # can persist auth and session history.
  if [ -d "$HOME/.codex" ]; then
    bargs+=(--bind "$HOME/.codex" "$HOME/.codex")
  fi
  # Network: default shares the host stack (agents need outbound HTTPS).
  # --nonet gives a fully isolated network namespace (offline).
  if [ "$NET" = nonet ]; then
    bargs+=(--unshare-net)
  fi
  bwrap "${bargs[@]}" "${shift_args[@]}"
}

# True if the given PID is a genuine zellij *server* process: its argv is
# `zellij --server <socket-path>`. Matching on argv tokens (not free text)
# ignores shells/wrappers whose command line merely mentions zellij, and
# avoids depending on the versioned socket-string `contract_version_*`, so
# this survives zellij upgrades.
# shellcheck disable=SC2086 # intentional word-splitting of /proc/pid/cmdline
is_server_pid() {
  local pid="$1" cmd bin next
  cmd="$( tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true )"
  set -- $cmd
  bin="$1"
  next="$2"
  case "$bin" in
    */zellij) ;;
    *) return 1 ;;
  esac
  [ "$next" = "--server" ] || return 1
}

# PIDs of every zellij server process (host + sandbox).
server_pids() {
  local pid
  for pid in $( pgrep -x zellij 2>/dev/null || true ); do
    is_server_pid "$pid" && echo "$pid"
  done
}

# Session name served by the given zellij server process.
server_session() {
  local pid="$1" cmd path
  cmd="$( tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true )"
  path="${cmd#*--server }"
  path="${path%% *}"
  echo "${path##*/}"
}

server_pid_for() {
  local want="$1" pid name
  while read -r pid; do
    [ -z "$pid" ] && continue
    name="$(server_session "$pid")"
    [ "$name" = "$want" ] && {
      echo "$pid"
      return 0
    }
  done < <(server_pids)
  return 1
}

is_sandboxed_pid() {
  local pid="$1" ppid
  while [ -n "$pid" ] && [ "$pid" != 0 ] && [ "$pid" != 1 ]; do
    if { grep -q "bwrap" "/proc/$pid/cmdline"; } 2>/dev/null; then
      return 0
    fi
    ppid="$( { grep '^PPid:' "/proc/$pid/status"; } 2>/dev/null | while read -r _ val; do echo "$val"; done || true )"
    [ -z "$ppid" ] && break
    pid="$ppid"
  done
  return 1
}

# True if the (live) session named $1 is a sandboxed session, i.e. its
# server process descends from a bwrap process.
is_sandbox_session() {
  local want="$1" pid
  pid="$(server_pid_for "$want")" || return 1
  is_sandboxed_pid "$pid"
}

stop_session() {
  local wanted="$1" pid name found=0
  while read -r pid; do
    [ -z "$pid" ] && continue
    name="$(server_session "$pid")"
    [ "$name" != "$wanted" ] && continue
    found=1
    if is_sandboxed_pid "$pid"; then
      zellij kill-session "$name" >/dev/null 2>/dev/null || true
      zellij delete-session "$name" >/dev/null 2>/dev/null || true
      rm -f "$XDG_RUNTIME_DIR"/zellij/*/"$wanted" 2>/dev/null || true
      echo "cage: stopped $name"
      return 0
    fi
    echo "cage: refusing to stop '$wanted': it is a host zellij session, not a sandbox" >&2
    return 1
  done < <(server_pids)
  if [ "$found" = 0 ]; then
    echo "cage: no sandbox session named '$wanted'" >&2
  fi
  return 1
}

stop_all() {
  local pid name found=0
  while read -r pid; do
    [ -z "$pid" ] && continue
    if is_sandboxed_pid "$pid"; then
      name="$(server_session "$pid")"
      [ -n "$name" ] || continue
      zellij kill-session "$name" >/dev/null 2>/dev/null || true
      zellij delete-session "$name" >/dev/null 2>/dev/null || true
      rm -f "$XDG_RUNTIME_DIR"/zellij/*/"$name" 2>/dev/null || true
      echo "cage: stopped $name"
      found=1
    fi
  done < <(server_pids)
  [ "$found" = 0 ] && echo "cage: no sandbox sessions running"
}

case "$ACTION" in
  start|attach)
    cwd="$(realpath "$PWD")"
    if server_pid_for "$NAME" >/dev/null; then
      # A live session with this name exists: only attach to it if it is
      # actually a sandbox. Never silently attach to a host zellij session.
      if is_sandbox_session "$NAME"; then
        exec zellij attach "$NAME"
      else
        echo "cage: refusing to attach to '$NAME': it is a host zellij session, not a sandbox" >&2
        exit 1
      fi
    else
      # No live server: clear any stale session entry, then start fresh.
      # delete-session works even when the server is dead (kill-session only
      # talks to a live one). Also nuke any stale socket file the dead server
      # left behind.
      zellij delete-session "$NAME" >/dev/null 2>/dev/null || true
      rm -f "$XDG_RUNTIME_DIR"/zellij/*/"$NAME" 2>/dev/null || true
      if [ "$cwd" = "$HOME" ]; then
        echo "cage: the sandbox has an empty tmpfs HOME; cd into a workspace dir first" >&2
        exit 1
      fi
      echo "cage: starting $NAME in $cwd"
      sandbox_cmd "$cwd" -- zellij -s "$NAME"
      # When the creating client detaches it is PID 1 of the namespace;
      # the kernel then reaps every process in it, tearing the session down
      # automatically. The server dies with it before zellij can remove its
      # socket and the session entry from its internal state, so prune them
      # here (globbing the socket-version dir, which is agnostic to its name).
      zellij delete-session "$NAME" >/dev/null 2>/dev/null || true
      rm -f "$XDG_RUNTIME_DIR"/zellij/*/"$NAME" 2>/dev/null || true
    fi
    ;;
  list)
    name=
    while read -r name; do
      [ -z "$name" ] && continue
      if is_sandbox_session "$name"; then
        echo "$name  (sandbox)"
      else
        echo "$name  (host)"
      fi
    done < <(zellij list-sessions -s 2>/dev/null || true)
    ;;
  stop)
    stop_session "$NAME"
    ;;
  stop-all)
    stop_all
    ;;
  *)
    usage
    exit 1
    ;;
esac
