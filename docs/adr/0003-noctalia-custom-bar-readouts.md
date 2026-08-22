# tempest niri: custom bar readouts ported from waybar to Noctalia CustomButton; bar layout is Nix-owned

Status: accepted (2026-06-04); **largely undone (2026-07-19)** by the Noctalia
v4→v5 rewrite, which removed the widget this decision rests on. Five of the six
readouts no longer exist. See the Amendment at the end before treating anything
below as current.

## Context

The niri rice replaced waybar with Noctalia (the "shell" leg of the NNN stack —
NixOS + niri + Noctalia). waybar carried six bespoke status readouts that
Noctalia has no built-in equivalent for: `power` (live battery watt draw),
`fans` (max hwmon fan RPM), `cpu-hog` / `mem-hog` (worst sustained CPU / RSS
offender), `health` (combined rpool + borg + syncoid backup health — the
indicator defined in CONTEXT.md), and `flights` (nearest aircraft overhead, from
the always-on `flights-server`). Each was a shell script emitting waybar JSON
(`{text, tooltip, class, alt}`), styled by per-`class` CSS into stylix colors.

Noctalia is a Quickshell app whose bar is configured from `settings.json`. Its
`CustomButton` widget is a near-equivalent of waybar's `custom/*` module
(`textCommand` ≈ `exec`, `textIntervalMs` ≈ `interval`, `parseJson` ≈
`return-type: json`, `leftClickExec` ≈ `on-click`), but its JSON dialect differs:
there is no arbitrary `class`; color comes from `textColor`/`iconColor`
restricted to `{primary, secondary, tertiary, error, none}`.

## Decision

- **Port each readout to a `CustomButton`, keeping the shell scripts.** A new
  `rices/ember/noctalia-widgets.nix` owns `programs.noctalia-shell.settings.bar`
  (position + full `widgets` layout) and defines the six scripts;
  `noctalia.nix` keeps shell enable + theming.
- **Rewrite state coloring into Noctalia's 5-value vocabulary.** Alarms →
  `error`; live/active accents → `tertiary`/`secondary`; neutral → `none`. The
  scripts emit `{text, tooltip, textColor}` instead of `{..., class, alt}`.
- **`flights` keeps its external binary** (`flights-waybar`, from the `flights`
  flake input, which we cannot change) and gets a thin `jq` wrapper translating
  its `class` (`""`/`lost`/`stale`/`error`) into `textColor`.
- **The whole bar layout is Nix-owned**, declared in the pinned (read-only,
  `/nix/store`) `settings.json`. The layout mirrors the old waybar arrangement
  1:1; waybar's three stat pills (cpu / memory / temperature) become three
  single-metric `SystemMonitor` instances.

## Why

- **CustomButton is a ~90% match and keeps the scripts**, so the bespoke logic
  (hwmon discovery, ZFS/systemd health folding, hog sampling) is preserved
  verbatim rather than rewritten as QML plugins.
- **Nix-owned `settings.json` is the stack-native, declarative choice** and
  matches this repo's config-as-code stance. It is also *forced*: the theming
  integration needs `colorSchemes.predefinedScheme = ""` in `settings.json` to
  stop Noctalia regenerating `colors.json` over stylix's (see
  `project_stylix_noctalia_target`), and a single JSON file has exactly one
  owner — it cannot be both Nix-pinned and live-GUI-editable.
- **The red alarm — the only load-bearing color in CONTEXT.md — maps exactly**
  to `error`. The shades that collapse (green "ok", amber "stale", grey "lost")
  are informational, not alarms.

## Consequences

- **The bar is not editable in Noctalia's GUI.** Rearranging widgets there will
  not survive a `home-manager switch`. The workflow is "discover in the GUI on
  an unmanaged file, then enshrine the `bar.widgets` block in Nix."
- **Built-in cpu/mem pills lose threshold coloring** (waybar reddened at
  70/90 %); `SystemMonitor.textColor` is static. The hog widgets cover the
  "something is pegged" alarm instead.
- **Tooltips need post-port tuning** — column alignment depends on the fixed
  font, and markup escaping (`&amp;`/`&lt;`) is kept on the assumption Qt
  StyledText matches Pango; verify on first render.

## Rejected alternatives

- **Run a stripped waybar alongside Noctalia, just for these six.** Zero script
  changes and 100 % fidelity (exact hues, Pango tooltips, mono alignment), but
  two bars on screen and two theming systems — undercuts the "one shell" point
  of adopting Noctalia at all.
- **Rewrite each as a native Quickshell/QML plugin.** Best-looking and most
  controllable, but the most work by far and discards the working shell scripts
  for six small status readouts.

## Amendment (2026-07-19) — the v5 rewrite removed the mechanism

Noctalia v5 is a ground-up C++ rewrite. Its `custom_button` widget only *runs* a
command on click or scroll; it can no longer poll on an interval and render the
command's stdout as live text. `textCommand`, `parseJson` and `textIntervalMs`
— the three v4 properties this entire decision was built on — are gone, and
`settings.json` became `config.toml`.

So the port described above no longer exists:

- **`power`, `fans`, `cpu-hog`, `mem-hog`, `health`, `flights` are dropped.**
  The shell scripts went with them; `git log rices/ember/noctalia-widgets.nix`
  before 2026-07-19 has the bodies if any are ever wanted back.
- **The three stat pills survive**, now as v5's built-in `sysmon` widget.
- **"The bar layout is Nix-owned" survives** and is the part of this ADR still
  in force — `rices/ember/noctalia-widgets.nix` still owns the layout, just in
  `config.toml`. Note that Noctalia writes a `settings.toml` that overrides the
  Nix-pinned `config.toml`, so "Nix-owned" is now weaker than it was.

The consequence that matters beyond the bar: **`health` was the backup alarm
CONTEXT.md pointed at.** That role moved to a desktop notification fired by the
backup units themselves (`hosts/tempest/system/backup-notify.nix`) plus the
alert block in `sitrep` — push and pull respectively, instead of an always-visible
pill. CONTEXT.md's *alarm* entry records this.

Reviving any of the five would mean writing a v5 plugin: a `plugin.toml`
manifest with `[[widget]]` entries. The third rejected alternative above
("rewrite each as a native Quickshell/QML plugin") is, in effect, now the only
option left — the cheap path this ADR chose is the one upstream deleted.
