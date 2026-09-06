#!/usr/bin/env bash
# ocelot — a per-project dev VM you enter over ssh. Sibling of `cage`.
#
#   ocelot                    start (if needed) and enter the ocelot of $PWD
#   ocelot <name>             same, for a named ocelot
#   ocelot start [name]       start without entering
#   ocelot enter [name]       enter, starting first if it is not running
#   ocelot stop [name]        shut the machine down; its state survives
#   ocelot destroy [name]     delete its state; the next start is a fresh machine
#   ocelot list               every ocelot, running or not
#   ocelot status [name]      systemctl --user status for the guest's unit
#   ocelot logs [name]        the guest's console + journal (follow with -f)
#   ocelot ssh [name] [cmd…]  run a command inside, or open a plain shell
#
#   Options:
#     -y                      don't ask for confirmation (destroy)
#     -f                      follow (logs)
#
# What an ocelot is, and what it is not, is CONTEXT.md, *Isolation (tempest)*.
# Why it is shaped this way is docs/adr/0013-ocelot-per-project-dev-vm.md. The
# short version: it bounds MESS, not malice. The agent credentials are carried
# inside on purpose, exactly as cage carries them, so anything running in an
# ocelot can read them.
#
# The three moving parts, none of which needs root:
#
#   virtiofsd × 2   the host /nix/store read-only (the guest's execution path,
#                   which is why this is not 9p), and one staging directory this
#                   script composes with bubblewrap — the project plus the agent
#                   credential dirs, which live in scattered places under $HOME
#                   and cannot be one share without a mount namespace to gather
#                   them. Unprivileged, so --sandbox none and no uid mapping:
#                   everything in a share is irene on both sides.
#   passt           the only route in or out. Exactly one port is forwarded, the
#                   guest's sshd, bound on 127.0.0.1.
#   systemd-run     the guest is a transient user unit, which is where stop,
#                   status, journal and survival-across-terminal-death come from
#                   for free. This inverts cage deliberately: cage's client is
#                   PID 1 of its namespaces and the session dies on detach,
#                   whereas the whole point here is that the containers you left
#                   running are still running.
#
# Lifecycle: the unit's main process is qemu; virtiofsd and passt are its
# cgroup siblings, so KillMode=mixed lets qemu exit first and then reaps them.
# `stop` asks the guest to power down over the qemu monitor and only stops the
# unit if it will not.
set -euo pipefail

# Where state disks live. rpool/vms on tempest, with a tmpfiles rule handing
# irene a subdir (hosts/tempest/system/virtualization.nix) — the same shape
# /var/lib/containers/rootless/irene already has, and off /persist for the same
# reason docker's dataset is: a layer cache must not be pinned in every hourly
# sanoid snapshot and shipped to the backup drive.
OCELOT_ROOT="${OCELOT_ROOT:-/var/lib/vms/irene}"

# The tree an ocelot is built from. Hard-coded like the rest of this repo's
# scripts; see CLAUDE.md on the path being load-bearing.
OCELOT_FLAKE="${OCELOT_FLAKE:-/persist/source-of-truth}"

# Sparse, so this is a ceiling and not an allocation. Holds the docker layer
# cache and the guest home.
OCELOT_STATE_SIZE="${OCELOT_STATE_SIZE:-64G}"

# What is carried in from the host home, at these names. Read-write, as in cage
# and for the same reason: the tools are already logged in. ~/.ssh is
# deliberately absent — `git push` works through ForwardAgent, so the private
# key never crosses. hosts/ocelot/system/runtime.nix binds whatever is staged
# here, so this list is the only place to add to.
# Entries are paths relative to $HOME and MAY be nested: the list is handed to
# the guest verbatim (conf/creds) rather than rediscovered by walking the share,
# so `.config/opencode` binds onto ~/.config/opencode and not onto ~/.config.
# That distinction is load-bearing now that the guest generates its own
# ~/.config/{zellij,fish,helix} — binding the parent would bury the theme.
OCELOT_CREDS=(
  .claude
  .claude.json
  .agents
  .codex
  .pi
  .hermes
  .cache

  # opencode is installed in the guest (desktop/cli-packages.nix) but keeps its
  # auth outside the config dir, so both halves have to cross or it is simply
  # logged out in here. cage binds the same two.
  .config/opencode
  .local/share/opencode/auth.json
)

SELF="$(realpath "${BASH_SOURCE[0]}")"

usage() {
  echo "usage: ocelot [start|enter|stop|destroy|list|status|logs|ssh] [name] [-y] [-f]" >&2
}

die() {
  echo "ocelot: $*" >&2
  exit 1
}

# Names compose filesystem paths, a systemd unit name, an ssh config stanza and
# a zellij session name, so restrict them to a safe set. Sanitising rather than
# rejecting keeps `ocelot` working in a directory whose basename has a space in
# it — the same trade cage makes.
sanitize_name() {
  local clean
  clean="$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '-')"
  case "$clean" in
    '' | . | ..) clean=project ;;
    [-.]*) clean="o$clean" ;;
  esac
  printf '%s' "$clean"
}

state_dir() { printf '%s/%s' "$OCELOT_ROOT" "$1"; }
unit_name() { printf 'ocelot-%s.service' "$1"; }
ssh_host() { printf 'ocelot-%s' "$1"; }
stanza_path() { printf '%s/.ssh/config.d/ocelot-%s' "$HOME" "$1"; }

run_dir() {
  [ -n "${XDG_RUNTIME_DIR:-}" ] || die "XDG_RUNTIME_DIR is not set"
  printf '%s/ocelot/%s' "$XDG_RUNTIME_DIR" "$1"
}

is_running() {
  systemctl --user --quiet is-active "$(unit_name "$1")" 2>/dev/null
}

# --- creation -----------------------------------------------------------------

port_taken() {
  local port="$1" claim
  # Bound by anything on this machine right now.
  [ -n "$(ss -Hltn "sport = :$port" 2>/dev/null)" ] && return 0
  # Or already claimed by another ocelot that simply is not running.
  for claim in "$OCELOT_ROOT"/*/port; do
    [ -r "$claim" ] || continue
    [ "$(dirname "$claim")" = "$(state_dir "$2")" ] && continue
    [ "$(cat "$claim")" = "$port" ] && return 0
  done
  return 1
}

# One port per ocelot, allocated once and then recorded, because the ssh config
# stanza and the seeded known_hosts entry both name it. Derived from the name so
# two ocelots created in either order still land somewhere different.
alloc_port() {
  local name="$1" sd port
  sd="$(state_dir "$name")"
  if [ -r "$sd/port" ]; then
    cat "$sd/port"
    return 0
  fi
  port=$((20000 + $(printf '%s' "$name" | cksum | awk '{print $1}') % 9000))
  while port_taken "$port" "$name"; do
    port=$((port + 1))
    [ "$port" -lt 30000 ] || die "no free port in 20000-29999"
  done
  printf '%s\n' "$port" >"$sd/port"
  printf '%s' "$port"
}

# The ssh config stanza is what makes everything that speaks ssh work by name —
# including `port-forward ocelot-<name> 3000`, unmodified. It is included from
# ~/.ssh/config via programs.ssh.includes (homes/tempest/default.nix).
#
# The host key was generated here and its public half went into this ocelot's
# own known_hosts in the same breath, so there is never a TOFU prompt and never
# a changed-key warning — and `destroy` removes both halves together, so a
# rebuilt ocelot cannot inherit a stale one.
write_stanza() {
  local name="$1" port="$2" sd stanza
  sd="$(state_dir "$name")"
  stanza="$(stanza_path "$name")"
  mkdir -p "$(dirname "$stanza")"
  chmod 700 "$(dirname "$stanza")"
  cat >"$stanza" <<EOF
# Generated by ocelot(1) for $(cat "$sd/project"). Removed by \`ocelot destroy $name\`.
Host $(ssh_host "$name")
  HostName 127.0.0.1
  Port $port
  User irene
  UserKnownHostsFile $sd/known_hosts
  StrictHostKeyChecking yes
  ForwardAgent yes
EOF
  chmod 600 "$stanza"
}

# Everything an ocelot needs before it can be started for the first time. Safe
# to re-run: each step is guarded, so this also repairs a half-created one.
ensure_created() {
  local name="$1" project="$2" sd port recorded
  sd="$(state_dir "$name")"

  if [ ! -d "$OCELOT_ROOT" ]; then
    die "$OCELOT_ROOT does not exist.
       On tempest it is created by the tmpfiles rule in
       hosts/tempest/system/virtualization.nix, on the rpool/vms dataset — so
       this needs one 'zfs create -o mountpoint=/var/lib/vms rpool/vms' plus a
       rebuild. Override with OCELOT_ROOT= to put state elsewhere."
  fi

  if [ -r "$sd/project" ]; then
    recorded="$(cat "$sd/project")"
    if [ "$recorded" != "$project" ] && [ "$NAME_FROM_CWD" = 1 ]; then
      die "'$name' is the ocelot of
       $recorded
       not of
       $project
       Two directories share a basename. Name this one explicitly:
       ocelot <some-other-name>"
    fi
  else
    mkdir -p "$sd"
    chmod 700 "$sd"
    printf '%s\n' "$project" >"$sd/project"
  fi

  port="$(alloc_port "$name")"

  if [ ! -e "$sd/ssh_host_ed25519_key" ]; then
    ssh-keygen -q -t ed25519 -N '' -C "$(ssh_host "$name")" \
      -f "$sd/ssh_host_ed25519_key"
  fi
  printf '[127.0.0.1]:%s %s\n' "$port" \
    "$(cut -d' ' -f1,2 <"$sd/ssh_host_ed25519_key.pub")" >"$sd/known_hosts"

  write_stanza "$name" "$port"

  # The stanza is only useful if ssh actually reads ~/.ssh/config.d, which is
  # programs.ssh.includes in homes/tempest/default.nix. Without it every ssh
  # here would fail to resolve the host and the only symptom would be a
  # two-minute wait, so check it once at creation and say what to do.
  if ! ssh -G "$(ssh_host "$name")" 2>/dev/null | grep -qx "port $port"; then
    die "ssh is not reading ~/.ssh/config.d/.
       Add 'Include config.d/*' to ~/.ssh/config — that is
       programs.ssh.includes in homes/tempest/default.nix — and activate it:
       nh home switch -b backup"
  fi

  if [ ! -e "$sd/state.img" ]; then
    echo "ocelot: formatting a $OCELOT_STATE_SIZE state disk for $name"
    truncate -s "$OCELOT_STATE_SIZE" "$sd/state.img"
    # root_owner=0:0 because mke2fs otherwise hands the new filesystem's root
    # directory to the *invoking* uid, and in the guest that root is /state,
    # which impermanence populates as root.
    mkfs.ext4 -q -L ocelot-state -E root_owner=0:0 "$sd/state.img"
  fi
}

# --- running ------------------------------------------------------------------

wait_for_socket() {
  local path="$1" i=0
  while [ "$i" -lt 100 ]; do
    [ -S "$path" ] && return 0
    i=$((i + 1))
    sleep 0.1
  done
  return 1
}

# The body of the transient unit. Not a user-facing subcommand: it expects to be
# PID 1-ish of its own cgroup with the guest already created.
do_run() {
  local name="$1" sd rd project port stage socket binds=() entry
  sd="$(state_dir "$name")"
  rd="$(run_dir "$name")"
  project="$(cat "$sd/project")"
  port="$(cat "$sd/port")"

  # A fresh runtime dir every start: it holds nothing but sockets and the
  # staging skeleton, and a leftover socket from a crashed guest would be
  # connected to instead of the new one.
  rm -rf "$rd"
  stage="$rd/staging"
  mkdir -p "$stage/conf" "$stage/creds" "$stage/project"

  # This ocelot's identity, read at boot by hosts/ocelot/system/runtime.nix.
  # In the staging directory rather than on the kernel command line, which
  # cannot carry a path containing a space without quoting games.
  printf '%s\n' "$name" >"$stage/conf/name"
  printf '%s\n' "$project" >"$stage/conf/project"
  install -m 600 "$sd/ssh_host_ed25519_key" "$stage/conf/ssh_host_ed25519_key"
  install -m 644 "$sd/ssh_host_ed25519_key.pub" "$stage/conf/ssh_host_ed25519_key.pub"

  # Mount points for what bubblewrap is about to compose in. Only for sources
  # that actually exist, so the guest binds nothing empty over a real directory.
  binds+=(--bind "$project" "$stage/project")
  : >"$stage/conf/creds"
  for entry in "${OCELOT_CREDS[@]}"; do
    [ -e "$HOME/$entry" ] || continue
    if [ -d "$HOME/$entry" ]; then
      mkdir -p "$stage/creds/$entry"
    else
      mkdir -p "$(dirname "$stage/creds/$entry")"
      : >"$stage/creds/$entry"
    fi
    # What was staged, in order, for the guest to bind. Written here rather than
    # rediscovered in the guest so a nested entry stays nested (see the array).
    printf '%s\n' "$entry" >>"$stage/conf/creds"
    binds+=(--bind "$HOME/$entry" "$stage/creds/$entry")
  done

  # The host store. --cache always is safe precisely because the store is
  # immutable, and it matters more here than anywhere else: this share is where
  # every binary the guest executes is read from.
  virtiofsd \
    --socket-path="$rd/store.sock" \
    --shared-dir /nix/store \
    --sandbox none \
    --readonly \
    --cache always \
    --inode-file-handles=never \
    --log-level warn &

  # The staging share. bubblewrap is here only to compose mounts, not as a
  # boundary: --dev-bind / / keeps the host visible to virtiofsd (it needs
  # /nix/store to run at all) and the --bind arguments gather the project and
  # the credential dirs under one root, which is what lets a single virtiofsd
  # serve them. The namespace dies with this process, so nothing is left
  # mounted anywhere.
  bwrap --dev-bind / / "${binds[@]}" -- \
    virtiofsd \
    --socket-path="$rd/host.sock" \
    --shared-dir "$stage" \
    --sandbox none \
    --inode-file-handles=never \
    --log-level warn &

  # Outbound connectivity plus exactly one inbound port, bound on loopback:
  # the guest is unreachable except through it. --one-off makes passt exit when
  # qemu disconnects.
  #
  # --mtu 1500 is not cosmetic. passt defaults to 65520 and advertises it over
  # DHCP; virtio-net's link MTU is 1500, so dhcpcd logs "advertised MTU 65520 is
  # greater than link MTU 1500", declines it on the link — and still installs it
  # on the routes, which is how you get a route MTU above the link MTU and TCP
  # computing an MSS for frames the link cannot carry.
  #
  # ponytail: 1500 leaves passt's large-frame throughput on the table. The
  # upstream-recommended alternative is to raise the *link* instead
  # (host_mtu=65520 on the virtio-net-pci device below) and drop this flag;
  # do that if an ocelot's network throughput ever becomes the complaint.
  passt --quiet --one-off --foreground \
    --mtu 1500 \
    --socket "$rd/net.sock" \
    --tcp-ports "127.0.0.1/$port:22" &

  for socket in "$rd/store.sock" "$rd/host.sock" "$rd/net.sock"; do
    wait_for_socket "$socket" || die "$socket never appeared"
  done

  # Everything that differs per ocelot. qemu-vm bakes the rest (memory, cores,
  # the memfd backend vhost-user needs, the kernel and the append line); see
  # hosts/ocelot/default.nix.
  export QEMU_OPTS="\
-chardev socket,id=vstore,path=$rd/store.sock \
-device vhost-user-fs-pci,chardev=vstore,tag=nix-store \
-chardev socket,id=vhost,path=$rd/host.sock \
-device vhost-user-fs-pci,chardev=vhost,tag=ocelot-host \
-netdev stream,id=net0,addr.type=unix,addr.path=$rd/net.sock \
-device virtio-net-pci,netdev=net0 \
-drive file=$sd/state.img,format=raw,if=virtio,discard=unmap \
-chardev socket,id=mon,path=$rd/monitor.sock,server=on,wait=off \
-mon chardev=mon,mode=readline"

  # TMPDIR: the runner would otherwise mktemp a directory per start and leave it
  # behind. USE_TMPDIR makes it use ours, which is removed on the next start.
  export TMPDIR="$rd" USE_TMPDIR=1
  exec "$sd/system/bin/run-ocelot-vm"
}

do_start() {
  local name="$1" project="$2" sd
  ensure_created "$name" "$project"
  sd="$(state_dir "$name")"

  if is_running "$name"; then
    return 0
  fi

  # Built on every start, which is what makes ephemeral root the update
  # mechanism: a change to desktop/cli-packages.nix reaches every ocelot at its
  # next boot with no per-guest rebuild to remember.
  #
  # The out-link is also load-bearing as a gcroot. A running ocelot is not in
  # tempest's system closure and programs.nh.clean runs weekly, so without this
  # `nh clean all` can delete store paths out from under a live guest.
  nix build --out-link "$sd/system" \
    "$OCELOT_FLAKE#nixosConfigurations.ocelot.config.system.build.vm"

  echo "ocelot: starting $name ($project) on port $(cat "$sd/port")"
  # A transient unit does not inherit this shell's environment, and the guest
  # console is the only place a failed boot is visible — hence the explicit
  # journal wiring and the OCELOT_ROOT pass-through (without which the unit
  # would look for its state disk somewhere else than the shell just created it).
  systemd-run --user --quiet --collect \
    --unit="ocelot-$name" \
    --description="ocelot $name — $project" \
    --property=KillMode=mixed \
    --property=TimeoutStopSec=120 \
    --property=StandardOutput=journal \
    --property=StandardError=journal \
    --setenv=OCELOT_ROOT="$OCELOT_ROOT" \
    -- "$SELF" __run "$name"
}

wait_for_ssh() {
  local name="$1" i=0
  while [ "$i" -lt 120 ]; do
    if ssh -o ConnectTimeout=2 -o BatchMode=yes "$(ssh_host "$name")" true \
      >/dev/null 2>&1; then
      return 0
    fi
    is_running "$name" || return 1
    i=$((i + 1))
    sleep 1
  done
  return 1
}

# Attached to a zellij session inside the guest, the same idiom as cage, so a
# dropped connection does not kill a build. --create attaches or starts.
do_enter() {
  local name="$1" project="$2"
  [ -t 0 ] || die "enter needs a terminal. For one command, use: ocelot ssh $name <cmd>"
  do_start "$name" "$project"
  wait_for_ssh "$name" || die "$name never answered on ssh; try: ocelot logs $name"
  exec ssh -t "$(ssh_host "$name")" -- zellij attach --create "$name"
}

do_ssh() {
  local name="$1" tty=()
  shift
  is_running "$name" || die "$name is not running"
  wait_for_ssh "$name" || die "$name never answered on ssh"
  # Only ask for a pty when there is one to give, or every scripted
  # `ocelot ssh <name> <cmd>` prints ssh's "Pseudo-terminal will not be
  # allocated" warning on stderr.
  [ -t 0 ] && tty=(-t)
  if [ "$#" -eq 0 ]; then
    exec ssh ${tty[@]+"${tty[@]}"} "$(ssh_host "$name")"
  fi
  exec ssh ${tty[@]+"${tty[@]}"} "$(ssh_host "$name")" -- "$@"
}

# stop ends the MACHINE and keeps everything it accumulated; destroy ends the
# STATE. Not degrees of one action — see CONTEXT.md. So this asks the guest to
# power down over the qemu monitor and gives it time, rather than pulling the
# plug on a live ext4 and a live docker.
do_stop() {
  local name="$1" rd i=0
  if ! is_running "$name"; then
    echo "ocelot: $name is not running"
    return 0
  fi
  rd="$(run_dir "$name")"
  if [ -S "$rd/monitor.sock" ]; then
    printf 'system_powerdown\n' \
      | socat -T2 - "UNIX-CONNECT:$rd/monitor.sock" >/dev/null 2>&1 || true
  fi
  while [ "$i" -lt 120 ]; do
    if ! is_running "$name"; then
      echo "ocelot: stopped $name"
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  echo "ocelot: $name ignored the power button; stopping the unit" >&2
  systemctl --user stop "$(unit_name "$name")"
}

do_destroy() {
  local name="$1" sd reply
  sd="$(state_dir "$name")"
  [ -d "$sd" ] || die "no ocelot named '$name'"
  if [ "$ASSUME_YES" != 1 ]; then
    echo "ocelot: this deletes $name's state disk — its container images, its" >&2
    echo "        home and its shell history. The project itself is untouched." >&2
    read -r -p "        destroy $name? [y/N] " reply
    case "$reply" in
      y | Y | yes | YES) ;;
      *) die "not destroying $name" ;;
    esac
  fi
  do_stop "$name"
  rm -rf -- "$sd" "$(run_dir "$name")"
  rm -f -- "$(stanza_path "$name")"
  echo "ocelot: destroyed $name"
}

do_list() {
  local sd name state port project found=0
  for sd in "$OCELOT_ROOT"/*/; do
    [ -d "$sd" ] || continue
    name="$(basename "$sd")"
    state=stopped
    is_running "$name" && state=running
    port="$(cat "$sd/port" 2>/dev/null || echo '-')"
    project="$(cat "$sd/project" 2>/dev/null || echo '-')"
    printf '%-24s %-8s %-6s %s\n' "$name" "$state" "$port" "$project"
    found=1
  done
  if [ "$found" = 0 ]; then
    echo "ocelot: no ocelots"
  fi
}

# --- argument handling --------------------------------------------------------

POS=()
ASSUME_YES=0
FOLLOW=0
if [ "${1:-}" = ssh ]; then
  # Everything after `ssh` is the remote command and is passed through
  # untouched: `ocelot ssh demo grep -f pattern` must not have its -f eaten as
  # one of ocelot's own flags.
  POS=("$@")
else
  for a in "$@"; do
    case "$a" in
      -y | --yes) ASSUME_YES=1 ;;
      -f | --follow) FOLLOW=1 ;;
      --) ;;
      -h | --help)
        usage
        exit 0
        ;;
      --*)
        echo "ocelot: unknown option: $a" >&2
        usage
        exit 1
        ;;
      *) POS+=("$a") ;;
    esac
  done
fi

ACTION="${POS[0]:-}"
NAME="${POS[1]:-}"
NAME_FROM_CWD=0

case "$ACTION" in
  __run)
    [ -n "$NAME" ] || die "__run needs a name"
    do_run "$(sanitize_name "$NAME")"
    exit 0
    ;;
  list)
    do_list
    exit 0
    ;;
  start | enter | stop | destroy | status | logs | ssh) ;;
  "")
    ACTION=enter
    ;;
  *)
    # Short form: `ocelot <name>` means start-or-enter a named ocelot.
    NAME="$ACTION"
    ACTION=enter
    ;;
esac

if [ -z "$NAME" ]; then
  NAME="$(basename "$PWD")"
  NAME_FROM_CWD=1
fi
NAME_RAW="$NAME"
NAME="$(sanitize_name "$NAME")"
[ "$NAME" = "$NAME_RAW" ] || echo "ocelot: name normalised to '$NAME'" >&2

case "$ACTION" in
  start | enter)
    PROJECT="$(realpath "$PWD")"
    [ "$PROJECT" != "$HOME" ] || die "an ocelot is of a project, not of \$HOME"
    if [ "$ACTION" = start ]; then
      do_start "$NAME" "$PROJECT"
    else
      do_enter "$NAME" "$PROJECT"
    fi
    ;;
  stop) do_stop "$NAME" ;;
  destroy) do_destroy "$NAME" ;;
  status) systemctl --user status "$(unit_name "$NAME")" ;;
  logs)
    if [ "$FOLLOW" = 1 ]; then
      journalctl --user -u "$(unit_name "$NAME")" -f
    else
      journalctl --user -u "$(unit_name "$NAME")" --no-pager
    fi
    ;;
  ssh)
    shift_args=("${POS[@]:2}")
    do_ssh "$NAME" ${shift_args[@]+"${shift_args[@]}"}
    ;;
  *)
    usage
    exit 1
    ;;
esac
