# niri rice becomes an enable-options Home-Manager module; machine policy factored out

Status: accepted (2026-06-05)

## Context

The niri rice (`rices/niri/`, ~1.5k lines) is wired in two halves: a 3-line
system half (`system.nix`, `programs.niri.enable` + fish + fonts) imported by
`hosts/tempest/default.nix`, and the home half (`default.nix`) imported by
`homes/tempest/default.nix`. There is exactly one consumer — tempest. orchid runs
estradiol/hyprland by choice.

The idea on the table was "split the wm/ui stuff into its own flake/module."
Examined against four stated motivations, the flake half collapsed:

- **Reuse across machines** — no real second consumer; ~670 lines (kanshi
  monitor serials, the backup-health readout, a `hostname == "tempest"` theme
  branch) are tempest-specific anyway.
- **Independent version pinning** — the only UI input *exclusive* to the rice
  is `noctalia`; `stylix`/`hyprland` already ride `update-home`, and `niri` is
  a shared *system* module (tempest + orchid), so pinning it in a sub-flake
  would split-brain the closure. Net: not needed.
- **Faster eval/rebuild** — a separate input does not speed up eval; it adds a
  lock + `follows` overhead.
- **Cleaner mental model** — real, but an in-repo concern, not a flake.

What survived was the wish for a single thing to *enable*.

## Decision

- **`rices.niri.enable`** — a Home-Manager module wrapping the entire home half
  behind `lib.mkIf`. Set in `homes/tempest/default.nix`. This deliberately deviates
  from the repo convention (CLAUDE.md: "no central enable-options layer; host
  composition is explicit `imports`"). The only prior options module is
  `options/passthrough.nix` (`vfio.enable`).
- **The system half stays a plain import.** `programs.niri.enable` must live at
  the NixOS level (package + Wayland session + portals/polkit); the HM module
  only writes config. Under standalone HM the two layers activate separately
  anyway, so "one enable spanning both" is not achievable without reverting the
  standalone-HM migration — which we are not doing.
- **Monitors are machine policy, factored out of the rice.** kanshi (the
  hard-coded BOE/Samsung/LG serials and modes) moves to
  `homes/tempest/monitors.nix`. kanshi is compositor-agnostic and per-machine,
  so it does not belong in a module whose job is "give me my desktop." See the
  *rice* / *machine policy* terms in CONTEXT.md.
- **The backup-health readout stays in the rice but becomes portable.** It is
  one of five bar readouts woven into a single layout (the other four are
  generic), so it is not cleanly separable like kanshi. Its watched systemd
  unit names become an option defaulting to tempest's units, and the readout
  collapses to nothing when those units are absent on a host — rather than
  going red (a false alarm) as it would today.

## Why

- With one consumer, a bare `enable` is ceremony — `imports` already toggles
  the rice. The value is the *boundary* it forces: an explicit `enable` makes
  the seam between "my desktop" (portable) and "this machine" (kanshi, backup
  units) legible, and pushes the per-host facts out to where they belong.
- Factoring monitors out is cheap and unambiguous (own file, zero coupling).
  Generalizing the backup widget is bounded to "option + graceful default" —
  not a generic backup abstraction, which would be building for a phantom host.

## Consequences

- The repo now has **two** options modules against a convention that claimed it
  had none. CLAUDE.md's "no options layer" statement has been softened to note
  that options are the deliberate exception, used for `vfio` and the niri rice.
- Enabling the desktop is still **two touch-points** (host import for the
  system half, `rices.niri.enable` for the home half) — inherent to standalone
  HM, not a wart of this design.
- `homes/` gains a per-host *directory* pattern: a host with machine policy
  beyond its main config grows from a flat `homes/<host>.nix` into
  `homes/<host>/` (`default.nix` + e.g. `monitors.nix`). tempest is the first;
  orchid stays a flat file until it needs the same.

## Rejected alternatives

- **Separate flake** for the wm/ui. No consumer, nothing cleanly isolatable
  (only `noctalia`), no closure win, and a second `flake.lock` to tend. All
  four motivations for it collapsed under inspection.
- **Symmetric `enable` in both the NixOS and HM layers.** More boilerplate for
  the same two-activation reality; the system half is 3 lines.
- **Factor the backup widget out like kanshi.** Would mean splitting the
  five-readout layout and exposing a host-injected widget hook — disproportionate
  surgery for one tempest-specific readout that is, by the boundary we drew,
  part of the bar (the shell = the WM).
