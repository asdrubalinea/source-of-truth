{
  lib,
  config,
  ...
}: let
  cfg = config.rices.ember;
in
  lib.mkIf cfg.enable {
    # Bar layout, merged into Noctalia's config.toml.
    #
    # v4→v5 REGRESSION: v5's `custom_button` only runs a command on click — it
    # can no longer poll a script and render its stdout, so the five bespoke
    # readouts of ADR 0003 (CPU/mem hog, fan RPM, backup health, flights) have
    # no v5 equivalent and were dropped. Reviving them means writing a v5 plugin;
    # the old script bodies are in git history before that migration.
    programs.noctalia.settings = {
      # v5 supports multiple named bars; `order` lists the active ones.
      bar.order = ["default"];
      bar.default = {
        position = "top";

        # Primary burn-in mitigation for the QD-OLED — a persistent bar is the
        # worst static-content offender (ADR 0009). `reserve_space = false` is
        # REQUIRED alongside it: the default true keeps the exclusive zone even
        # while hidden, so windows stop below it and leave a dead wallpaper
        # strip. `smart_auto_hide` is deliberately left alone; it would only add
        # static bar-time.
        auto_hide = true;
        reserve_space = false;

        # …and don't flash it on every workspace change (defaults to true). That
        # reveal exists to announce where a *relative* switch landed, but every
        # workspace bind here is absolute, so it announced the already-known and
        # animated away. Off is also strictly less on-screen time.
        show_on_workspace_switch = false;

        # THE DESKTOP'S EDGE TREATMENT, not just the bar's (CONTEXT.md: "bar").
        # Window corner rounding and niri's top strut are derived from these
        # four values, so this is the one place to change the geometric
        # register — the derived ones follow.
        #
        # Flush and square: a floating rounded strip is a *card* on the
        # wallpaper, and it forced a 12px radius on every window plus an 8px
        # top gap so square corners wouldn't clash with its curve. At 0 the bar
        # is part of the display edge and nothing has a corner that can disagree
        # with its neighbour.
        margin_edge = 0;
        margin_ends = 0;

        # All five keys, not just `radius`: noctalia reports the four corners as
        # their own values and this config can't tell whether they derive from
        # `radius` or default independently. Four lines removes the question.
        radius = 0;
        radius_top_left = 0;
        radius_top_right = 0;
        radius_bottom_left = 0;
        radius_bottom_right = 0;

        # The flourish that joins a floating bar to the screen corner. Already
        # flush, there is nothing to join and the notch reads as an artefact.
        concave_edge_corners = false;

        # `border = "outline"` is the default but `border_width` defaults to 0,
        # so the outline was enabled and invisible. 1px is the hairline that
        # separates the strip from the window now that no margin does.
        border_width = 1.0;

        # 14 → 8: the old figure was sized for a card with margin around it.
        padding = 8;

        shadow = false;
        thickness = 32;

        # Lane entries are widget INSTANCE names; a bare name with no matching
        # [widget.<name>] table uses the name as its type, so these resolve to
        # stock widgets at their defaults. The three pills in `start` override
        # the sysmon instances below. The system tray is intentionally omitted.
        start = ["workspaces" "cpu" "ram" "temp"];
        center = ["clock"];
        end = ["notifications" "battery" "volume" "brightness" "control-center"];
      };

      # The three readouts that map to a built-in: v4 SystemMonitor → v5
      # `sysmon`, one instance per stat. v5 bakes percent-vs-value into the stat
      # name and dropped the per-widget monospace/compact toggles; poll
      # intervals are global under [system.monitor].
      #
      # `visualization = "none"` + `show_value = true` is the bare numeric pill.
      # These were `display`/`show_label`, which noctalia renamed — and a
      # deprecated key is a WARNING, not an error, so all six were being parsed
      # and discarded. The pills only looked right because "bare numeric" is
      # also what the defaults produce.
      widget.cpu = {
        type = "sysmon";
        stat = "cpu_usage";
        visualization = "none";
        show_value = true;
      };
      # `ram_used`, not `ram_pct`: a percentage of an unstated total is
      # unreadable here, because the total isn't what's installed and "used"
      # isn't what's in use — ARC, amdgpu's GTT and the zswap pool all count
      # against it. Noctalia computes MemTotal - MemAvailable and renders binary
      # GiB; the unit is not configurable, and the used/total pair is
      # control-center-only.
      widget.ram = {
        type = "sysmon";
        stat = "ram_used";
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
