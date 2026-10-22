# ocelot — per-project QEMU dev VM for NixOS

## Abstract

This document specifies the ocelot tool: a per-project virtual machine, entered
over ssh, that holds its own container runtime and outlives the connection to
it. It is the counterpart to `docs/cage.md` — cage confines a process tree on
tempest's own kernel; an ocelot is a different machine.

Why it is shaped this way is `docs/adr/0013-ocelot-per-project-dev-vm.md`. What
the words mean is `CONTEXT.md`, *Isolation (tempest)*. This document is the
mechanism and the reference.

The key words "MUST", "MUST NOT", "REQUIRED", "SHOULD", "SHOULD NOT",
"RECOMMENDED", "MAY" and "OPTIONAL" are to be interpreted as in BCP 14
[RFC2119] [RFC8174].

## 1.  Introduction

An **ocelot** is a QEMU guest belonging to one host directory — **the project**.
Each individual is named for that directory. You enter it over ssh, attached to
a zellij session, and work inside it; the project is mounted at the same
absolute path it has on tempest, so a path copied between the two means the same
file.

It exists because cage cannot manage containers and must not: cage never binds
the docker socket, and a docker socket is host root, so a container started
through it would land as a root process on tempest, confined by nothing. An
ocelot runs its own docker daemon, so the containers started in it are *its*
containers and appear in no listing on the host.

What it bounds is **mess**: a runaway build, a container that fills the disk, a
daemon that rewrites its own `/etc`, a toolchain that wants to own the machine.
It does **not** bound malice — see §7.

Three properties follow from the design and are worth stating up front:

- **It outlives the ssh session.** This inverts cage deliberately. cage's client
  is PID 1 of its namespaces and the session ends on detach; here the whole
  point is that the containers you left running are still running.
- **Its root filesystem is rebuilt on every boot** from the current tree, and an
  explicit list of paths is bound out of a state disk. Ephemeral root is the
  update mechanism, not an austerity measure: a change to
  `desktop/cli-packages.nix` reaches every ocelot at its next boot.
- **`stop` and `destroy` are different verbs.** stop ends the machine and keeps
  everything it accumulated. destroy deletes that accumulation.

## 2.  Definitions

- **ocelot** — the species, one individual per project, and also the command.
- **the project** — the single host directory an ocelot is of.
- **state disk** — the sparse raw ext4 image holding what survives a `stop`.
- **the staging directory** — a directory the launcher composes on tempest with
  bubblewrap and serves to the guest over virtiofs; it carries the project, the
  agent credentials and this ocelot's identity. Mounted at `/host` inside.
- **host clone** — `tempest-vm` / `orchid-vm`, built by `./build-vm`. A
  different thing entirely; see `CONTEXT.md`.

## 3.  Architecture

### 3.1.  Processes

Everything runs unprivileged, as `irene`. There is no libvirtd, no VM registry
and no root helper; `libvirtd` and `virt-manager` are `enable = false` on
tempest and stay that way.

One transient systemd **user** unit per running ocelot, `ocelot-<name>.service`,
created with `systemd-run --user`. That is where `stop`, `status`, the journal
and survival-across-terminal-death come from, at the cost of no unit file to
maintain. Inside its cgroup:

```
ocelot-<name>.service
├── qemu-system-x86_64            (the unit's main process)
├── virtiofsd  → /nix/store       --readonly --cache always
├── bwrap → virtiofsd → staging   the project + credentials + identity
└── passt                         one forwarded port, bound on 127.0.0.1
```

`KillMode=mixed`: SIGTERM reaches only qemu, so it can exit on its own, and
systemd reaps the three helpers afterwards. No helper can be orphaned.

### 3.2.  The three things that cross

All three are virtiofs. `virtualisation.sharedDirectories` in nixpkgs'
`qemu-vm.nix` is 9P only, and 9P was not survivable once the host store started
crossing: the store is the guest's execution path, so every binary it runs is
read across that share. Hence virtiofsd by hand.

| Guest path | Tag | Source | Mode |
|---|---|---|---|
| `/nix/.ro-store` | `nix-store` | host `/nix/store` | read-only |
| `/host` | `ocelot-host` | the staging directory | read-write |
| the project's own path | — | bind of `/host/project` | read-write |

`/nix/store` is an overlay: `/nix/.ro-store` as lowerdir, and an upperdir **on
the state disk**, at `/state/nix-store/upper`. `/nix/var/nix` is on the state
disk too, so the store's writable layer and the Nix database that describes it
persist together — which is the condition under which persisting it is safe at
all. microvm.nix documents the failure when it is not: *"The Nix database will
forget all built packages after a reboot"*, leaving orphans that neither nix nor
GC can reason about. Guest builds work from the first boot because the closure
of the guest's own toplevel is registered in its Nix DB from `regInfo` on the
kernel command line, by a service ordered after `local-fs.target` — i.e. after
the persisted DB is mounted, not under it.

This upperdir was a tmpfs until 2026-09-06, on the argument that wiping it each
boot was what kept store and DB in agreement. Two things were wrong with that.
The tmpfs is sized at half of RAM, 3.9G here, which a real devshell does not fit
in — a devenv `direnv allow` filled it and died with `write of 65536 bytes: No
space left on device` while the 63G state disk sat at 0.6M used. And the cost
was never "re-fetch on a cold store"; it was re-fetch *on every boot*, because
the wipe took the DB's knowledge of the upper with it.

What did not change is that the guest's DB knows only the guest's own closure —
some 4,000 paths against tempest's ~79,000 — so the host store being physically
present under `/nix/.ro-store` does **not** make its contents valid to the guest.
The first `direnv allow` in a fresh ocelot still fetches what tempest already
has. Registering the host's whole database into the guest at boot
(`nix-store --dump-db | nix-store --load-db`, 54M, ~80s) does fix that and is
deliberately not done: it would leave the guest depending on host paths that
nothing gcroots, so tempest's weekly `nh clean all` would quietly invalidate
them. Fetch once per ocelot is the accepted price of not lying about the store.

vhost-user requires the guest's RAM to be mappable by another process, which a
plain `-m` allocation is not, so the guest is given a
`memory-backend-memfd,share=on` of exactly `virtualisation.memorySize`. QEMU
refuses to start if the two disagree. `hosts/tempest/vm.nix` already does the
same thing for virgl.

### 3.3.  Why bubblewrap is in the picture

virtiofsd serves exactly one directory. The agent credentials are nine scattered
paths under `$HOME` — two of them (`~/.claude.json`,
`~/.local/share/opencode/auth.json`) *files*, two of them nested rather than
top-level — so they cannot be one share, and sharing `$HOME` itself would carry
`~/.ssh` across, which is precisely what must not happen.

So the launcher creates a staging skeleton in `$XDG_RUNTIME_DIR` and starts
virtiofsd inside a bubblewrap mount namespace that binds each credential path
into it. bubblewrap is used here **only to compose mounts** — `--dev-bind / /`
keeps the host visible, because virtiofsd needs `/nix/store` to run at all. It
is not a boundary in this direction and is not pretending to be one. The
namespace dies with the process, so nothing is left mounted.

### 3.4.  Boot sequence

1. Initrd mounts `/state` (ext4, by label `ocelot-state`), `/nix/.ro-store`
   (virtiofs) and the `/nix/store` overlay whose upper lives on the first. All
   three are `neededForBoot`; the overlayfs module creates the upperdir and
   workdir and orders the overlay after `/state` on its own.
2. impermanence binds `/nix/var/nix`, `/var/lib/docker`, `/home/irene`,
   `/var/lib/nixos` and `/etc/machine-id` out of `/state`.
3. `ocelot-runtime.service` reads `/host/conf` and, before sshd and docker:
   sets the kernel hostname to `ocelot-<name>`; installs the ssh host key into
   `/etc/ssh`; bind-mounts `/host/project` onto the project's real path; and
   bind-mounts every entry of `/host/creds` into the guest home at its usual
   name.
4. sshd starts on the host key that tempest generated at creation time, so
   `known_hosts` already matches.

Bind mounts, not symlinks, for the credentials: a tool that writes its config by
`rename(2)` would replace a symlink and silently stop writing through.

The guest keeps no `/var/log`. Its journal is forwarded to the console at
warning level and above, and the console is the launcher's journal on tempest —
which outlives the guest, and is therefore the only place a failed boot is
readable. `ocelot logs <name>`.

### 3.5.  Network

passt, with exactly one inbound port: `127.0.0.1/<port>:22`. The guest is
unreachable except through forwarded ports. Outbound works; DHCP, DNS and
routing all come from passt.

passt is started with `--mtu 1500`. Its default is 65520, which it advertises
over DHCP; virtio-net's link MTU is 1500, so dhcpcd declines it on the link and
still installs it on the *routes* — a route MTU above the link MTU, and TCP
computing an MSS for frames the link cannot carry. Raising the link instead
(`host_mtu=65520` on the virtio-net device) is the upstream-recommended
alternative if throughput ever becomes the complaint.

### 3.6.  Addressing

One ssh config stanza per ocelot, in `~/.ssh/config.d/ocelot-<name>`, included
from `~/.ssh/config` by `programs.ssh.includes` (`homes/tempest/default.nix`).
It carries the host name, the allocated port, a per-ocelot `UserKnownHostsFile`
and `ForwardAgent yes`.

The stanza is what makes everything that speaks ssh work by name — including
`port-forward ocelot-<name> 3000`, unmodified. The host key is generated on
tempest at creation and seeded into that `known_hosts` in the same moment, so
there is never a TOFU prompt and never a changed-key warning; `destroy` removes
both halves together, so a rebuilt ocelot cannot inherit a stale one.

The port is allocated once, derived from the name, probed against both live
listeners and the ports other ocelots have claimed, and then recorded — because
the stanza and the `known_hosts` entry both name it.

### 3.7.  Why the guest is configured and not furnished

cage and an ocelot answer "why does my shell look right in here" differently,
and the difference is not a detail.

cage runs on tempest, so it can bind tempest's own already-generated
`~/.config/{zellij,fish,helix,git}` read-only into the sandbox. The theme comes
along because it is the same machine's `$HOME`.

An ocelot is a different machine, and nothing of tempest's `$HOME` crosses
except the credential list in §7.2. So the guest home is *built*:
`homes/ocelot.nix` imports the same modules tempest does —
`desktop/{cli-packages,helix,tmux,zellij}.nix` and `misc/fish.nix` — plus the
stylix HM module pointed at `rices/ember/ember-3400k-dark.yaml`, with
`autoEnable = false` and five targets on by name (zellij, fish, helix, tmux,
starship). The rice itself is not imported: it is compositors, Qt, GTK, cursors
and a wallpaper, and none of that has a display to land on here. Only the
palette is shared, that being the one thing a terminal and a desktop have in
common.

Two consequences worth stating. A palette change reaches every ocelot at its
next boot, with nothing to re-bind. And no `home.packages` entry costs a
headless guest a font: `stylix.targets.fontconfig` is what installs those, and
it is off.

**MUST NOT** bind a host config directory in to get this effect. Beyond
duplicating what the guest already generates, the entry would have to be
`~/.config/<tool>` — and the first one that is written as `~/.config` instead
mounts the staging skeleton over the guest's whole config tree.

## 4.  Command reference

```
ocelot                    start (if needed) and enter the ocelot of $PWD
ocelot <name>             same, for a named ocelot
ocelot start [name]       start without entering
ocelot enter [name]       enter, starting first if it is not running
ocelot stop [name]        shut the machine down; its state survives
ocelot destroy [name]     delete its state; the next start is a fresh machine
ocelot list               every ocelot, running or not
ocelot status [name]      systemctl --user status for the guest's unit
ocelot logs [name] [-f]   the guest's console and forwarded journal
ocelot ssh [name] [cmd…]  run a command inside, or open a plain shell
```

With no name, the name is the sanitized basename of `$PWD`, as cage names its
sessions. `-y` skips the `destroy` confirmation.

Notes:

- **`start` on a running ocelot is a no-op**, and does not rebuild.
- **`start` rebuilds the guest** from `$OCELOT_FLAKE` on every start, and keeps
  the `nix build` result symlink. That symlink is load-bearing twice: it is what
  the unit executes, and it is the **gcroot**. A running ocelot is not in
  tempest's system closure and `programs.nh.clean` runs weekly, so without it
  `nh clean all` could delete store paths out from under a live guest.
- **`enter`** attaches to a zellij session named after the ocelot, so a dropped
  connection does not kill a build. It requires a terminal; use `ocelot ssh
  <name> <cmd>` for one command.
- **`stop`** asks the guest to power down over the qemu monitor
  (`system_powerdown`) and waits up to 120s before stopping the unit, so a live
  ext4 and a live docker are not pulled out from under themselves. A clean stop
  takes about three seconds.
- **Two directories with the same basename are refused loudly.** The project's
  full path is recorded at creation; a second directory of the same name is told
  to pick a name rather than silently handed the wrong machine.
- **`$HOME` is refused as a project.**
- Interactive shells inside land in the project. Non-interactive
  `ocelot ssh <name> <cmd>` runs in the guest home, untouched.

### 4.1.  Environment overrides

| Variable | Default | Meaning |
|---|---|---|
| `OCELOT_ROOT` | `/var/lib/vms/irene` | where state disks live |
| `OCELOT_FLAKE` | `/persist/source-of-truth` | the tree the guest is built from |
| `OCELOT_STATE_SIZE` | `64G` | state disk ceiling (sparse) |

## 5.  State model

Host side, `$OCELOT_ROOT/<name>/`:

```
project                     the project's absolute path (the registry)
port                        the allocated ssh port
ssh_host_ed25519_key{,.pub} the guest's host key
known_hosts                 seeded with the above, named by the stanza
state.img                   sparse raw ext4, label ocelot-state
system                      nix build out-link — the runner AND the gcroot
```

`$OCELOT_ROOT` is `rpool/vms` on tempest (`disks/tempest.nix`), with
`com.sun:auto-snapshot=false` and a tmpfiles rule handing irene a subdirectory
(`hosts/tempest/system/virtualization.nix`) — the shape
`/var/lib/containers/rootless/irene` already has, and off `/persist` for the
same reason docker's dataset is: a layer cache must not be pinned in every
hourly sanoid snapshot and shipped to the backup drive.

Guest side, what survives a `stop` (`hosts/ocelot/system/persistence.nix`):

- `/nix/store`'s writable upper, at `/state/nix-store/` — not an impermanence
  bind but the overlay's own upperdir (§3.2). This is what a devshell lands in.
- `/nix/var/nix` — the Nix database, profiles and gcroots. Persisted *with* the
  upper and for its sake: a store layer whose DB was wiped is a store that
  re-downloads what it is already holding.
- `/var/lib/docker` — the layer cache, the one thing whose loss is expensive.
- `/home/irene` — the guest's own home. Not the host's home bound in: that would
  put a door in the most valuable wall, and would mean per-project ocelots
  sharing the one directory that accumulates state.
- `/var/lib/nixos`, `/etc/machine-id`.

Deliberately not persisted: the ssh host key (installed from `/host` at every
boot, so tempest can seed `known_hosts` without ever mounting the image) and
`/var/log` (see §3.4).

## 6.  First-time setup

`ocelot` is unprivileged, but two things have to exist first, and both need a
rebuild the user runs:

1. **The dataset.** disko only runs at format time, so `rpool/vms` in
   `disks/tempest.nix` documents the layout for the next install and does not
   create it on a live machine:

   ```
   sudo zfs create -o mountpoint=/var/lib/vms rpool/vms
   ```

   The `irene` subdirectory then comes from the tmpfiles rule at the next
   `nh os switch`. `ocelot` says exactly this if the directory is missing.

2. **The ssh include.** `programs.ssh.includes` in `homes/tempest/default.nix`
   needs one `nh home switch -b backup`. `ocelot` checks with `ssh -G` at
   creation time and says so, rather than leaving a two-minute timeout as the
   only symptom.

## 7.  Security considerations

### 7.1.  It bounds mess, not malice

An ocelot is isolated from tempest's *state*, not from your *secrets*. It has
its own kernel, so what runs in it cannot touch tempest's system state, and it
has its own container runtime, so its containers are invisible on the host.
That is the whole claim.

Protection from hostile code is a different request and would mean a different
set of things crossing the boundary.

### 7.2.  Credentials cross on purpose

`~/.claude`, `~/.claude.json`, `~/.agents`, `~/.codex`, `~/.pi`, `~/.hermes`,
`~/.cache`, `~/.config/opencode` and `~/.local/share/opencode/auth.json` are
bound in read-write, as in cage and for the same reason: the tools you use
should already be logged in. Anything running in an ocelot can read them.

The list is `OCELOT_CREDS` in `scripts/ocelot.sh` and is staged *and* handed to
the guest from there (`/host/conf/creds`); the guest binds exactly what that
file names. It does not enumerate the share, because a nested entry would then
be bound at its top-level parent — `~/.config` over the whole of it, burying the
generated zellij, fish and helix configs of §3.7.

`~/.ssh` is **not** bound. `git push` works through `ForwardAgent`, so the
private key never crosses — but note that agent forwarding lets anything in the
guest ask the host agent to sign while you are connected.

### 7.3.  Unprivileged virtiofsd does no uid mapping

virtiofsd runs as irene with `--sandbox none`, so everything in a share is irene
on both sides. This is stated by the design rather than discovered by it. It is
also why the ssh host key is *copied* into `/etc/ssh` at boot instead of being
used in place: sshd is strict about a host key's mode and owner, and nothing on
a virtiofs share can be root-owned.

### 7.4.  passt forwards exactly what it was told to

One port, bound on 127.0.0.1. `networking.firewall` is disabled inside the guest
on purpose: a second filter there would only make `port-forward` lie about what
is reachable.

## 8.  Known limitations

- **inotify does not cross.** Neither 9p nor virtiofs propagates inotify from
  host-side edits. Editing inside the guest is fine. A host editor driving a
  watcher inside an ocelot will silently never fire.
- **`nix develop` fetches once per ocelot**, even for paths tempest already has,
  because the guest's Nix DB knows only the guest's own closure — the shared
  store is bytes on disk, not registered paths (§3.2). It does not re-fetch on
  the next boot: the upper and the DB both persist.
- **One built image serves every ocelot.** Nothing about the guest system varies
  per project, so no ocelot can have a package another lacks; per-project
  difference is the project's own `flake.nix`, by design. Adding a package to
  `desktop/cli-packages.nix` reaches all of them at their next boot.
- **IPv6 is link-local only** when tempest itself has no global IPv6 address;
  dhcpcd logs two warnings about the router advertisement per boot and IPv4
  works normally.

## 9.  References

- `docs/adr/0013-ocelot-per-project-dev-vm.md` — the decisions, and five
  rejected alternatives.
- `CONTEXT.md`, *Isolation (tempest)* — the vocabulary, including why "the VM"
  is ambiguous in this repo.
- `docs/cage.md` — the sandbox, and where its boundary actually is.
- `scripts/ocelot.sh`, `hosts/ocelot/`, `homes/ocelot.nix`.
