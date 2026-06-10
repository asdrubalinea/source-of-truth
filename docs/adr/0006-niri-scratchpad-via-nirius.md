# niri scratchpad via the nirius daemon, not a hand-rolled `niri msg` script

Status: accepted (2026-06-10)

## Context

The goal was "keep Telegram always open and pop it out on the focused
workspace with Mod+T" — i.e. an i3/sway-style scratchpad. niri has no hidden
workspace, so a scratchpad has to be *emulated*: a window is parked on the
bottom-most workspace and flipped onto the focused workspace on demand. niri's
IPC is rich enough to build this by hand — the existing `Mod+G` bind
(`rices/niri/niri.nix`) proves the `niri msg action … | jq` pattern works, and
`move-window-to-workspace --window-id … --focus` + `focus-window --id …` cover
the needed primitives.

## Decision

Use **`nirius` + `niriusd`** (nixpkgs, 0.7.1) rather than a hand-rolled script.
`niriusd` runs from `spawn-at-startup`; `nirius scratchpad-toggle` marks a
window as a scratchpad member and `nirius scratchpad-show --app-id REGEX` flips
it in/out of the focused workspace. The infrastructure is generic — a
`mkScratchpad { name; appId; spawn; }` helper (`rices/niri/niri.nix`) builds the
launch/park (`init`) and summon/dismiss (`toggle`) scripts for any app — with
two tenants:

- **Telegram** — always-open, parked at login by `init`, summoned with `Mod+T`.
- **Floating terminal** — a `kitty --class scratchpad-terminal`, spawned lazily
  on first use and summoned with `Mod+Shift+Return` (which previously opened an
  Emacs frame; that bind and the Emacs server are disabled for now).

`Mod+Shift+T` toggles the *focused* window in/out of the scratchpad as general
infrastructure. Geometry (float + centered, sized as a proportion of the working
area so it adapts to any output) is a window-rule, matched per app-id.

## Why

The hand-rolled path is viable but would have to **reinvent membership state**
— which windows are "in the scratchpad" and where each was last shown — that
`niriusd` already tracks as a daemon. Emulating a stateful scratchpad with
stateless `niri msg` calls means encoding that state in workspace positions and
re-deriving it on every keypress; nirius is the maintained, purpose-built
version of exactly that. The cost is one extra daemon and a nixpkgs dependency,
both cheap and reversible.

## Consequences

- A daemon (`niriusd`) now runs in the niri session; the scratchpad silently
  no-ops if it isn't up, so the init wrapper retries `scratchpad-toggle` while
  it starts (spawn-at-startup entries launch concurrently, not in order).
- **`scratchpad-show` only acts on windows that are already scratchpad
  *members*, and nirius exposes no way to query membership.** If the login-time
  parking doesn't take (e.g. Telegram's slow firejail cold start outruns the
  wait), Telegram comes up as a plain window and `Mod+T` becomes a silent no-op.
  So the `toggle` script doesn't trust membership: it reads the window's
  workspace via `niri msg` before and after `scratchpad-show`, and if the window
  didn't move it establishes membership on the spot (`scratchpad-toggle` to
  park, or `move-to-current-workspace` to summon). The toggle therefore
  self-heals an un-parked or freshly-respawned window within one or two presses,
  rather than depending on login-time parking being perfect.
- Parked Telegram lives on the bottom-most workspace and is therefore visible
  in the overview (`Mod+E`) — unavoidable, since niri has no truly hidden
  workspace. Accepted wart.
