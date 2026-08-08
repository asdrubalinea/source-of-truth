# cage — bubblewrap + zellij sandbox for NixOS

## Abstract

This document specifies the cage tool, a lightweight persistent sandbox
that confines processes started by a user inside a bubblewrap namespace while
providing transparent terminal access through zellij.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 [RFC2119] [RFC8174].

## 1.  Introduction

cage lets a user run arbitrary commands (builds, nix develop, opencode,
agents) inside a set of Linux namespaces.  The user starts the sandbox once,
attaches to it from any terminal, and every process spawned inside descends
from the same namespace tree.  No wrapper command is needed after the initial
attach.

There is exactly one sandbox mode, and it is **isolated**:

- The user's home directory is a fresh tmpfs inside the sandbox.  Only the
  working directory at launch time is writable from the host.
- Only this session's own zellij socket directory is reachable; ssh-agent,
  gnupg, D-Bus, PipeWire and keyrings are NOT reachable.  (The Wayland socket
  IS bound when `WAYLAND_DISPLAY` is set — see §3.4.)
- The user's home-manager profile, opencode configuration, and opencode auth
  file are mounted read-only.
- By default the sandbox shares the host network (agents need outbound HTTPS);
  `--isolate-net` gives outbound-only connectivity in a private network
  namespace, and `--nonet` is fully offline.  Note that sharing the host
  network also shares the host's abstract AF_UNIX socket namespace — see
  §3.5.

There is no "shared" mode that bind-mounts the home directory; the tool never
exposes the writable home to the sandbox.

## 2.  Definitions

- **Host**:  the NixOS system on which cage runs.
- **Sandbox**:  a set of Linux namespaces (user, pid, ipc, uts, and optionally
  net) created by bubblewrap.  Processes inside the sandbox see distinct
  process IDs, host names, IPC resources, and mount points.
- **Session**:  a zellij session that runs inside the sandbox.  Each session
  has a name, a server process, and a Unix socket.  Inside the sandbox that
  socket is at `$XDG_RUNTIME_DIR/zellij/contract_version_1/<session>`; on the
  host it lives in the session's private directory,
  `$XDG_RUNTIME_DIR/cage/<session>/contract_version_1/<session>`.
- **Session name**:  sanitised to `[A-Za-z0-9._-]` before use, because it
  composes a host path that teardown removes recursively.  Characters outside
  that set are replaced with `-`.
- **Owner**:  the `cage` invocation that created the session (the process
  running bubblewrap).  The owner's zellij client is PID 1 of the namespace.
- **Attach**:  connecting a zellij client from the host to the zellij server
  that runs inside the sandbox.

## 3.  Architecture

### 3.1.  Namespace layout

The sandbox SHALL create the following namespaces:

- User namespace (unprivileged, no root)
- PID namespace (sandbox processes have their own PID tree)
- IPC namespace (no System V IPC leak)
- UTS namespace (separate hostname)

The sandbox SHOULD NOT create a network namespace by default; the network is
shared with the host.  When `--nonet` is given, a network namespace SHALL be
created and the sandbox is fully offline (only the loopback device exists).
When `--isolate-net` is given, a network namespace SHALL be created and
`pasta(1)` SHALL be attached to it to restore outbound connectivity (§3.5).

### 3.2.  Server-in-namespace trick

The zellij server process runs inside the namespace.  Its Unix socket is
written to `$XDG_RUNTIME_DIR/zellij/` as seen from inside the sandbox, which
is a bind mount of the session's private host directory
`$XDG_RUNTIME_DIR/cage/<session>/`.  Because that directory is bind-mounted
read-write between host and sandbox, a zellij client invoked from the host can
connect to the server that runs inside the namespace.  Every pane, window, or
subprocess that the client spawns is then automatically inside the namespace.

The bind MUST be the per-session directory and MUST NOT be the shared
`$XDG_RUNTIME_DIR/zellij/`.  Binding the shared directory places every *host*
session's control socket inside every sandbox, which is a complete escape: a
process in the sandbox runs `zellij attach <host-session>` and reaches a server
living in the host namespace.  The host-session guards in §4 are host-side CLI
checks and do not constrain a process that invokes `zellij` directly.

The procedure is:

1.  The host shell starts `cage`.
2.  `cage` creates `$XDG_RUNTIME_DIR/cage/<session>/` and invokes `bwrap` with
    the namespace flags and mounts, binding it onto the sandbox's
    `$XDG_RUNTIME_DIR/zellij`.
3.  Inside the namespace, `bwrap` execs `zellij -s <session>`.
4.  The zellij server opens its socket in that directory.
5.  The host shell (or any other terminal) runs `cage attach <session>`, which
    points a zellij client at the session's private directory via
    `XDG_RUNTIME_DIR` and reaches the server inside the namespace.
6.  Every pane created by the attached client runs inside the namespace.

Because the host client needs the per-session `XDG_RUNTIME_DIR`, a bare
`zellij attach <session>` from the host no longer finds a sandboxed session;
use `cage attach <session>`.

### 3.3.  Lifecycle: sessions end on detach

A session is owned by the invocation that created it.  That invocation's
zellij client is PID 1 of the PID namespace; when it exits (detach), the
kernel tears the entire PID namespace down, which terminates the zellij server
and every pane inside it.  The session therefore ends automatically when the
owner finishes with it.

`bwrap` is additionally started with `--die-with-parent`, so the namespace is
also torn down if the owner's shell or terminal dies.

Consequences:

- There is no way to leave an orphaned namespace behind.
- A second terminal may attach to a live session, but only while the owner is
  still attached.
- Sessions are not for background processes that must outlive their terminal
  (use a plain `tmux`/`systemd` service for that).
- `--net`/`--nonet` only affect the namespace created at launch; attaching to
  an existing session reuses whatever was created.

### 3.4.  Socket isolation

Only the session's own `$XDG_RUNTIME_DIR/cage/<session>/` directory is bound
read-write between host and sandbox.  PipeWire, D-Bus, ssh-agent, gnupg and
keyring sockets are NOT reachable: they are filesystem paths outside the bind
set, so `SSH_AUTH_SOCK` and `DBUS_SESSION_BUS_ADDRESS` point at paths that do
not exist inside the sandbox.

The Wayland socket IS bound when `WAYLAND_DISPLAY` is set, so that `wl-copy`,
`wl-paste`, `grim` and `slurp` work inside the sandbox.  This grants clipboard
read/write and screen capture against the host session, and is a deliberate
trade-off rather than an oversight.

### 3.5.  Network isolation and the abstract socket namespace

Abstract AF_UNIX sockets are keyed by *network* namespace, not by filesystem
path.  Under the default `--net`, replacing `/tmp` with a tmpfs therefore does
NOT hide the host's abstract sockets, and the following remain reachable from
inside the sandbox:

- The host X server (`@/tmp/.X11-unix/X0`), which accepts unauthenticated
  clients.  This grants XTEST input injection, key capture and clipboard access
  against host XWayland applications.
- Every host loopback service, including unauthenticated admin APIs that bind
  to `127.0.0.1` on the assumption that loopback is trusted.
- The LAN and the tailnet.

`--isolate-net` SHALL create a network namespace and attach `pasta(1)` to it,
which removes the sandbox from the host's abstract socket namespace and from
host loopback while preserving outbound connectivity.  Because `/etc` is bound
read-only and the host resolver may be unreachable from the new namespace, cage
SHALL generate a `resolv.conf` pointing at pasta's DNS forwarder and bind it
over `/etc/resolv.conf`.  pasta MUST be invoked with `--no-map-gw`; without it
pasta maps the gateway address back to the host's loopback and re-opens the
access this mode exists to remove.

Outbound connections in this mode are still made from the host's stack, so LAN
and tailnet destinations remain reachable; host loopback and abstract sockets
do not.

## 4.  Command Reference

```
cage [start|attach|agent|list|stop|stop-all] [name] [--net|--isolate-net|--nonet]
```

Options:

- `--net` — share the host network (DEFAULT; required for agents that call
  model APIs).  See §3.5 for what else this shares.
- `--isolate-net` — private network namespace with outbound-only connectivity
  via `pasta(1)`.  Requires the `passt` package.
- `--nonet` — create a network namespace; the sandbox is offline.

The default may be set for a whole shell with `CAGE_NET=isolated`.

### 4.1.  `cage [start|attach] [name]`

Start or attach to a session.  If the session is already running (and is a
sandbox), attach to it.  Otherwise create a new isolated sandbox.

When no name is given, the session name is derived from the current working
directory's basename.  This means running `cage` from different directories
creates separate sandbox sessions — each directory gets its own isolated
session — instead of all attaching to a single `sandbox` session.  A user
who wants a custom or shared session can still pass an explicit name.

### 4.2.  `cage agent [name]`

Alias for `start`, kept for backwards compatibility.

The tool MUST refuse to start the session if the current working directory
equals `$HOME`.  The user SHOULD change into a project directory before
invoking this command.

### 4.3.  `cage <name>`

Short form: equivalent to `cage attach <name>`.

### 4.4.  `cage list`

List all active sessions, marking each as `(sandbox)` or `(host)`.  A session
is a sandbox if its zellij server process has a `bwrap` ancestor.

### 4.5.  `cage stop <name>`

Stop the named session, but ONLY if it is a sandboxed session.  If the name
belongs to a host zellij session, the tool MUST refuse with an error and leave
the host session untouched.  If no such session exists, the tool reports that
no sandbox session matches.

### 4.6.  `cage stop-all`

Stop every sandboxed session.  Host sessions MUST NOT be affected: a session
is only stopped if its server process has a `bwrap` ancestor.

### 4.7.  Session-name conflicts with host zellij

Host and sandbox zellij servers share one session-name space, so a requested
name MAY resolve to a host session.  In that case `start`/`attach` MUST refuse
to attach and `stop` MUST refuse to stop.  The tool never silently operates on
a host session.

These are host-side conveniences, not a security boundary: they run in the
cage CLI, and a process inside the sandbox is not obliged to go through it.
The boundary that does hold is the per-session socket directory of §3.2 —
a sandbox cannot reach a host session's socket at all.

## 5.  Mount Model

### 5.1.  Base mounts

| Mount point | Type | Purpose |
|-------------|------|---------|
| `/proc` | proc | Process information |
| `/dev` | dev-bind | Device nodes |
| `/tmp` | tmpfs | Ephemeral work area |
| `/sys` | ro-bind | System information (CPU topology, devicemodel) |
| `/nix` | ro-bind | Nix daemon socket access |
| `/nix/store` | ro-bind | Nix store (read-only packages) |
| `/etc` | ro-bind | System configuration |
| `/bin` | ro-bind | `/bin/sh` (fish_completions and tools resolve it) |
| `/usr/bin` | ro-bind | `/usr/bin/env` (shebangs like `#!/usr/bin/env` need it) |
| `/run/current-system` | ro-bind | Active NixOS system |
| `/run/wrappers` | ro-bind | setuid wrappers (rendered nosuid by bubblewrap) |
| `$XDG_RUNTIME_DIR/cage/<session>` → `$XDG_RUNTIME_DIR/zellij` | rw | this session's zellij socket only (host ↔ sandbox) |
| `$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` | bind-try | Wayland socket when set (clipboard, screenshots) |
| `$HOME` | tmpfs | Fresh, empty home inside the sandbox |
| `$HOME/.nix-profile` | ro-bind-try | home-manager programs (immutable store refs) |
| `$HOME/.config/opencode` | ro-bind | opencode config when present on the host |
| `$HOME/.local/share/opencode/auth.json` | ro-bind-try | opencode credentials |
| `$HOME/.cache/opencode` | bind-try | opencode plugin/model cache when present on the host (rw) |
| `$HOME/.pi` | bind | Pi config dir (auth.json, settings.json, models.json, sessions, tools) when present (rw) |
| `$HOME/.config/fish` | ro-bind | Fish shell config (aliases, prompt, key bindings, theme) when present (ro) |
| `$HOME/.local/share/fish` | bind | Fish shell history when present (rw) |
| cwd (PWD at launch) | rw | Working directory |

`--ro-bind-try` is used for optional sources, so a missing `~/.nix-profile` or
missing opencode auth file does not prevent the sandbox from starting.

The `$XDG_RUNTIME_DIR/cage/<session>` directory is created on the host before
the first use, so a fresh machine that has never run zellij can still start a
sandbox.  It is removed on teardown.

### 5.2.  Home directory

- `$HOME` MUST be a tmpfs.  The directory is initially empty.  The zellij
  server and tools may create subdirectories (`.cache`, `.config`, `.local`).
  The working directory is bound over the tmpfs at its exact path, so the
  agent can read and write the project files it was started in.
- The user's home-manager profile MUST additionally be bound read-only at
  `$HOME/.nix-profile` (its symlink resolves into the immutable
  `/nix/store`).  This exposes the user's installed programs (via
  `$HOME/.nix-profile/bin` on `PATH`) without exposing any writable HOME
  contents.
- The opencode configuration directory (`$HOME/.config/opencode`) MUST be
  bound read-only at its exact path when it exists on the host, so opencode
  started inside the sandbox picks up the usual config (opencode.jsonc,
  agents, commands, plugins).
- The opencode auth file (`$HOME/.local/share/opencode/auth.json`) MUST be
  bound read-only at its exact path when it exists, so sandboxed opencode can
  authenticate.  This grants the agent read access to the provider tokens.
  See §6.5.
- The opencode cache (`$HOME/.cache/opencode`) MUST be exposed at its exact
  path when it exists on the host.  It holds opencode's installed plugin
  packages and the resolved model list; without it opencode re-resolves
  `@latest` plugins from the npm registry on every fresh sandbox, adding
  several seconds of cold start (and hanging much longer offline).  It is
  bound read-write so sandboxed opencode can refresh its cache, which means a
  compromised agent could write to that host cache directory; it contains no
  credentials.
- The Pi config directory (`$HOME/.pi`) MUST be bound at its exact
  path when it exists on the host, so sandboxed `pi` inherits the host's
  providers, auth, settings and saved sessions and can persist sessions and
  tool state.  It is bound read-write, which means a compromised agent could
  write to that host directory; it holds the user's provider credentials, so
  consider `--nonet` if those must never leave the machine.
### 5.3.  Environment

The sandbox SHALL set the following environment variables:

- `HOME` — same value as the host's `HOME`
- `USER` — same value as the host's `USER`
- `SANDBOXED` — set to `cage` (a marker the user can check)
- `TMPDIR` — set to `/tmp`, the sandbox-local tmpfs; host dev-shell temp paths
  are not inherited because their parent directories do not exist inside the
  fresh tmpfs

The hostname inside the sandbox SHALL be set to `sandbox-<session>`.

## 6.  Security Considerations

### 6.1.  Process confinement is not malware containment

The sandbox uses an unprivileged user namespace.  It provides process, mount,
and optionally network isolation, but it does NOT provide a hard security
boundary.  A malicious process inside the sandbox that has access to shared
mounts (§6.4) or to the host's network can exploit those interfaces.

### 6.2.  Network is shared by default

The sandbox does NOT create a network namespace unless `--nonet` is given.
Processes inside the sandbox MAY use the host's network stack: they can
connect to the internet, listen on ports, and access local services.  This is
by design: the sandbox is intended for development tools and agents that need
network access.

With `--nonet`, the sandbox is fully offline: it cannot exfiltrate data, reach
the internet, or access local services.  Use `--nonet` for anything that does
not need outbound connectivity.

### 6.3.  No shared (home-exposing) mode exists

Historically the tool had a "shared" mode that bind-mounted the entire home
directory and the entire runtime directory read-write.  That mode has been
removed: it provided no data protection.  The sandbox now always uses a tmpfs
home.

### 6.4.  What the sandbox does NOT expose

The sandbox:

- MUST NOT expose the host's home directory (only a tmpfs).
- MUST NOT expose desktop sockets (ssh-agent, Wayland, D-Bus, PipeWire,
  gnupg, keyring).
- MUST expose the user's home-manager profile read-only at `$HOME/.nix-profile`
  so installed programs are usable; this exposes only immutable store symlinks,
  never writable HOME contents or secrets.
- MUST expose the opencode configuration directory read-only at
  `$HOME/.config/opencode` when it exists on the host, so sandboxed opencode
  starts with the user's usual config; this exposes only that config
  directory, never writable HOME contents or secrets.
- MUST expose the opencode cache at `$HOME/.cache/opencode` when it exists on
  the host, so sandboxed opencode does not re-resolve `@latest` plugins from
  the network on a fresh (empty HOME) sandbox; it is bound read-write so the
  cache can be refreshed, and contains no credentials.
- MUST expose the Pi config directory at `$HOME/.pi` when it exists
  on the host, so sandboxed `pi` starts with the user's usual providers,
  auth and settings and can persist sessions and tool state.  It is bound
  read-write (see §5.2).
- MUST expose the fish shell config at `$HOME/.config/fish` when it exists
  on the host, so shell aliases, prompt, key bindings and theme are available
  inside the sandbox.  It is bound read-only.
- MUST expose the fish shell history at `$HOME/.local/share/fish` when it
  exists on the host, so command history persists across sandbox sessions and
  is shared between host and sandbox.  It is bound read-write.
- MUST expose the working directory read-write (the user chose to
  expose it by launching from that directory).
- Additionally exposes `/etc`, `/nix/store` and `/run/current-system`
  read-only, which are system-wide configuration; do not place secrets readable
  by your own uid there if you need to keep them from the sandbox.

### 6.5.  Credential exposure

Binding `$HOME/.local/share/opencode/auth.json` read-only means the sandboxed
agent holds the same provider tokens it uses itself: it is literally reading
open code's own credentials.  With the default shared network an agent could
transmit those tokens anywhere.  This is an accepted trade-off for agent use;
use `--nonet` if the credentials must never leave the machine.

### 6.6.  Host-session protection

The tool enumerates zellij server processes by argv (`zellij --server
<path>`) and classifies each as sandboxed or host by walking its ancestor
chain for a `bwrap` process.  `stop` and `stop-all` only ever act on
sandboxed sessions, and `start`/`attach` refuse to attach to host sessions
that happen to share a requested name.  A host zellij session can never be
attached to or killed by cage.

### 6.7.  Network flag is a creation-time property

The `--net`/`--nonet` choice is fixed when the session is created.  Re-attaching
to an existing session reuses the same namespace; changing the network posture
requires ending the session and starting a new one.

### 6.8.  Mounts are fixed at session creation

The set of mounts is determined when the session is created.  Re-attaching to
an existing session uses the same mounts.

## 7.  Usage Scenarios

### 7.1.  Everyday development

```sh
# Inside the project directory
cage work
# Inside the session:
nix develop
cargo build
```

The sandbox keeps the project files and the Nix store accessible.  The host
zellij server is not required; the sandboxed zellij server IS the zellij
server.

### 7.2.  Running an agent (isolated mode)

```sh
cd ~/project
cage agent        # add --nonet for a fully offline sandbox
# Inside the session:
opencode
```

The agent sees an empty home directory and cannot touch the user's SSH keys,
gnupg, or desktop sockets.  It can read and write files in `~/project/`.
opencode inherits its credentials and usual config (read-only) and works
against the network for model calls; append `--nonet` if the project must
never make network requests.

### 7.3.  Second terminal

From another terminal, the user can attach to the same session while it is
alive:

```sh
cage work
```

The session ends when the creating (owning) client detaches; attaching to a
live session does not create a new namespace, and an additional client does
not extend the session's life beyond the owner's.

### 7.4.  Cleanup

```sh
cage list          # see which sessions are sandboxes vs host
cage stop work     # stop one sandboxed session
cage stop-all      # stop all sandboxed sessions (never host ones)
```

## 8.  Troubleshooting

### 8.1.  "refusing to attach: it is a host zellij session"

The requested name is already used by a host zellij session.  Pick a different
session name, or end the host session first.

### 8.2.  "the sandbox has an empty tmpfs HOME"

The sandbox cannot start with `$HOME` as the working directory.  `cd` into a
project directory first.

### 8.3.  htop shows one CPU

This is a cosmetic issue caused by the absence of `/sys` in older sandboxes.
Since the initial implementation, `/sys` is mounted read-only.  If htop still shows one
CPU, verify that the session was created with a version of cage that
includes the `--ro-bind /sys /sys` flag.

### 8.4.  No sessions listed by `list`

`cage list` enumerates live zellij *server processes* rather than calling
`zellij list-sessions`, because sandboxed sessions keep their sockets in
per-session directories that a host client does not scan.  If nothing is
shown, there are no live zellij servers anywhere (sandbox or host).

A bare `zellij list-sessions` on the host will not show sandboxed sessions,
for the same reason.  This is expected; use `cage list`.

## 9.  References

- [RFC2119]  Bradner, S., "Key words for use in RFCs to Indicate Requirement
  Levels", BCP 14, RFC 2119, DOI 10.17487/RFC2119, March 1997,
  <https://www.rfc-editor.org/info/rfc2119>.
- [RFC8174]  Leiba, B., "Ambiguity of Uppercase vs Lowercase in RFC 2119 Key
  Words", BCP 14, RFC 8174, DOI 10.17487/RFC8174, May 2017,
  <https://www.rfc-editor.org/info/rfc8174>.
- bubblewrap manual, <https://github.com/containers/bubblewrap>
- zellij documentation, <https://zellij.dev/documentation/>
- NixOS manual, <https://nixos.org/manual/nixos/stable/>
