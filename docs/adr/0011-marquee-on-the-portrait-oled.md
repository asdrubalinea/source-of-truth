# The marquee: a permanently reserved 16:9 band on tempest's portrait QD-OLED

Status: accepted — implemented in `rices/niri/marquee.nix`. Two sections were
amended during implementation, both because a claim read out of waybar's and
mpvpaper's source assumed *wlroots'* conventions and niri does not follow them:
*Why a waybar that is not a bar* (panel identity) and *Layer assignment*.
Checks 1 and 2 below have since passed; 3 and 4 are unrun.

tempest's QD-OLED (ADR-0009) now runs portrait (`transform "270"`, logical
1440x2560). Its top edge is uncomfortably high to read, so the top **810 logical
px of that panel alone** are permanently removed from niri's working area and
given to a 16:9 video: the **marquee** (see CONTEXT.md). Windows tile in the
1440x1750 below it with no window rules and no manual sorting, and nothing ever
moves when a video starts or stops.

The reserve and the pixels are **two separate, independently-lived processes**:
an always-on, opaque-black, module-less **waybar** owns the exclusive zone
(`niri-marquee-strut.service`), and an on-demand **mpvpaper** draws the video
(`niri-marquee.service`, transient). The mechanism lives in
`rices/niri/marquee.nix`; machine policy supplies only `rices.niri.marquee =
{ panel; width; }` from `homes/tempest/`, and the rice derives the 810 depth as
`width * 9 / 16` so no derived number is ever hand-typed.

## Why not `layout.struts` (the obvious answer)

niri v25.08 has **no per-output layout override**. Verified with `niri validate`:

```
output "DP-2" { layout { struts { top 810 } } }   →  × unexpected node `layout`
layout { struts { top 810 } }                     →  config is valid
```

Struts are global, so they would also take 810 from eDP-1's 1600 and 810 of the
portable's 1440 — unusable the moment anything else is connected. A layer-shell
**exclusive zone** is the only per-output reserve niri honours, and it happens to
solve the other half of the problem for free: layer surfaces belong to no
workspace, so the marquee survives workspace switches with nothing chasing it.

## Why a waybar that is not a bar

The reserve must be always-on, on one output, matched by panel identity rather
than connector — `homes/tempest/monitors.nix` matches by make/model/serial
precisely because "the DRM connector name is incidental" (the OLED moved DP-7 →
DP-2 with the port). waybar gives us the first two directly, and it creates and
destroys its per-output bars itself, so the marquee simply does not exist when
the panel is absent (CONTEXT.md's "degrades cleanly").

**Panel identity it does not give us, and neither does mpvpaper.** This ADR
originally claimed waybar could be handed the kanshi criteria verbatim, reasoning
from `src/config.cpp:190` (`config_output == name || config_output ==
identifier`) plus wlroots' description format, `make model serial (connector)`.
The code is right; the format is not niri's. niri publishes

```
<make> - <model> - <connector>          # niri-config/src/output.rs:112-119
Micro-Star Int'l Co., Ltd. - MAG 272U E16 - DP-2
```

— the connector is *in* it and the serial is *not*. So under niri there is no
port-independent string either tool can match, and a make/model/serial criteria
matches **nothing**: waybar logs its config, creates no bar, and says nothing
about why. mpvpaper substring-matches the same two strings
(`src/main.c:728-730`) and fails identically.

niri's own IPC does report `make`, `model` and `serial` separately, so the
identity boundary moved there: `marquee-panel-connector` joins those three,
compares against `cfg.panel` — still byte-identical to the kanshi criteria — and
prints the connector. Only a connector name ever reaches waybar or mpvpaper. Two
consequences of that translation being a *runtime* step:

- The strut can no longer come from `programs.waybar`, whose config is written at
  build time. It is a `niri-marquee-strut.service` that resolves, writes
  `$XDG_RUNTIME_DIR/marquee-waybar.json`, and `exec`s `waybar -c … -s …`.
- A panel that reappears on a *different* connector leaves that file stale, which
  waybar cannot ride out (unlike the same-connector case, which it handles
  itself). So the unit watches niri's event stream and exits on a connector move;
  `Restart=always` re-resolves.

The considered alternative was patching mpvpaper: its `set_anchor` (all four
edges), `set_size(0,0)` and `set_exclusive_zone(-1)` are hard-coded at
`src/main.c:701-708` with no CLI escape, and ~6 lines would turn them into flags
for an exactly-band-sized surface that reserves its own space. **Rejected because
it couples the panel's working area to a video decoder staying alive.**
`rices/niri/noctalia.nix:23` records this machine already losing a shell
component to a crash loop; under that design an mpvpaper crash would jolt every
window on the panel up 810px and back down on restart. Splitting the concerns
means a dead video just leaves a dark band.

waybar is also the **dark backdrop**: it is opaque black, not transparent, so an
untenanted marquee is unlit pixels rather than a static image.

`rices/niri/waybar/` — the pre-Noctalia bar, superseded per ADR-0003 and
imported by nothing — is deleted in the same change. It was going to collide with
the strut on `programs.waybar.settings`; the strut ended up not using that module
at all, but a dead bar config that nothing imports is still worth removing.

## Layer assignment (creation-ordered, by necessity)

Three surfaces must stack in a fixed order on this panel: the wallpaper at the
bottom, waybar's black above it, the video above that.

This ADR originally gave each its own layer-shell level — waybar on
`background`, mpvpaper on `bottom` — so that the order would not depend on
same-layer surfaces stacking in creation order (true in wlroots/niri, but not
promised by the protocol). **That is not implementable**, for two independent
reasons found while writing the module:

- **waybar cannot sit on `background`.** Its `layer` deserializer understands
  only `"bottom"`, `"top"` and `"overlay"` (`src/bar.cpp:63-71`; `enum bar_layer`
  at `include/bar.hpp:32` has exactly those three members). An unrecognised value
  is *silently ignored* — the bar keeps its mode default, `bottom`. So a config
  saying `background` would have looked right and done nothing.
- **There is no level between `bottom` and normal windows.** So the video cannot
  be given its own layer strictly above waybar's black and still stay under the
  windows; `top` would put it over fullscreen windows too.

So both live on `bottom`:

| surface | layer | why |
| --- | --- | --- |
| Noctalia wallpaper | `background`, reparented into niri's **backdrop** | already so, via the `place-within-backdrop` layer-rule at `rices/niri/niri.nix:631-634`; the backdrop renders behind everything |
| waybar (reserve + dark backdrop) | `bottom` | the only layer it can reach that is still below windows |
| mpvpaper (video) | `bottom`, mapped later | above waybar by creation order (below) |

niri *does* define same-layer order, even though the protocol doesn't: smithay's
`LayerMap` keeps an insertion-ordered set, and niri renders
`layers_on(layer).rev()` front-to-back (`src/niri.rs:4392-4393`), so the most
recently mapped surface is on top. waybar is always-on from
`graphical-session.target` and the video is cast on demand, so the video always
maps later and always wins.

The residual hole: restarting waybar while a tenant plays remaps its black
*above* the video — audio keeps playing and the band goes black. Going dark and
re-casting fixes it. `After=waybar.service` on the tenant unit records the
requirement.

## Why the marquee is permanent rather than summoned

Two reasons, and the first is the whole point of the feature:

- **Reflow.** If the exclusive zone appeared and disappeared with playback, every
  start and stop would recompute the working area and resize every column on that
  output — exactly the manual re-sorting the marquee exists to eliminate. The band
  is a fixed property of the panel, not a mode.
- **Burn-in.** No window can ever cover the band, which makes whatever it shows
  the single most exposed surface on the machine — worse than the persistent bar
  that `auto_hide` + `reserve_space = false` were introduced to mitigate
  (`rices/niri/noctalia-widgets.nix:26-37`). So an empty marquee shows *nothing*:
  not the wallpaper, not a paused frame. On OLED, dark means pixels off. A
  *paused* tenant is the one way to put a static frame there on purpose, which is
  why pausing hands the panel back to swayidle — see *Why playback holds an idle
  inhibitor*.

## Why playback holds an idle inhibitor

Watching is not input. Untouched, `rices/niri/swayidle.nix` puts the `drift`
screensaver fullscreen over the video at 300s, locks at 600s, powers the monitors
off at 900s and suspends at 1200s — and mpvpaper contains **no idle-inhibit code
whatsoever**, so unlike a browser it never holds the session up.

swayidle reads logind's `BlockInhibited` property and calls `disable_timeouts()`
whenever any `idle` inhibitor is held (`main.c:252-279`, `365-370`), re-enabling
on release. So `systemd-inhibit --what=idle` — the same lever
`scripts/keep-awake.nix` already uses — suppresses the entire chain. mpvpaper is
deliberately given **no `loop`**, so a finite video hits EOF, exits, releases the
inhibitor and darkens the marquee by itself: a 40-minute video is a self-cleaning
40-minute keep-awake.

The lock is held for **playback, not tenancy** — a separate
`niri-marquee-awake.service` rather than a wrapper around mpvpaper — so that
pause can drop it. That was decided when pause was added (`Mod+Shift+Y`), because
holding it across a pause collides with the burn-in argument above: a paused
tenant is exactly the static frame the band must not sit on, and swayidle's
screensaver at 300s (panel off at 900s) is the thing that covers it. Holding the
inhibitor would have suppressed the one mechanism that fixes it.

`BindsTo=niri-marquee.service` is what keeps the two honest: the tenant going
inactive for *any* reason — EOF, crash, "go dark" — releases the lock with
nothing watching for it. And because the unit is active precisely while the
tenant plays, it doubles as the pause state, so the pause key needs no round trip
over mpv's socket to know which way to toggle.

This makes marquee playback an *implicit* **keep-awake**, a term CONTEXT.md
previously defined as deliberate-only; that definition has been widened.

## Consequences

- **The wallpaper may be hidden on that panel while a tenant plays.** mpvpaper's
  surface is the whole output, so whatever mpv paints outside the video covers the
  rest of the panel — visible in the 8px window gaps and on empty workspaces.
  Accepted as the price of not patching mpvpaper. (mpvpaper actually sets
  `background-color=#00000000` and asks EGL for an 8-bit alpha channel
  — `src/main.c:421` and `568-575` — so the remainder may come out *transparent*
  and leave the wallpaper visible instead. Either outcome is fine; don't "fix"
  whichever one shows up.)
- **The video's position above the black band depends on mapping order.** See
  *Layer assignment* above — this is a property of niri, not of the layer-shell
  protocol, and it is the only arrangement waybar can express.
- **A live or looping tenant is an open-ended keep-awake.** tempest will not lock
  and will not suspend while it plays; there is deliberately no cap. Pausing or
  going dark are the two ways out.
- **Pause and seek are the only controls, and only pause has a key.** `Mod+Shift+Y`
  toggles it. Seek, volume and the rest stay unbound: mpv's socket
  (`input-ipc-server`) is there for whoever wants them, and volume is already
  reachable as an ordinary PipeWire stream. Nothing MPRIS-based sees the tenant —
  the mpv MPRIS script isn't loaded — so `playerctl` and the media keys don't
  touch it, which is deliberate: they belong to the browser.
- **DRM streaming can never be a tenant.** The marquee can only host what yt-dlp
  can fetch, so Netflix/Prime/Disney+ are out, and there is no marquee at all on
  the laptop-only or ultrawide profiles. `rices/niri/pip-follow.nix` and the PiP
  window rules therefore stay — the marquee does **not** supersede them, and
  CONTEXT.md keeps the two concepts explicitly distinct.
- **Playback quality is capped at 1440p.** The band is 2160x1215 *physical*
  (1440x810 logical at scale 1.5), so unrestricted `bestvideo` would decode
  2160p for a 1215px-tall strip.
- **The marquee follows the panel, not the port** — but only because a resolver
  translates identity into a connector on every start (see *Why a waybar that is
  not a bar*). Within one connector it needs nothing: it survives kanshi profile
  switches and the ADR-0008 redock, since mpvpaper's `destroy_display_output`
  (`main.c:620`) only drops that output's surface and never exits, and recreates
  it when the panel returns. While the panel is away a tenant keeps playing
  **audio** invisibly. Across connectors the strut restarts itself, but a *tenant*
  does not: mpvpaper is holding the old connector name, so a port change
  mid-playback loses the video (the audio plays on) until it is re-cast.
- **`-p`/`--auto-pause` and `-s`/`--auto-stop` must never be passed.** Their
  "wallpaper is hidden" heuristic misfires on a full-output surface that windows
  partially cover.

## First-run checks

Four things could not be verified without running the compositor. The first two
have since been run against the live session:

1. ✅ waybar honours `height: 810` with zero modules configured —
   `Bar configured (width: 1440, height: 810) for output: DP-2`.
2. ✅ Its exclusive zone is honoured on that output alone, and the black lands
   above the backdrop-reparented wallpaper.
3. A cast video lands above that black rather than under it (the creation-order
   claim in *Layer assignment*, read out of niri's source but never watched).
4. A fullscreened window covers the marquee — expected, since fullscreen windows
   sit above `bottom`-layer surfaces.

The failure mode to recognise for anything output-related: waybar logs "Using
configuration file …" and then *nothing*. No bar and no error means the `output`
matcher matched nothing — see *Why a waybar that is not a bar*.
