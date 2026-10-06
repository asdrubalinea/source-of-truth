# Helium profile sync (tempest ↔ orchid)

Helium has no account sync (it is ungoogled Chromium), so the whole profile
directory, `~/.config/net.imput.helium`, is a syncthing folder shared between
tempest and orchid. History, open tabs, cookies, the three profiles, extensions
and their state all roam. The caches don't (see the ignore list in
`services/syncthing.nix`).

**The one rule: never have Helium open on both hosts at once.** The profile is
a pile of SQLite databases; two writers through a file sync corrupt them. The
guard in `packages/helium.nix` can't see the other machine's windows, only its
syncthing state. Close on one, open on the other.

## Pieces

- `services/syncthing.nix` — syncthing on both hosts, fully declarative
  (GUI-made devices and folders are reverted on activation). The `helium`
  folder, its peers, the ignore patterns, and simple versioning (last 3
  replaced versions of each file kept in `.stversions`, for recovering a
  database that synced half-written). Sync and discovery ports are open on
  `tailscale0` only.
- `packages/helium.nix` + `packages/helium-guard.sh` — `pkgs.helium`, used by
  `home.packages`, both compositors' `Mod+Shift+B`, and the `.desktop` entry.
  Two things over the plain package:
  - `--password-store=basic`. Chromium encrypts cookies with a key from the
    login keyring, which is random per machine; synced cookies would be
    unreadable on the other host and every site logged out on each switch.
    The basic store derives a fixed key. The disk is LUKS, so what's lost is
    only obfuscation at rest. One-off cost: the first start after switching
    drops the existing cookies (they were keyring-encrypted), so sites log out
    once.
  - The guard. Before starting: if syncthing is up and the folder isn't idle
    or still needs items from the peer, wait (a notification says so; two
    minutes max, then a critical notification and start anyway). If a peer
    connected in the last ten seconds, wait for the index exchange first.
    After quitting: trigger a scan and wait until every connected peer has
    100% of the folder, then notify "handed off" (five minutes max), so it's
    known when the laptop can be closed. A second invocation while Helium is
    already running (a URL from another app) skips all of this, as Chromium
    just forwards it to the live instance.

## First-time pairing

Device IDs come from the TLS certificate syncthing generates on first start,
so a fresh host has none until syncthing has run once.

1. `apply` on both hosts. Each starts syncthing with the folder declared but
   no peers.
2. On each host: `syncthing --device-id --home=/persist/syncthing-config`.
3. Put both IDs into `deviceIds` at the top of `services/syncthing.nix`,
   commit, `apply` on both. They pair themselves; no Accept in the GUI.
4. The first sync must be one-directional: the receiving host's folder must
   be empty, otherwise two full profiles merge into one unusable pile of
   `.sync-conflict` files. On the host whose profile is to be discarded,
   with Helium closed, **before step 1's `apply`** (so syncthing never
   indexes the old files):

       rm -rf ~/.config/net.imput.helium ~/.cache/net.imput.helium

   Syncthing creates the empty folder itself. If syncthing already ran with
   the old profile in place, stop it first (`systemctl stop syncthing`),
   delete the profile and its index (`/persist/syncthing-config/index-v2.db`)
   and start it again, otherwise the old files sit in tempest's index as
   deletions and come back as conflicts.
5. Open Helium on the surviving host once (cookies drop, see above), close
   it, wait for the "handed off" notification, then open it on the other.

The GUI, if ever needed, is loopback only: `ssh -L 8384:127.0.0.1:8384 <host>`
then <http://127.0.0.1:8384>. Device IDs are public; the API key in
`/persist/syncthing-config/config.xml` is not.

## When it goes wrong

- *"Profile still syncing after 2 minutes"* — the peer is connected and still
  sending. Either wait and relaunch, or accept that the other host had newer
  state and carry on; the newer files land underneath the running browser,
  which is exactly the thing the guard tries to avoid. Prefer waiting.
- A database arrives corrupt (Helium opens with blank history, or a profile
  refuses to load): the previous three versions of every replaced file are in
  `~/.config/net.imput.helium/.stversions/`, named with a timestamp. Close
  Helium on both hosts, copy the last good one back over, let it sync.
- `.sync-conflict-*` files in the profile mean both sides changed the same
  file between syncs, i.e. the rule above was broken. Keep whichever side's
  session was the real one and delete the other copy; Chromium ignores the
  conflict files themselves.
