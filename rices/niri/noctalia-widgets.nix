{ lib, config, ... }:
let
  cfg = config.rices.niri;
in
lib.mkIf cfg.enable {
  # Bar layout for the niri rice, merged into Noctalia's config.toml.
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
    bar.order = [ "default" ];
    bar.default = {
      position = "top";

      # Auto-hide the bar: it retracts to a 3px edge-trigger and slides back when
      # the pointer reaches the screen edge. Primary burn-in mitigation for the
      # tempest QD-OLED — a persistent bar is the worst static-content offender.
      # `reserve_space = false` is REQUIRED with auto_hide: it defaults to true,
      # which keeps the bar's compositor exclusive zone even while hidden, so
      # tiled/maximized windows stop below it and leave a dead wallpaper strip at
      # the top. With it false the bar is a true overlay and windows fill the full
      # height. Hot-reloads. Companions if wanted: `smart_auto_hide` (stay visible
      # only while the workspace is empty) and `show_on_workspace_switch`
      # (default: flash on switch). See docs/adr/0009.
      auto_hide = true;
      reserve_space = false;

      margin_edge = 8;
      margin_ends = 8;
      radius = 12;
      shadow = false;
      thickness = 32;

      # Lane entries are widget INSTANCE names; a bare name with no matching
      # [widget.<name>] table uses the name as its type, so "workspaces", "clock",
      # "battery", … resolve to stock widgets at their defaults. The three pills
      # in `start` override the seeded sysmon instances (below). The system Tray is
      # intentionally omitted from `end`, as in the old bar.
      start = [ "workspaces" "cpu" "ram" "temp" ];
      center = [ "clock" ];
      end = [ "notifications" "battery" "volume" "brightness" "control-center" ];
    };

    # The three readouts that map to a built-in: v4 SystemMonitor → v5 `sysmon`,
    # one instance per stat. v5 bakes percent-vs-value into the stat name
    # (`ram_pct`, not a showMemoryAsPercent flag) and dropped the per-widget
    # monospace/compact toggles. `display = "text"` shows the numeric value;
    # `show_label = false` keeps it bare (no leading glyph), matching the old
    # numeric pills. Poll intervals are global, under [system.monitor] (defaults:
    # cpu/memory 2s).
    widget.cpu = {
      type = "sysmon";
      stat = "cpu_usage";
      display = "text";
      show_label = false;
    };
    widget.ram = {
      type = "sysmon";
      stat = "ram_pct";
      display = "text";
      show_label = false;
    };
    widget.temp = {
      type = "sysmon";
      stat = "cpu_temp";
      display = "text";
      show_label = false;
    };
  };
}
