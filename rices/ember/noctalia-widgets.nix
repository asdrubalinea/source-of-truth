{
  lib,
  config,
  ...
}: let
  cfg = config.rices.ember;
in
  lib.mkIf cfg.enable {
    # Bar layout for the ember rice, merged into Noctalia's config.toml.
    #
    # IMPORTANT v4→v5 regression: Noctalia v5 is a ground-up C++ rewrite whose
    # `custom_button` widget only RUNS a command on click/scroll — it can no longer
    # poll a script on an interval and render its stdout as live text/JSON (v4's
    # CustomButton `textCommand`/`parseJson`/`textIntervalMs`). The five bespoke
    # readouts ported from waybar and documented in docs/adr/0003 (CPU-hog,
    # mem-hog, fan RPM, storage/backup-health, and the flights pill) therefore have
    # NO built-in v5 equivalent and were dropped in the v5 migration. The three
    # plain stat pills survive as the new `sysmon` widget. Reviving the bespoke
    # readouts would mean writing a Noctalia v5 plugin (a plugin.toml manifest with
    # [[widget]] entries) — see git history before this commit for the old script
    # bodies, and ADR 0003 for their rationale.
    programs.noctalia.settings = {
      # v5 supports multiple named bars; `bar.order` lists the active ones. We use
      # the single seeded "default" bar.
      bar.order = ["default"];
      bar.default = {
        position = "top";

        # Auto-hide the bar: it retracts to a 3px edge-trigger and slides back when
        # the pointer reaches the screen edge. Primary burn-in mitigation for the
        # tempest QD-OLED — a persistent bar is the worst static-content offender.
        # `reserve_space = false` is REQUIRED with auto_hide: it defaults to true,
        # which keeps the bar's compositor exclusive zone even while hidden, so
        # tiled/maximized windows stop below it and leave a dead wallpaper strip at
        # the top. With it false the bar is a true overlay and windows fill the full
        # height. Hot-reloads. Companion left alone: `smart_auto_hide` (stay visible
        # while the workspace is empty), which would only add static bar-time. See
        # docs/adr/0009.
        auto_hide = true;
        reserve_space = false;

        # …and DON'T flash it on every workspace change (`show_on_workspace_switch`
        # defaults to true — confirmed with `noctalia config export full`). That
        # reveal exists to tell you where you landed after a *relative* switch, but
        # every workspace bind in ./compositors/niri/niri.nix is absolute (Mod+1…Mod+0 →
        # focus-workspace = N) and Mod+E opens the overview, so it announced
        # something already known and then animated away. Off is also strictly less
        # on-screen time for the panel this bar hides itself to protect.
        show_on_workspace_switch = false;

        # EDGE TREATMENT. This is the desktop's edge treatment, not just the
        # bar's — see "bar" in CONTEXT.md. Window corner rounding
        # (./compositors/niri/window-rules.nix, and mango's border_radius) and
        # niri's top strut are all derived from these four values, so this is the
        # one place to change the desktop's geometric register; the derived ones
        # follow.
        #
        # Flush and square. A floating rounded strip is a *card* laid on the
        # wallpaper — it belongs to the wallpaper, and it forced two things to
        # match it: every window got a 12px radius, and niri had to leave an 8px
        # gap at the top so a square window corner wouldn't clash with the bar's
        # curve (a dead wallpaper strip, since the bar is an overlay and reserves
        # no space). At margin 0 / radius 0 the bar is part of the display edge
        # instead, both of those follow to 0/-8, and nothing has a corner that
        # can disagree with its neighbour.
        margin_edge = 0;
        margin_ends = 0;

        # All five radius keys, not just `radius`: `noctalia config export full`
        # reports radius_top_left/top_right/bottom_left/bottom_right as their own
        # values alongside it, and this config can't tell whether they derive
        # from `radius` or default independently. Setting all five costs four
        # lines and removes the question.
        radius = 0;
        radius_top_left = 0;
        radius_top_right = 0;
        radius_bottom_left = 0;
        radius_bottom_right = 0;

        # Concave corners are the flourish that makes a floating bar look joined
        # to the screen corner. With the bar already flush there is nothing to
        # join, and the notch reads as a rendering artefact.
        concave_edge_corners = false;

        # `border = "outline"` is the default but `border_width` defaults to 0.0,
        # so the outline was enabled and invisible. 1px at the bar's own outline
        # colour is the hairline that separates the strip from the window
        # underneath now that no margin does it.
        border_width = 1.0;

        # 14 → 8: padding was sized for a card with its own margin around it.
        # Flush against the edge, the same figure reads as slack.
        padding = 8;

        shadow = false;
        thickness = 32;

        # Lane entries are widget INSTANCE names; a bare name with no matching
        # [widget.<name>] table uses the name as its type, so "workspaces", "clock",
        # "battery", … resolve to stock widgets at their defaults. The three pills
        # in `start` override the seeded sysmon instances (below). The system Tray is
        # intentionally omitted from `end`, as in the old bar.
        start = ["workspaces" "cpu" "ram" "temp"];
        center = ["clock"];
        end = ["notifications" "battery" "volume" "brightness" "control-center"];
      };

      # The three readouts that map to a built-in: v4 SystemMonitor → v5 `sysmon`,
      # one instance per stat. v5 bakes percent-vs-value into the stat name
      # (`ram_pct`, not a showMemoryAsPercent flag) and dropped the per-widget
      # monospace/compact toggles. Poll intervals are global, under
      # [system.monitor] (defaults: cpu/memory 2s).
      #
      # `visualization = "none"` + `show_value = true` is the bare numeric pill:
      # no gauge, no graph, just the figure. These two keys used to be
      # `display = "text"` and `show_label = false`, which noctalia renamed and
      # which `noctalia config validate` had been warning about on every build:
      #
      #   WARN widget.cpu.display: display is now visualization and show_value
      #   WARN widget.cpu.show_label: show_label is now show_value
      #
      # A deprecated key is a WARNING, not an error, so all six were being parsed
      # and discarded — the pills only looked right because "bare numeric" is also
      # what the defaults produce. Stating the current keys makes the config mean
      # what it says, and takes the build from six warnings to none.
      widget.cpu = {
        type = "sysmon";
        stat = "cpu_usage";
        visualization = "none";
        show_value = true;
      };
      widget.ram = {
        type = "sysmon";
        stat = "ram_pct";
        visualization = "none";
        show_value = true;
      };
      widget.temp = {
        type = "sysmon";
        stat = "cpu_temp";
        visualization = "none";
        show_value = true;
      };
    };
  }
