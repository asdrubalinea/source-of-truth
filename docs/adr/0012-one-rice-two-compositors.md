# One rice, two compositors: ember carries niri and mango side by side

Status: accepted (2026-08-16). Amends
[0004](0004-niri-rice-as-enable-module.md).

## Context

The desktop on tempest was `rices/niri/` — ~2,500 lines named after its window
manager. Trying a second compositor (mango, a dwl descendant on wlroots+scenefx
with a PaperWM-style `scroller` layout) exposed that the name was wrong about the
contents: of those lines, the compositor's own config, its window rules and the
two modules that exist purely to work around what niri lacks accounted for
roughly a third. The other two-thirds — stylix, the Noctalia shell, tofi, three
terminals, the wallpaper set, Qt plumbing, fonts, idle handling — never mention
niri at all.

That mattered because of *how* we wanted to try mango. The cheap option is a
rebuild toggle: flip an enable, `apply`, log in. The useful option is having both
sessions installed at once and picking at the greeter, because comparing two
compositors means switching between them ten times a day, not twice a month. The
second option forces the split: two rices enabled in one Home-Manager generation
collide on every shared option (`services.mako.enable = mkForce false` twice, one
stylix scheme, one Noctalia bar order), and identical values only merge by luck.

`CONTEXT.md` also defined **rice** as "a *self-contained* desktop environment:
the Wayland compositor plus its shell furniture", and "tempest's rice is niri" —
both of which stop being true the moment the choice is made at login.

## Decision

**One rice, two compositor layers.**

- `rices/ember/` is the rice: furniture only. It is named for the base16 scheme
  it has always used (`ember-3400k-dark`), not for a window manager.
- `rices/ember/compositors/niri/` and `rices/ember/compositors/mango/` are
  compositor layers — window manager, bindings, layout, window rules.
- Options: `rices.ember.enable` for the rice, `rices.ember.niri.enable` and
  `rices.ember.mango.enable` for the layers. All three are true on tempest. The
  layer flags are **not** a selector; they mean "this session is installed".
- The session is chosen at the greeter. tuigreet moved from
  `--cmd niri-session` to `--sessions … --remember-session`, listing whatever
  each layer contributed via `services.displayManager.sessionPackages`.
- The soft-reboot autologin (ADR 0007) keeps exec'ing `niri-session`
  unconditionally.
- mango comes from its own flake (`github:mangowm/mango`), not from nixpkgs.
- The two layers' window rules are maintained as two hand-written files.

### Why the greeter, and not a rebuild toggle

Because the point is comparison. A rebuild toggle makes every switch cost a
`nh os switch` plus a relogin, which in practice means you stop switching and
never find the papercuts. `--remember-session` also means the choice persists
across reboots without being baked into the config, so "which compositor am I
running" is runtime state — where it belongs — rather than a committed fact.

### Why the autologin stays on niri

`initial_session` fires hands-free after `systemctl soft-reboot`, with no
greeter in the path. Pointing it at the remembered session would mean a broken
mango session autologins into itself with no way out but a TTY. Pinning it to
the compositor that has worked for months costs one extra greeter interaction
after a soft-reboot and removes that failure mode entirely. It also keeps the
autologin free of tuigreet's cache-file format, which is not a stable interface.

### Why mango's flake rather than nixpkgs

nixpkgs has `mango` and a two-option NixOS module. It has **no** Home-Manager
module, so the config would have to be a hand-written dotfile — against this
repo's grain. The flake ships `hmModules.mango`, whose `settings` attrset renders
`config.conf` and then runs `mango -c <file> -p` **at build time**. mango is young
and its config keys move between releases; that validation turns a renamed key
into a failed rebuild instead of a session that drops you at a black screen.
Unlike the niri input, this one *does* `follows = "nixpkgs"`: there is no upstream
cache either way, so following costs nothing and saves a second nixpkgs
evaluation.

### Why two window-rule files instead of one abstraction

The dialects overlap only in the middle. mango has `isglobal`,
`shield_when_capture`, `isnamedscratchpad`, `scroller_proportion`; niri has
`block-out-from`, `clip-to-geometry`, `tab-indicator`, pixel column widths. A
neutral vocabulary could express only the intersection, so every interesting rule
would need an escape hatch — and we would maintain the abstraction *and* the
escape hatches, for two consumers. The real overlap is about ten apps. It is
duplicated on purpose.

## Consequences

What mango gives us for free, which the niri layer needs machinery for:

- **Scratchpads are native** (`toggle_named_scratchpad` + `isnamedscratchpad:1`).
  No nirius daemon, no `mkScratchpad` init/toggle scripts, nothing spawned and
  hidden at startup. ADR 0006 describes a workaround for a niri limitation, and
  remains true of niri only.
- **Sticky windows are native** (`isglobal:1`), so the PiP follows you across
  tags by itself and `pip-follow.nix` has no mango counterpart.
- **XWayland is built in**, so no xwayland-satellite.

What carried over untouched:

- **kanshi**, and therefore all 271 lines of `homes/tempest/monitors.nix`. mango
  implements `wlr_output_manager_v1` (`wlr_output_manager_v1_create` in
  `src/mango.c`), which is the protocol kanshi drives. Machine policy needed no
  porting at all — the strongest evidence the rice/machine-policy boundary from
  ADR 0004 was drawn in the right place.
- **Noctalia**, which has first-class mango support (`CompositorKind::Mango`,
  detected via `MANGO_INSTANCE_SIGNATURE`). The bar, launcher, notifications and
  lockscreen are the same under both.
- **swayidle**, with one exception: powering panels off is compositor-specific
  and swayidle is a single user service reached by both sessions, so
  `ember-monitor-power` branches at runtime on `$NIRI_SOCKET` vs
  `$MANGO_INSTANCE_SIGNATURE`. One script, no duplicated unit.

What we accepted losing under mango:

- **The marquee** (ADR 0011). Layer-shell exclusive zones are generic, so the
  reserve would probably work — but the design rests on reading niri's renderer
  (which layers draw per-workspace vs once, `place-within-backdrop`, negative
  struts), and none of that reasoning transfers to wlroots+scenefx. It has to be
  re-derived empirically, and that is worth doing only if mango sticks.
- **Brightness keys.** The niri layer's script probes whether the internal panel
  is an active output and falls back to DDC/CI when clamshell-docked (ADR 0009).
  Deliberately not ported, and not replaced with a plain `brightnessctl` bind
  either: mango sessions have dead brightness keys. It is a test rice.
- **The Mod+O audio-output switcher and Mod+G even-split.**
- **Dynamic workspaces.** Ten tags stand in for them so the keys match, but a
  tag is a bitmask that always exists — see the **workspace** entry in
  `CONTEXT.md`.

Costs and risks we are taking on:

1. `rices/niri/` no longer exists. Every ADR and guide that named a path under it
   was rewritten; ADRs 0004 and 0011 also had option names updated, and 0004
   carries an amendment header.
2. mango builds from source on every input bump — no cache.
3. mango's NixOS module sets `xdg.portal.wlr.enable = mkDefault true`
   system-wide, so xdg-desktop-portal-wlr is now present in the niri session too.
   Portal backends are keyed by `XDG_CURRENT_DESKTOP` and niri keeps its own
   config entry, so this should be inert — screencast under niri is the first
   thing to re-check if something misbehaves.
4. `rices/ember/swayidle.nix` references `pkgs.mango` unconditionally, so the
   compositor is in the closure of any host enabling the rice even with the mango
   layer off. Only tempest enables ember, and it enables both layers.
5. The directory `rices/` now holds two rices of different shapes: estradiol
   (one compositor, unsplit) and ember (furniture plus layers). estradiol was
   deliberately not touched — it has an older problem of its own (per-host
   monitor layouts behind `hostname ==`, see `CONTEXT.md`) and folding it into
   this change would have hidden both.

## Alternatives considered

- **Rebuild toggle, one compositor live at a time.** Smallest change, no
  refactor. Rejected: makes switching expensive enough that the comparison never
  actually happens.
- **Copy the furniture into a second rice.** No refactor of the existing tree and
  trivially deletable. Rejected: ~1,200 duplicated lines that drift, and any
  `mkForce` or list-valued option collides the moment both are enabled.
- **Widen the enable gate in place** (`rices.desktop.enable`, mango importing
  `../niri/tofi.nix`). Smallest diff. Rejected: the mango rice would depend on
  the niri directory forever, and "which rice owns tofi" would have no answer.
- **Nest nothing; keep `rices/{ember,niri,mango}/` flat.** Half the churn.
  Rejected: reads as three peer rices when it is one rice and two engines, which
  is the exact confusion the glossary exists to prevent.
