# The ember rice: visual language

Reference for the look, and for how to extend it without breaking it. Written
after the 2026-09-02 pass that turned the rice from a unixporn-shaped desktop
into a workstation-shaped one.

**What this is not.** Not an ADR — nothing here is hard to reverse, every value
is one config key away from being changed, so no decision cleared the ADR bar
(see `docs/adr/` for the ones that did). Not a spec either: the config is the
spec. This is the *reasoning*, so that a change made six months from now lands
in the same language instead of quietly reintroducing what was removed.

Canonical vocabulary lives in `CONTEXT.md` (**bar**, **body face** / **display
face**, **machine policy**, **legible size range**). This document does not
redefine those terms; it explains the design they belong to.

---

## The thesis

**An instrument, not artwork.**

The desktop's job is to disappear while you work and to answer a question when
you look at it. Everything below follows from that single sentence, and every
"why not" in this document is really "because that would ask for attention it
hasn't earned".

The concrete consequence: the desktop has no decoration that isn't also
information. Not "minimal" — minimalism is a style, and a style is still a
claim on attention. The test is functional. Does this mark tell me something?
If not, it goes.

---

## Four principles

### 1. Two typographic roles, not three letterform slots

Theming exposes `serif` / `sansSerif` / `monospace`. Those name *letterform
classes*. The rice needs something else: a split by **how long the text is
looked at**.

- **Body face** — read continuously. Terminals, editor buffers, and every
  application's own interface chrome. Must be unremarkable, because character in
  a face you read for eight hours is fatigue. → **Ioskeley Mono** (an Iosevka
  cut shaped after Berkeley Mono), in *all three* slots.
- **Display face** — only ever glanced at. Bar readouts and clock. Strings are
  a handful of characters and are never read as prose, so this is the one place
  the desktop gets to have a voice. → **Departure Mono**, a pixel font, pointed
  at exactly one surface.

Putting a monospace face in `sansSerif` is not a category error. In this repo a
slot is a **role** — "what non-terminal UI renders in" — not a claim about
proportionality. It is how you say *the interface reads like the terminal does*.

A display face is **never** chosen by putting it in a slot. `sansSerif` reaches
noctalia, GTK3, GTK4, Obsidian's chrome and Zed's chrome; a pixel font there
would land on all five. It is pointed at the single surface that wants it,
by name.

Web page body text follows too, deliberately. stylix writes no fontconfig
generic aliases, so `fonts.fontconfig.defaultFonts` in `rices/ember/fonts.nix`
restates the same three roles where fontconfig can act on them — a page asking
for `font-family: sans-serif` lands on the body face. That alias is not
cosmetic: the NixOS default names DejaVu, which this host does not install, and
cairo clients (noctalia) rendered tofu rather than falling back.

### 2. One geometric register, derived from one root

The desktop has a single answer to "are things square or round", and exactly one
place where that answer is written down: **the bar's edge treatment**.

```
bar.default.{radius*, margin_edge, margin_ends}   ← the root, and the only
  │                                                 value you should edit
  ├─→ niri  layout.struts.top
  ├─→ niri  window-rules geometry-corner-radius
  └─→ mango border_radius
```

Currently: flush and square. A floating rounded strip is a *card laid on the
wallpaper* — it belongs to the wallpaper, not to the screen, and it forced two
things to match it. Every window took a 12px radius so its corners wouldn't
disagree with the bar's. And niri had to leave `struts.top = 0` so a square
window corner wouldn't collide with the bar's curve — which, since the bar
reserves no space, bought nothing but a dead 8px strip of wallpaper across the
top of every tiled window.

Square at the root collapsed all of that: three derived values went to 0/0/-8
and the dead strip disappeared.

**The rule for future edits:** change the root, let the rest follow. If you find
yourself setting a corner radius in two places to make them agree, you are
editing a derived value and the root is now lying.

Gaps are a separate axis and stayed at 8: `gaps = 8` with `struts = -8` on all
four sides is niri's documented idiom for *inner gaps only* — windows separate
from each other but not from the display edge. mango expresses the same thing
directly as `gappi*` 8 / `gappo*` 0.

### 3. Contrast is spent, not free

The external panel is a 27" QD-OLED (`docs/adr/0009`). Lit pixels cost panel
lifetime, so brightness is a budget, not a free parameter. Three practices fall
out of it:

**Hierarchy by size, not by value.** The palette's dark end is compressed —
`base02` is only 16/255 above `base00` in every channel, which is under the
discrimination floor on a screen this dark. The wallpaper's first cut proved it:
tick marks drawn at `base02` to subordinate them came out *invisible*. They are
now the same `base03` as the corner brackets, subordinated by being short (10px
against a 200px arm) and thin (3px against 4px). Size survives downscaling and
the wlsunset warm filter; a 16-step value difference survives neither.

**Nothing is lit that doesn't have to be.** The bar auto-hides. The wallpaper is
0.13% lit. Window borders are alpha-dimmed rather than solid.

**Colour means something.** `base09` (orange, the ember) appears on the desktop
in exactly one place — the wallpaper's centre reticle. Spending it on chrome
would spend the one accent that still reads as a signal. The one other coloured
border is `base08` on a window that is being screencast: transient, and a fact
you want answered at a glance, which is the whole bar a colour has to clear.

**And it means something inside a buffer too**, which took a second pass to
notice. The 2026-09-02 pass reached every surface the desktop draws itself and
stopped at the edge of the two windows actually being looked at all day: the
terminal and the editor. Both were still running base16's slot convention —
one hue per syntax category, variables red, types yellow, strings green,
functions blue, keywords magenta — which is six colours in a ranking that
doesn't exist. Nothing there is more urgent than anything else, so the only
thing the colour reports is "different kind of token", and the shape of the
code already reported that.

The replacement is NANO emacs' face model (`desktop/helix-theme.nix`): faces
chosen by *what the reader is being told* rather than by token category —
`faded` for prose, `default` for your own names, `strong` (same colour, more
weight) for definitions, `salient` for the language itself, `literal` for
values written out in the source, `popout` for look-here-now, `critical` for
wrong. `base09` stays spent on the reticle and nowhere else, which is why
popout is `base0A` — the slot the scheme already annotates "warnings, matches".

**The foreground ramp has two levels, not three**, and finding that out cost a
revision. Against the ground: `base03` is 3.41:1, `base04` 9.19:1, `base05`
14.74:1 — so `base04`→`base05` is **1.60:1**, under the threshold where the eye
reads two values as different at all. The first cut spent `base04` as a text
colour on punctuation, justified in the file as "a real step (43/255)": a raw
channel delta, which is the identical error to the tick marks below. It read as
code with a smudge on it, and its one real effect was to fill in the middle of
the comment→code gap and flatten the buffer. `base04` is a *fill*, not a
foreground.

Two levels means `faded` is single-tenant — prose only. NANO fades strings too
and on its own white ground can afford to (its faded/default separation is ~7x;
ember's dark end gives 4.3x), but here it made string literals read as
commented-out code. And since every hue in this palette sits 1.4–2.7:1 from
`base05`, hues never separate from code by *value*, only by hue — which is both
why the base16 rainbow "worked" and why collapsing all of it onto a two-level
ramp lost the separation. So the buffer keeps exactly the distinctions the ramp
cannot carry, and no more: language, literal, your names, prose. Four roles,
three hues.

The same pass took the terminal's own chrome down: stylix fills every inactive
wezterm tab with solid `base03`, which put a row of lit warm-grey blocks along
the top of the window, so the tab bar is now text on the buffer's ground with
focus carried by value. That is the gutter argument in miniature — a fill at
`base01` or `base02` is *under the discrimination floor* on this panel, so an
invisible background is the worst available trade: it lights pixels for the
panel's lifetime and answers nothing. Where a surface genuinely needs a
boundary (a popup floating over live text) it gets a 1px outline, which is the
bar's answer, not a second one.

Related constraint, and it is a real one: the palette must stay distinguishable
under **wlsunset** (night 4000K), which crushes the blue channel. That is why
this scheme exists at all rather than oxocarbon-dark, whose blues and magentas
collapse into each other once warmed. Any new colour has to survive that filter.

### 4. Generated from the palette, never copied from it

Every colour on screen traces back to `rices/ember/ember-3400k-dark.yaml`
through stylix. Nothing hard-codes a hex value, and nothing hard-codes a font
name that a slot already knows.

The wallpaper is the strongest case: it is *rendered from base16 at build time*
by an ImageMagick derivation in `rices/ember/wallpaper/default.nix`, so it
cannot drift out of palette. Edit the scheme and the wallpaper re-renders.

This is also why two hard-coded font names were bugs rather than preferences.
`desktop/vscode.nix` said `"Maple Mono"` and `desktop/zed-editor` forced
`ui_font_family = "Maple Mono"` — both went stale the moment the rice changed
face, silently, because a string can't be wrong at build time.

---

## The pieces

| | | |
|---|---|---|
| Body face | Ioskeley Mono | `rices/ember/stylix.nix` (all three slots) |
| Display face | Departure Mono | `rices/ember/noctalia.nix` (`shell.font_family`, mkForce) |
| Palette | Ember 3400K Dark, sharpened | `rices/ember/ember-3400k-dark.yaml` |
| Bar | flush, square, 1px outline, 32px | `rices/ember/noctalia-widgets.nix` |
| Windows | square, 2px dim border, 8px inner gaps | `compositors/{niri,mango}` |
| Cast marker | `base08` border while screencast | `compositors/niri/window-rules.nix` |
| Instrument panel | Mod+I, floating transient `sitrep` | `rices/ember/sitrep-hud.nix` |
| Ground | generated HUD bezel | `rices/ember/wallpaper/default.nix` |
| Pointer | capitaine-cursors-white @ 24 | three places — see gotchas |
| Terminal cursor | steady block, all four terminals | `{kitty,alacritty,wezterm,konsole}.nix` |
| Terminal inset | 12px padding, all four terminals | `{kitty,alacritty,wezterm,konsole}.nix` |
| Terminal tabs | text on `base00`, no fills, no `+` | `rices/ember/wezterm.nix` |
| Buffer | NANO face model over base16 | `desktop/helix-theme.nix` |
| Font packages | 5 families, each one referenced | `rices/ember/fonts.nix` |

The **ground** is worth describing since it's the one thing built from scratch:
a 3840×2160 PNG, `base00` field, four `base03` corner brackets (4px, 200px arms,
64px inset), `base03` tick marks down all four edges (3px, 160px apart, 10px
long with every fifth counted out from the centre drawn at 24px), and a small
`base09` centre reticle. 0.14% of pixels sit above the ground colour.

The ticks are graduated rather than uniform for the same reason they are short:
each edge reads as a scale with a marked axis, the centre major lands on the
reticle's axis, and it costs 0.008 percentage points of lit area because length
is the cheap axis — the same hierarchy-by-size move as principle 3, applied
within a single mark type. No line is thinner than 3px because the smallest panel is 0.5×
and a 2px line lands there as a 1px line at half opacity — a smudge, not a mark.

---

## If you want to add something

**A bar widget.** Lane entries in `noctalia-widgets.nix` are instance names; a
bare name with no `[widget.<name>]` table resolves to the stock widget at its
defaults. Keep readouts numeric and label-free (`visualization = "none"`,
`show_value = true`) — the display face is doing the work, a glyph beside every
number is noise. Which units a readout watches is **machine policy** and belongs
in `homes/<host>/`, not in the rice.

**An application's fonts.** Read the slot, never type the name:
`config.stylix.fonts.monospace.name`. If the app's own chrome should differ from
its buffer, that is a real distinction — but check first whether stylix already
sets it, because an override that restates what stylix says is the exact shape
of the two bugs described in principle 4.

**A colour.** Take it from `config.lib.stylix.colors` — `.withHashtag.baseXX`
for anything wanting `#RRGGBB`, the bare form where a config wants its own
syntax (mango takes `0xRRGGBBAA`). Then ask whether it survives 4000K and
whether it earns being lit.

**A wallpaper.** Measure it before it goes in `oled/`, with the same command the
table in `wallpaper/default.nix` records — that directory is the rotation pool
and nothing unmeasured belongs in it. Bright images go in the flat directory for
manual picking. Better: extend the generated ground instead, and it can't drift.

**Something rounded, or a shadow, or blur.** Change the root (principle 2) and
let it propagate. Do not round one surface. Note that mango's scenefx backend
*can* do blur and per-window opacity and deliberately doesn't: the brief for the
second compositor was "the same desktop, different engine".

**A terminal.** All four are configured and themed and stay that way, even
though wezterm is the only one any binding spawns — kitty and alacritty are the
fallback when it breaks, and konsole is there because Dolphin's F4 panel embeds
the KPart and reads the default profile. A behavioural change to one (cursor
shape, padding) goes to all four or it is a divergence, not a change. konsole is
also the one that is not a stylix target, so its palette is written out from
base16 by hand in `konsole.nix` — a fifth terminal would need the same.

**A syntax colour.** Almost certainly no. Ask which of the faces the token
belongs to — `faded` / `default` / `strong` / `salient` / `literal` / `popout`
/ `critical` — and use that; a new hue means you are claiming a distinction
those faces cannot express, and there is room for about one of those. Do not
reach for `base04` to make something recede: measure the ratio first. Note that
`desktop/helix-theme.nix` deliberately contradicts two slot comments in
`ember-3400k-dark.yaml` (`base0D` "functions", `base0E` "keywords"): those
describe the base16 convention the theme departs from and stay true for the
ANSI palette and fish's highlighting, so the yaml is not edited to match.
The theme lives in `desktop/`, not here, because it maps *slots to roles* and
holds for any scheme — which is also what keeps an ocelot looking like the
machine it runs on.

**A rice-wide value that differs per machine.** It isn't a rice value. Panel
identities, terminal sizes, monitor layout and geography are **machine policy**
and live in `homes/<host>/`. The rice knows no hostnames — if you're writing
`hostname == "…"` inside `rices/ember`, the fact belongs elsewhere.

---

## Tried and rejected

Kept here so nobody spends the afternoon rediscovering them.

**Solid bright window borders** (`base09` at `ff` active, `base02` at `ff`
inactive). Motivation was real: once corners went square, the dimmed pair
(`base03` at 45% over `base00` lands around `#2f2b26`) left focus genuinely hard
to find with three columns open. But a bright ring around the focused window
reads as an *alert*, not as focus, and it is precisely the always-lit static
content ADR 0009 exists to avoid. Reverted; the ADR stands unamended. If focus
legibility comes up again, the answer is not more brightness.

**Tick marks a value step below the brackets** — see principle 3. Invisible.

**Per-output wallpapers** to solve the aspect-ratio problem. Would have put
monitor serial numbers inside the rice, which is the definition of a machine
policy leak. Solved with a mostly-void design plus `fill_mode = "fit"` instead.

**A pixel font in the `sansSerif` slot.** Reaches five consumers; only one
wanted it. Hence the point-at-one-surface rule.

**An always-on telemetry panel** — the classic "hackish" move. Blocked by two
independent facts: the bar auto-hides for burn-in (ADR 0009), so a persistent
readout contradicts the rice's own mitigation; and noctalia v5's `custom_button`
can no longer poll a script and render its stdout (ADR 0003), so the five
bespoke readouts have no v5 equivalent without writing a plugin.

Answered instead by inverting the lifetime: **Mod+I** spawns `sitrep` in a
floating terminal (`rices/ember/sitrep-hud.nix`), respawned per invocation so
the numbers are read at the moment you look rather than a poll interval stale,
and lit only while you are looking. Same question, and it costs zero permanently
lit pixels — which is principle 3 rather than an exception to it. If a future
readout wants to be always visible, this is the shape the answer takes.

---

## Gotchas that will bite

**Runtime state shadows the Nix config.** `~/.local/state/noctalia/settings.toml`
deep-merges *over* the read-only `config.toml` that Home Manager pins. Anything
ever touched in noctalia's settings GUI is written there and wins forever. This
is how `shell.screen_corners` stayed `true` for weeks while the rice said
`false`, and it currently also pins `wallpaper.default` and per-monitor
wallpapers. There is no Nix-side fix — `mkForce` cannot beat it. When a setting
appears not to apply, read that file first. To clear a key: stop the service,
edit, start.

**The pointer cursor has three consumers, one root.** `stylix.cursor` themes
the *client-drawn* cursor; niri and mango each draw their own from their own
config, and both now read `config.stylix.cursor.{name,size}` rather than
restating it. Set it in one place. If you ever type a cursor theme name inside
a compositor layer, the pointer will change appearance as it crosses between an
app's surface and the compositor's.

**Cursor themes have design sizes.** capitaine's `left_ptr` embeds
24/30/36/48/60/72 and nothing smaller, so the inherited size of 20 would have
XCursor resample the 24px bitmap into a soft pointer. Same principle as the
pixel font: check what sizes exist before picking one.

**Deprecated noctalia keys fail silently.** `noctalia config validate` runs at
build time, but an unknown or renamed key is a *warning*, not an error. Three
sysmon widgets carried `display` / `show_label` for months after they became
`visualization` / `show_value`; all six keys were parsed and discarded, and the
pills only looked correct because "bare numeric" is also the default. Read the
build warnings.

**`fill_mode = "fit"` insets the ground on non-16:9 panels.** Nothing on the
OLED or the 16:9 externals; ~150px top and bottom on eDP-1; ~440px left and
right on the 21:9 ultrawide. Invisible, because the letterbox colour is the
image's own ground, and the frame stays centred and isotropic. `stretch` would
hug every physical edge instead, at the cost of anisotropic line weight (up to
1.34:1 on the ultrawide). One word, either way.

**Run `alejandra` on files, not directories.** Formatting `rices/ember/`
wholesale reformats whatever else has uncommitted work in it.

---

## See also

- `CONTEXT.md` — **bar**, **body face** / **display face**, **machine policy**,
  **legible size range**
- `docs/adr/0009-oled-external-sdr-under-niri.md` — the OLED burn-in posture
  that constrains most of principle 3
- `docs/adr/0012-one-rice-two-compositors.md` — why every visual value has to be
  expressible in both niri's and mango's config languages
- `docs/adr/0003-noctalia-custom-bar-readouts.md` — the bar readouts that used
  to exist, and why they don't
- `docs/adr/0004-niri-rice-as-enable-module.md` — why the rice is an enable
  module at all
