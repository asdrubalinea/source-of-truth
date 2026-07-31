# tempest media automation design

## Goal

Provide one person with a pleasant way to discover and request a movie, then
leave an ordinary file ready to open locally with mpv. This is not a streaming
service and does not need a second UI for browsing or managing the finished
library.

The first version is intentionally small:

```text
Seerr -> Radarr -> manual lawful intake -> /data/media/movies -> mpv
```

Seerr is the normal front door. Radarr is background plumbing and is opened
only for setup, troubleshooting, or manual import. See
[`CONTEXT.md`](../CONTEXT.md) for the canonical meanings of media request,
media library, playback client, and opportunistic media service.

## Scope

- One user: irene.
- Movies only. Sonarr is deferred until episodic series are actually wanted.
- tempest is the host.
- Availability follows tempest's awake time. Sleep and shutdown are normal
  unavailability.
- mpv opens files directly from the filesystem.
- The library contains only replaceable content. Personal media stays under
  `/home/irene` and keeps the existing backup protections.
- Maximum library footprint: 400 GiB.

## Components

### Included

- **Seerr** provides discovery and creates movie requests.
- **Radarr** receives those requests, owns movie naming and organization, and
  provides manual import.
- **mpv** is the playback client. It is not managed by the container stack.
- **Docker Compose** owns the application containers. NixOS owns storage,
  persistence, service startup, users/groups, and network exposure.

### Excluded

- Jellyfin, Plex, and Emby: no streaming server or server-side watch state is
  wanted.
- Sonarr: no series in the first version.
- Prowlarr, qBittorrent, and SABnzbd: there is currently no lawful indexer,
  torrent feed, or Usenet provider to drive them.
- Recyclarr/Profilarr: premature for a small, manually supplied library.
- Bazarr, autobrr, Cleanuparr, and transcoding workers: no demonstrated need.

These exclusions are not placeholders that should be deployed disabled. Add a
component only when its use case exists.

## Storage

Create a dedicated ZFS dataset, `rpool/media`, mounted at `/data`, with a
`400G` quota. It must remain outside `rpool/persist` and
`rpool/persist/home` so replaceable media does not enter sanoid's snapshot
retention or the external USB replication set.

Use one filesystem and one container-visible root:

```text
/data/
├── incoming/
│   └── movies/
└── media/
    └── movies/
```

Radarr receives `/data` as `/data`, not as unrelated `/downloads` and
`/movies` mounts. This preserves atomic moves and makes future hardlink-based
imports possible without changing paths. For manual intake, moving a file from
`/data/incoming/movies` into the library is the default because the source is
not required after import.

The quota protects the existing `rpool` workloads from unbounded library
growth. At design time the pool has roughly 643 GiB free, so a full 400 GiB
library still leaves working headroom for `/home`, `/nix`, Docker, snapshots,
and copy-on-write operation. The existing 5 GiB emergency reservation remains
last-resort recovery space, not usable media capacity.

## Persistent application state

Bind-mount application state from:

```text
/persist/media-automation/
├── radarr/
└── seerr/
```

This state survives tempest's tmpfs root and is covered by the existing local
ZFS snapshots and USB replication of `rpool/persist`. Container images and
layers remain in `rpool/docker`; they are reproducible and stay outside the
backup set. The media files themselves are neither snapshotted nor backed up.

SQLite data must be treated as crash-consistent state. Before relying on a
restore, test recovery from a ZFS snapshot; use each application's supported
backup/export mechanism if stronger database consistency is later required.

## Deployment ownership

Place the Compose definition and a small NixOS integration module under a
dedicated `services/media-automation/` directory. The intended boundary is:

- Compose declares Seerr, Radarr, their private network, bind mounts, health
  checks, and version-pinned images.
- NixOS declares `rpool/media`, the persistent directories and ownership, and
  a systemd unit that starts/stops the Compose project.
- The service module is enabled only on the physical tempest configuration;
  `tempest-vm` may exercise the filesystem layout but must not start production
  application state.

Do not use floating `latest` tags. Select an image publisher and pin explicit
versions during implementation, after checking the current upstream release
and upgrade notes.

## Access and security

- Bind Seerr and Radarr to loopback only. They are used on tempest itself.
- Do not add public firewall ports, public DNS, Cloudflare tunnels, or Caddy
  routes.
- Seerr uses a local owner account. There are no imported media-server users.
- Radarr's API key remains in persistent application state and is entered into
  Seerr during setup; it is not committed to this repository.
- Radarr is an administrative UI. Seerr is the only UI expected in ordinary
  use.

If access from another Tailscale device is later wanted, expose only Seerr on
`tailscale0`; keep Radarr private unless remote administration has a concrete
need.

## Request and fulfillment flow

1. Browse and request a movie in Seerr.
2. Seerr creates the corresponding movie in Radarr.
3. Obtain a file from a source the user is legally entitled to use.
4. Place it in `/data/incoming/movies` and manually import it through Radarr.
5. Radarr verifies the match, renames it, and moves it to
   `/data/media/movies/<Movie (Year)>/`.
6. Open the resulting file directly with mpv.

A request is fulfilled when the playable file exists in the media library.
Seerr is not expected to provide playback, watched state, or an authoritative
scan of filesystem availability without Jellyfin, Plex, or Emby.

## Implementation gates

Validate these before treating the design as deployed:

1. Confirm the chosen Seerr release can complete first-run setup with local
   authentication and Radarr integration but no media server. Current Seerr
   documentation centers Jellyfin, Plex, and Emby, so this is a proof-of-concept
   gate rather than an assumption.
2. Confirm a Seerr movie request appears in Radarr with the intended root
   folder and profile.
3. Import a test file from `incoming` and verify it is moved—not copied across
   filesystems—into `media/movies`.
4. Confirm the resulting file is readable by irene and opens in mpv.
5. Reboot tempest and confirm container state and `/data` survive while no
   state lands on tmpfs root.
6. Confirm `rpool/media` has no sanoid snapshots and is absent from the USB
   replication pairs.
7. Fill a disposable test dataset to its quota and confirm the rest of `rpool`
   retains operating headroom.

If gate 1 fails, do not add Jellyfin merely to satisfy Seerr. Re-evaluate the
discovery front end or use Radarr's discovery view; the no-media-server boundary
is deliberate.

## Deferred decisions

- Exact Seerr and Radarr container images and versions.
- The initial Radarr naming and quality profile. It should reflect local mpv
  compatibility and the 400 GiB cap, not blindly mirror a large TRaSH profile.
- Automated acquisition. It remains out of scope until a lawful source exists;
  choosing a downloader before then would be speculative configuration.
- Automatic deletion or retention. Start with deliberate manual deletion for
  a small library.

