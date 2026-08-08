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
#     --isolate-net            private network namespace with outbound-only
#                              connectivity via pasta(1). Blocks the host's
#                              loopback services AND the abstract-socket
#                              namespace (which is what exposes the host X
#                              server to the sandbox). Not yet the default --
#                              see the CAGE_DEFAULT_NET note below.
#     --nonet                  isolate the network (fully offline sandbox)
#
# Every sandbox is isolated: the home directory is a fresh tmpfs, only the
# launch-time working directory is writable from the host, and the runtime
# dir is restricted to this session's own zellij socket (no ssh-agent/dbus/
# gnupg, and no other session's socket).
#
# NOTE on --net (the default): sharing the host network namespace also shares
# the host's *abstract* AF_UNIX socket namespace, which is not hidden by the
# /tmp tmpfs. The host X server listens there and accepts unauthenticated
# clients, so under --net a sandboxed process has full X11 rights against
# host XWayland apps (input injection, key capture, clipboard). Host loopback
# services are reachable for the same reason. Use --isolate-net to close both.
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
# sandbox automatically. Each session gets its OWN socket directory on the
# host ($XDG_RUNTIME_DIR/cage/<name>), bind-mounted rw onto the sandbox's
# $XDG_RUNTIME_DIR/zellij: a zellij client attached from the host reaches the
# server that runs INSIDE the namespace, so every pane/window it spawns is
# sandboxed, while the sandbox only ever sees its own control socket.
# Binding the shared $XDG_RUNTIME_DIR/zellij instead (as this script used to)
# put every *host* session's socket inside every sandbox, which is a full
# escape: `zellij attach <host-session>` from inside reaches a server that
# lives in the host namespace. The host-session guards below are host-side
# CLI checks and do not help there.
#
# Lifecycle: a session belongs to the invocation that created it (the one
# running bwrap). When that client detaches it is PID 1 of the namespaces,
# and the kernel tears the whole PID namespace down on its exit, so the
# session ends automatically on detach. --die-with-parent additionally
# tears the sandbox down if the launching shell or terminal dies. There is
# no way to leave an orphaned namespace behind.
set -euo pipefail

usage() {
  echo "usage: cage [start|attach|agent|list|stop|stop-all] [name] [--net|--isolate-net|--nonet]" >&2
}

# Default network mode. `net` shares the host stack (the long-standing
# behaviour); `isolated` is the hardened mode described in the header. Override
# per-invocation with the flags, or for a whole shell with CAGE_NET=isolated.
# Flip this default to `isolated` once pasta has been smoke-tested here.
CAGE_DEFAULT_NET="${CAGE_NET:-net}"

# Address of the DNS forwarder pasta runs inside the sandbox netns. Link-local,
# so it cannot collide with the LAN (10.0.0.0/24) or the tailnet (100.64/10).
CAGE_DNS_FORWARD=169.254.1.1

# Derive a default session name from the current working directory (basename)
# when the user does not supply one.  This way `cage` from different directories
# creates separate sandbox sessions instead of all attaching to a single
# "sandbox" session.  Users who want a custom name can still run `cage <name>`.
default_session_name() {
  basename "$PWD"
}

# Session names now compose a filesystem path ($XDG_RUNTIME_DIR/cage/<name>)
# that teardown removes with `rm -rf`, so restrict them to a safe character
# set. Sanitising rather than rejecting keeps `cage` working in directories
# whose basename contains spaces or other awkward characters.
sanitize_session_name() {
  local clean
  clean="$( printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-' )"
  case "$clean" in
    '' | . | ..) clean=sandbox ;;
    [-.]*) clean="s$clean" ;;
  esac
  printf '%s' "$clean"
}

# Parse positionals (subcommand, name) and flag options. The network flag
# only matters at session creation; re-attaching reuses the existing mounts.
POS=()
NET="$CAGE_DEFAULT_NET"
for a in "$@"; do
  case "$a" in
    --net) NET=net ;;
    --isolate-net) NET=isolated ;;
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
NAME_RAW="$NAME"
NAME="$(sanitize_session_name "$NAME")"
if [ "$NAME" != "$NAME_RAW" ]; then
  echo "cage: session name normalised to '$NAME'" >&2
fi

sandbox_cmd() {
  local cwd="$1"
  shift
  local shift_args=("$@")
  [ -n "$XDG_RUNTIME_DIR" ] || {
    echo "cage: XDG_RUNTIME_DIR is not set" >&2
    exit 1
  }
  # This session's private socket dir must exist on the host BEFORE the bind
  # (bwrap requires the source path to exist); create it on first use.
  local sockroot
  sockroot="$(sock_root "$NAME")"
  mkdir -p "$sockroot"

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
    # Only THIS session's socket dir, never the shared one (see header).
    --bind "$sockroot" "$XDG_RUNTIME_DIR/zellij"
    # Wayland socket: bind-mount the compositor's socket so sandboxed tools
    # (wl-copy/wl-paste for clipboard, grim/slurp for screenshots) can
    # interact with the host display server. Deliberately opt-in via
    # --bind-try: when the socket path doesn't exist the mount is silently
    # skipped — no leak on headless usage. The :- default matters: this script
    # runs under `set -u`, so a bare $WAYLAND_DISPLAY made cage abort outright
    # on an SSH/headless login rather than skipping the mount.
    --bind-try "$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-.cage-no-wayland}" \
      "$XDG_RUNTIME_DIR/${WAYLAND_DISPLAY:-.cage-no-wayland}"
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
  # Network. --net (default) shares the host stack, which also shares the
  # host's abstract AF_UNIX socket namespace and loopback. --nonet is fully
  # offline. --isolate-net keeps outbound connectivity but puts the sandbox in
  # its own netns, so the host X server and host loopback services stop being
  # reachable; pasta(1) then restores outbound traffic from the host side.
  case "$NET" in
    nonet)
      bargs+=(--unshare-net)
      ;;
    isolated)
      command -v pasta >/dev/null 2>&1 || {
        echo "cage: --isolate-net needs pasta(1) from the passt package" >&2
        exit 1
      }
      # /etc is bound read-only from the host, and the host resolver here is a
      # tailscale address that does not exist in the new netns, so point the
      # sandbox at pasta's forwarder instead.
      printf 'nameserver %s\noptions edns0\n' "$CAGE_DNS_FORWARD" \
        >"$sockroot/resolv.conf"
      bargs+=(
        --unshare-net
        --ro-bind "$sockroot/resolv.conf" /etc/resolv.conf
        --info-fd 3
      )
      ;;
  esac

  if [ "$NET" = isolated ]; then
    rm -f "$sockroot/info.json"
    attach_network "$sockroot/info.json" &
    bwrap "${bargs[@]}" "${shift_args[@]}" 3>"$sockroot/info.json"
  else
    bwrap "${bargs[@]}" "${shift_args[@]}"
  fi
}

# Wait for bwrap to publish the sandbox PID on --info-fd, then hand the fresh
# network namespace to pasta. pasta backgrounds itself and exits when the
# namespace goes away, so there is nothing to clean up afterwards.
attach_network() {
  local info="$1" pid='' i=0
  while [ "$i" -lt 100 ]; do
    if [ -s "$info" ]; then
      pid="$( tr -d '\n ' <"$info" \
        | sed -n 's/.*"child-pid":\([0-9]\{1,\}\).*/\1/p' )"
      [ -n "$pid" ] && break
    fi
    i=$(( i + 1 ))
    sleep 0.1
  done
  [ -n "$pid" ] || {
    echo "cage: could not read the sandbox PID; it has no network" >&2
    return 1
  }
  # --no-map-gw is load-bearing: pasta's default maps the gateway address back
  # to the host's loopback, which would hand back exactly the host-loopback
  # access this mode exists to remove. --dns-forward is also required, since
  # pasta forwards no DNS unless asked.
  pasta --quiet --config-net --no-map-gw \
    --dns-forward "$CAGE_DNS_FORWARD" "$pid" || {
    echo "cage: pasta failed to configure the sandbox network" >&2
    return 1
  }
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

# Host-side location of a session's private socket directory.
sock_root() {
  printf '%s/cage/%s' "$XDG_RUNTIME_DIR" "$1"
}

# XDG_RUNTIME_DIR a host-side zellij *client* must use to reach the server with
# the given PID. Sandboxed servers keep their socket in the per-session dir;
# host servers use the real runtime dir. A sandbox started by an older cage
# (shared socket dir) falls back correctly, because its per-session directory
# will not exist.
client_runtime_dir() {
  local pid="$1" name
  if is_sandboxed_pid "$pid"; then
    name="$(server_session "$pid")"
    if [ -n "$name" ] && [ -d "$(sock_root "$name")" ]; then
      sock_root "$name"
      return 0
    fi
  fi
  printf '%s' "$XDG_RUNTIME_DIR"
}

stop_session() {
  local wanted="$1" pid name found=0
  while read -r pid; do
    [ -z "$pid" ] && continue
    name="$(server_session "$pid")"
    [ "$name" != "$wanted" ] && continue
    found=1
    if is_sandboxed_pid "$pid"; then
      local rt
      rt="$(client_runtime_dir "$pid")"
      XDG_RUNTIME_DIR="$rt" zellij kill-session "$name" >/dev/null 2>/dev/null || true
      zellij delete-session "$name" >/dev/null 2>/dev/null || true
      rm -rf "$(sock_root "$name")" 2>/dev/null || true
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
  local pid name rt found=0
  while read -r pid; do
    [ -z "$pid" ] && continue
    if is_sandboxed_pid "$pid"; then
      name="$(server_session "$pid")"
      [ -n "$name" ] || continue
      rt="$(client_runtime_dir "$pid")"
      XDG_RUNTIME_DIR="$rt" zellij kill-session "$name" >/dev/null 2>/dev/null || true
      zellij delete-session "$name" >/dev/null 2>/dev/null || true
      rm -rf "$(sock_root "$name")" 2>/dev/null || true
      echo "cage: stopped $name"
      found=1
    fi
  done < <(server_pids)
  # Plain `[ ... ] && echo` would make a successful stop-all exit nonzero,
  # since it is the last command in the function.
  if [ "$found" = 0 ]; then
    echo "cage: no sandbox sessions running"
  fi
}

case "$ACTION" in
  start|attach)
    cwd="$(realpath "$PWD")"
    if server_pid_for "$NAME" >/dev/null; then
      # A live session with this name exists: only attach to it if it is
      # actually a sandbox. Never silently attach to a host zellij session.
      if is_sandbox_session "$NAME"; then
        # The server's socket lives in this session's private dir, so point the
        # client at it. Only the socket lookup uses XDG_RUNTIME_DIR; config and
        # cache come from XDG_CONFIG_HOME / XDG_CACHE_HOME and are unaffected.
        pid="$(server_pid_for "$NAME")"
        exec env XDG_RUNTIME_DIR="$(client_runtime_dir "$pid")" \
          zellij attach "$NAME"
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
      rm -rf "$(sock_root "$NAME")" 2>/dev/null || true
      if [ "$cwd" = "$HOME" ]; then
        echo "cage: the sandbox has an empty tmpfs HOME; cd into a workspace dir first" >&2
        exit 1
      fi
      echo "cage: starting $NAME in $cwd"
      sandbox_cmd "$cwd" -- zellij -s "$NAME"
      # When the creating client detaches it is PID 1 of the namespace;
      # the kernel then reaps every process in it, tearing the session down
      # automatically. The server dies with it before zellij can remove its
      # socket and the session entry from its internal state, so drop the
      # whole per-session socket dir here.
      zellij delete-session "$NAME" >/dev/null 2>/dev/null || true
      rm -rf "$(sock_root "$NAME")" 2>/dev/null || true
    fi
    ;;
  list)
    # Enumerate live servers by process rather than via `zellij list-sessions`:
    # sandboxed servers now keep their sockets in per-session dirs the host
    # client does not scan. This is also more accurate than the old listing,
    # which labelled every dead-but-resurrectable session "(host)" because
    # is_sandbox_session needs a live server to answer.
    found=0
    while read -r pid; do
      [ -z "$pid" ] && continue
      name="$(server_session "$pid")"
      [ -n "$name" ] || continue
      if is_sandboxed_pid "$pid"; then
        echo "$name  (sandbox)"
      else
        echo "$name  (host)"
      fi
      found=1
    done < <(server_pids)
    if [ "$found" = 0 ]; then
      echo "cage: no live zellij sessions"
    fi
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
