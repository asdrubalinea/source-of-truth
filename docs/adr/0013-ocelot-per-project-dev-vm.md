# ocelot: a per-project dev VM beside the cage sandbox

Status: accepted and implemented (2026-09-06). Complements `docs/cage.md`;
supersedes nothing. The mechanism and the command reference are `docs/ocelot.md`;
this file stays the record of *why*.

Implementation notes, where reality was more specific than the decision:

- The unprivileged `virtiofsd --sandbox none` spike passed against a qemu with a
  shared memfd backend, so the most-reversible decision below — option (c),
  falling back to microvm.nix — was not taken.
- The credential dirs are staged into **one** virtiofs share, composed by
  `bwrap` in a mount namespace. virtiofsd serves exactly one directory, the
  seven credential paths are scattered under `$HOME`, and one of them
  (`~/.claude.json`) is a file — so the alternative was seven virtiofsd
  processes and still no way to carry the file.
- The guest reads its identity from `/host/conf/*`, not from the kernel command
  line, which cannot carry a path containing a space without quoting games.
- The guest is a **transient** unit (`systemd-run --user`), not a unit file: the
  per-ocelot parameters then need no encoding in a unit name.
- The ssh host key is copied into `/etc/ssh` at boot rather than used in place,
  because sshd is strict about a host key's owner and nothing on an
  unprivileged virtiofs share can be root-owned.
- passt is given `--mtu 1500`. Its 65520 default is advertised over DHCP,
  declined on the 1500-byte virtio-net link and still installed on the routes.

## Context

`cage` (`scripts/cage.sh`, `docs/cage.md`) confines a process tree with
bubblewrap: fresh tmpfs `$HOME`, only the launch directory writable, agent
credential dirs bound in, session dies on detach. It is the right tool for
"run this agent without letting it wander", and its own §6.1 is explicit that
it is not malware containment.

It cannot do containers, and not by oversight. cage never binds the docker
socket, and it must not: a docker socket is host root, so a container started
through it is not confined by the sandbox at all — it lands as a root process
on tempest. Managing containers therefore means leaving the sandbox, which
puts the messiest thing back on the host.

What is wanted is a **blast radius** boundary — see `CONTEXT.md`, *Isolation
(tempest)* — for mess rather than malice: a container runtime that is genuinely
the project's own, a machine that can be wrecked and reset, and a place where
a toolchain that wants to own its host can have one. Explicitly *not* a
hardened boundary against hostile code; the same agent credentials cage carries
in are carried in here, for the same reason.

Constraints from this tree that shaped the answer:

- `libvirtd` and `virt-manager` are both `enable = false` on tempest
  (`hosts/tempest/system/virtualization.nix`). There is no VM management stack
  to plug into and no wish for one.
- The root filesystem is tmpfs and `/home/irene` lives on `rpool/persist/home`,
  which sanoid snapshots hourly and syncoid replicates to the USB pool
  (`docs/adr/0002`). A docker layer cache anywhere in the home would be pinned
  in every snapshot and shipped to the backup drive — exactly what
  `disks/tempest.nix` already avoids for `/var/lib/docker` and
  `/var/lib/containers`.
- `programs.nh.clean` GCs weekly across all profiles.
- `pkgs.passt` is already a dependency (`scripts/cage.nix`, for cage's
  `--isolate-net`), and `scripts/port-forward.nix` already encodes the
  `ssh -L <port>:localhost:<port>` convention against a host name.
- `./build-vm` already produces VMs — **host clones** — which are a different
  thing entirely. "The VM" is now ambiguous in this repo.

## Decision

**An ocelot is a per-project QEMU guest, entered over ssh, holding its own
container runtime.** One species, many individuals; each is named for its
project directory. `scripts/ocelot.sh` is the launcher, sitting beside
`cage.sh` as its sibling.

Shape, in the order the decisions depend on each other:

- **You work inside it**, over ssh, attached to a zellij session — the same
  idiom as cage, so a dropped connection does not kill a build. Rejected the
  alternative of staying outside with only the daemon in the guest (see below).
- **One ocelot per project directory**, keyed by sanitized basename as cage
  keys its sessions, with the full path recorded so a second directory of the
  same name is refused loudly rather than silently handed the wrong machine.
  Several run at once.
- **It outlives the ssh session.** This inverts cage, deliberately: cage's
  client is PID 1 of its namespaces and the session ends on detach, whereas
  the whole point here is that the containers you left running are still
  running. It runs as a **systemd user unit**, which supplies stop, status,
  journal and survival-across-terminal-death for free.
- **Ephemeral root, explicit persist list.** The root is rebuilt from the Nix
  image on every boot; a state disk holds `/var/lib/docker`, the guest home,
  the ssh host key, `/etc/machine-id` and `/var/lib/nixos`. This is the house
  idiom (`modules/impermanence-root.nix`), but the real argument is that
  **ephemeral root is the update mechanism**: the launcher builds from the
  current tree on every start, so a change to the shared package set reaches
  every ocelot at its next boot, with no per-guest rebuild to remember. A
  persistent root would be a second machine to maintain.
- **Guest-own home** on the state disk, not the host's home bound in. A shared
  home would put a door in the most valuable wall, and would mean per-project
  ocelots sharing the one directory that accumulates state.
- **The host `/nix/store` is shared read-only**, with a writable overlay for
  the guest's own builds so `nix develop` works inside. **The overlay's upper
  and the Nix database both live on the state disk**, so they survive a `stop`
  together. microvm.nix's documentation records what happens when only one of
  them does (*"The Nix database will forget all built packages after a
  reboot"*): orphans that neither nix nor GC can reason about. Keeping the pair
  together is what makes persisting either of them safe.

  *Corrected 2026-09-06.* This originally read "the overlay is scratch, wiped
  at every guest boot … costs little, because the paths a devShell needs are
  mostly in the host store already". Both halves were wrong. The wipe was a
  tmpfs sized at half the guest's RAM, and a devenv shell exhausted it —
  `write of 65536 bytes: No space left on device` — with the 63G state disk
  untouched. And host-store presence buys nothing on its own: the guest's DB
  knows ~4,000 paths against tempest's ~79,000, so a shared path that is not
  *registered* is re-fetched regardless. The wipe was therefore not paying for
  agreement between store and DB; it was paying for a re-download on every
  single boot.
- **The base package set comes from the image; per-project tooling comes from
  the project's own `flake.nix`.** `desktop/cli-packages.nix` holds the set
  shared with tempest, and `desktop/home-packages.nix` is redefined as that set
  plus the desktop-only additions — an additive extraction, so tempest and
  orchid see no change. Adding a package lands in the shared set by default and
  reaches both places; making something desktop-only is the deliberate act.
- **Network is passt**, already in the tree. The guest is unreachable except
  through forwarded ports.
- **Addressing is an ssh config stanza per ocelot** (`~/.ssh/config.d/`,
  included via home-manager): host name, allocated port, per-ocelot
  `known_hosts`, `ForwardAgent yes`. The host key is generated on tempest at
  creation and seeded into `known_hosts` at the same moment, so there is never
  a TOFU prompt or a changed-key warning. The stanza is what makes everything
  that speaks ssh work by name — including `port-forward <name> 3000`,
  unmodified.
- **`stop` and `destroy` are different verbs.** stop ends the machine and keeps
  its state; destroy deletes the state. destroy is what makes the blast-radius
  claim real.
- **Filed on the tree's existing axes**: `hosts/ocelot/`, `homes/ocelot.nix`,
  `scripts/ocelot.{nix,sh}`, `desktop/cli-packages.nix`. An ocelot is treated
  as a host, because it is one.
- **State lives on a new `rpool/vms` dataset** mounted at `/var/lib/vms` with
  `com.sun:auto-snapshot=false`, and a tmpfiles rule handing irene a subdir —
  the shape `/var/lib/containers/rootless/irene` already has.
- Guest defaults: 8 GiB, 4 cores, docker (not podman — rootless buys nothing
  inside a guest that is itself the boundary), plain nixpkgs kernel, state disk
  a sparse raw image.

## Considered options

**microvm.nix.** The obvious answer, and better engineering in the abstract:
virtiofs is first-class, boots are ~1s, `writableStoreOverlay` and `volumes`
are supported options. Rejected because its unit of organisation is *a named VM
declared on a host*, materialised in a root-owned registry at
`/var/lib/microvms/<name>` with virtiofsd started by a systemd service from
`microvm.nixosModules.host`. Ours is *a directory*. Bending it to per-project
ad-hoc use means either regenerating host config per project or scripting
against that registry with root — at which point the input has been paid for
and the launcher is still unwritten. Revisit if the hand-rolled virtiofsd
plumbing turns out to be a maintenance burden; this is the decision most likely
to be reversed.

**Plain `qemu-vm.nix` shares.** `virtualisation.sharedDirectories` is **9P
only** — there is no virtiofs option. That was survivable when only the project
directory crossed, and stopped being survivable once the host store was shared:
the store is then the guest's execution path, and every binary it runs is read
across the share. Hence virtiofsd by hand, which `hosts/tempest/vm.nix` already
half-demonstrates with its `memory-backend-memfd` options for virgl.

**Stay outside; only the daemon in the guest.** Point the host `docker` CLI at
a guest daemon via `DOCKER_HOST`, with the project mounted at its exact host
path. Roughly a fifth of the work, and it addresses the literal complaint.
Rejected because it creates two filesystems that must agree: every relative
volume path, build context and bind mount is resolved by the CLI on the host
and interpreted by the daemon in the guest. When paths match it is invisible;
when they do not, the symptom is a silently empty directory inside a container.
That is a shared illusion, not a boundary.

**One long-lived workshop VM.** Much lazier — one warm layer cache instead of
N cold ones. Rejected because one docker daemon means `docker ps` shows every
project's containers again, which is the entanglement being escaped.

**A persistent-root pet VM.** Gives "everything survives" for free, which is
what was asked for. Rejected in favour of ephemeral root plus an explicit
persist list, because the persist list gives the same convenience while keeping
the base system tracking the flake and keeping "what survives" readable in one
file.

## Consequences

- **A running ocelot must hold a gcroot for its own toplevel.** It is not in
  tempest's system closure, and `programs.nh.clean` runs weekly; without a
  gcroot, `nh clean all` can delete store paths out from under a live guest.
  A `nix build` result symlink is one — the launcher keeps it.
- **One built image serves every ocelot.** Nothing about the guest system
  varies per project; path, state disk and ssh port are runtime parameters.
  Adding a package rebuilds one thing and every ocelot picks it up on next
  boot — and no ocelot can have a package another lacks. Per-project difference
  is the project's `flake.nix`, by design.
- **Credentials cross the boundary.** `~/.claude`, `~/.claude.json`,
  `~/.agents`, `~/.codex`, `~/.pi`, `~/.hermes`, `~/.cache`,
  `~/.config/opencode` and `~/.local/share/opencode/auth.json` are bound
  read-write, as in cage and for the same reason. Anything running in an ocelot
  can read them. `~/.ssh` is *not* bound; `git push` works through
  `ForwardAgent`, so the private key never crosses.
- **Everything else the guest needs, it is configured with, not handed.** cage
  binds tempest's generated `~/.config/{zellij,fish,helix}` because it is the
  same machine; an ocelot builds its own from the same modules plus the ember
  palette (`homes/ocelot.nix`). Config crosses the boundary only when it is a
  credential.
- **Neither 9p nor virtiofs propagates inotify from host-side edits.** Editing
  inside the guest is fine. A host editor driving a watcher inside an ocelot
  will silently never fire.
- **Unprivileged virtiofsd means `--sandbox none` and no uid mapping.**
  Everything in the share is irene on both sides. True today; a constraint the
  design states rather than discovers.
- **`rpool/vms` must be created by hand once.** disko only runs at format time,
  so the entry in `disks/tempest.nix` documents the layout for the next install
  but does not create the dataset on the live machine.
- **`nix develop` inside fetches once per ocelot**, even for paths tempest
  already holds, because the guest's Nix DB knows only the guest's own closure.
  Accepted; the alternative is registering the host's whole database into the
  guest at boot, which is a store that lies about what it contains — those
  paths are not gcrooted from inside the guest, so the weekly `nh clean all`
  would invalidate them under it.
