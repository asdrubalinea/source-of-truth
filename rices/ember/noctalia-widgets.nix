{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.rices.ember;
  noctalia = lib.getExe config.programs.noctalia.package;

  # Even ISO weeks top, odd weeks bottom: spreads the always-on bar's static
  # wear over two strips of the QD-OLED instead of one. config-set writes the
  # state-dir settings.toml override, which beats `position` below and survives
  # restarts. shortcut: a 53-week year gives two odd weeks back to back.
  barFlip = pkgs.writeShellScript "noctalia-bar-flip" ''
    if (( 10#$(${pkgs.coreutils}/bin/date +%V) % 2 )); then pos=bottom; else pos=top; fi
    exec ${noctalia} msg config-set bar.default.position "'$pos'"
  '';
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
        # Baseline only — flipped weekly by noctalia-bar-flip below.
        position = "top";

        # Always visible, by choice, despite the QD-OLED: a persistent bar is the
        # worst static-content offender, and auto-hiding it was ADR 0009's
        # primary burn-in mitigation. If burn-in shows, go back to
        # `auto_hide = true` with `reserve_space = false` (a hidden bar that
        # still reserves its exclusive zone leaves a dead wallpaper strip).
        auto_hide = false;
        reserve_space = true;

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

    # Fires Monday 00:00 (Persistent catches a week the machine slept through),
    # and on every noctalia start, retrying until its IPC socket is up.
    systemd.user.services.noctalia-bar-flip = {
      Unit = {
        Description = "Alternate the noctalia bar between top and bottom by week";
        After = ["noctalia.service"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${barFlip}";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install.WantedBy = ["noctalia.service"];
    };
    systemd.user.timers.noctalia-bar-flip = {
      Timer = {
        OnCalendar = "Mon *-*-* 00:00:00";
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  }
