# tempest hosts an opportunistic, file-first movie workflow

Status: accepted (2026-07-31)

## Context

The desired experience is to discover a movie in a polished interface and end
with an ordinary local file ready for mpv. There is one user, a library ceiling
of 400 GiB, no requirement for streaming or server-side watch state, and no
current lawful automated acquisition source. tempest is a daily-driver laptop,
not an always-on server, and its existing ZFS snapshot and USB replication
policies protect irreplaceable data rather than replaceable bulk media.

## Decision

Run Seerr and Radarr on tempest as an **opportunistic media service**: Seerr is
the discovery/request front door, Radarr organizes movies and supports manual
lawful import, and mpv opens the resulting files directly. Do not deploy a
media server, Sonarr, Prowlarr, or a download client in the first version.

Store replaceable movie data in a dedicated `rpool/media` dataset mounted at
`/data` and capped at 400 GiB. Keep application state under `rpool/persist`, but
exclude `rpool/media` from snapshots, Borg, and USB replication. Bind the web
interfaces to loopback and accept that the entire workflow is unavailable when
tempest sleeps or is off.

## Why

This preserves the only desired polished UI without introducing a streaming
catalogue, remote-user model, transcoding pipeline, or always-on availability
promise. The separate quota-limited dataset prevents replaceable files from
consuming backup capacity or exhausting the laptop's pool. Omitting speculative
download infrastructure also makes the missing lawful acquisition source an
explicit boundary instead of hiding it behind installed but unusable services.

## Consequences

- Requests require manual fulfillment until a lawful automated source exists.
- Seerr will not receive playback history or authoritative library scans from
  mpv; mpv is a playback client, not a media server.
- Losing `rpool/media` means reacquiring movies, while Seerr/Radarr state can be
  recovered from the existing `rpool/persist` backup path.
- Moving the library to another filesystem later requires copying up to 400
  GiB and revisiting the shared `/data` path contract.
- Seerr-without-a-media-server must pass a first-run proof of concept before
  implementation is considered viable.

## Rejected alternatives

- **Jellyfin, Plex, or Emby** — adds a library and streaming server solely to
  integrate with Seerr, although playback is local through mpv.
- **Always-on operation** — conflicts with tempest's role and sleep lifecycle.
- **Store media under `/persist` or `/home`** — would snapshot and replicate
  hundreds of gigabytes of replaceable content.
- **Preinstall Prowlarr and download clients** — there is no lawful source for
  them to consume yet.
- **Sonarr from day one** — episodic series are outside the current scope.
