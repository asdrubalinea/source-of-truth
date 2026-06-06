{ lib, pkgs, inputs, config, ... }:
let
  cfg = config.rices.niri;

  # The flights radar package (TUI + waybar client), backed by the always-on
  # flights-server enabled in ./flights.nix.
  flights = inputs.flights.packages.${pkgs.system}.flights;

  # ── Five bespoke readouts ported from waybar ──────────────────────────────
  # Each was a shell script emitting waybar JSON ({text, tooltip, class, alt}),
  # styled per-class into stylix colors. Noctalia's CustomButton has no
  # arbitrary `class`; color comes from `textColor` restricted to
  # {primary, secondary, tertiary, error, none}. So the script bodies are kept
  # verbatim — only the final JSON emission is rewritten into that vocabulary.
  # See docs/adr/0003-noctalia-custom-bar-readouts.md.

  # Detects sustained per-process CPU usage and surfaces the worst offender.
  # %CPU is per-core (so 100 = one full core pegged). Collapses when idle.
  cpuHogWatch = pkgs.writeShellScript "cpu-hog-watch" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}   # for bare sort/head/echo
    threshold=''${THRESHOLD:-70}

    # Two iterations 1s apart — first is lifetime avg (useless), second is real-time delta.
    sample=$(${pkgs.procps}/bin/top -bn2 -d 1 -o %CPU -w 200 | ${pkgs.gawk}/bin/awk '
      /^top - / { it++; next }
      it == 2 && $1 ~ /^[0-9]+$/ { print }
    ')

    hogs=$(echo "$sample" | ${pkgs.gawk}/bin/awk -v t="$threshold" '
      $9+0 > t { printf "%s %s\n", $9, $12 }
    ' | sort -rn)

    if [ -z "$hogs" ]; then
      printf '{"text":""}\n'
      exit 0
    fi

    worst=$(echo "$hogs" | head -n1)
    cpu=$(echo "$worst" | ${pkgs.gawk}/bin/awk '{print $1}')
    cmd=$(echo "$worst" | ${pkgs.gawk}/bin/awk '{print $2}')
    tooltip=$(echo "$hogs" | head -n5 | ${pkgs.gawk}/bin/awk '{printf "%5s%%  %s\n", $1, $2}')

    ${pkgs.jq}/bin/jq -nc \
      --arg text "⚠ $cmd $cpu%" \
      --arg tooltip "$tooltip" \
      '{text: $text, tooltip: $tooltip, textColor: "error"}'
  '';

  # Detects processes holding lots of resident memory. Collapses when idle.
  # Threshold is %MEM (percent of total physical RAM).
  memHogWatch = pkgs.writeShellScript "mem-hog-watch" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}   # for bare sort/head/echo
    threshold=''${THRESHOLD:-10}

    # ps gives current RSS — no sampling needed.
    hogs=$(${pkgs.procps}/bin/ps -eo pmem,rss,comm --sort=-rss --no-headers \
      | ${pkgs.gawk}/bin/awk -v t="$threshold" '$1+0 > t { print }')

    if [ -z "$hogs" ]; then
      printf '{"text":""}\n'
      exit 0
    fi

    worst=$(echo "$hogs" | head -n1)
    rss_kb=$(echo "$worst" | ${pkgs.gawk}/bin/awk '{print $2}')
    cmd=$(echo "$worst" | ${pkgs.gawk}/bin/awk '{print $3}')
    rss_human=$(${pkgs.gawk}/bin/awk -v k="$rss_kb" 'BEGIN {
      if (k >= 1048576) printf "%.1fG", k/1048576;
      else printf "%dM", k/1024;
    }')

    tooltip=$(echo "$hogs" | head -n5 | ${pkgs.gawk}/bin/awk '{
      if ($2 >= 1048576) mem = sprintf("%.1fG", $2/1048576);
      else mem = sprintf("%dM", $2/1024);
      printf "%6s  %s\n", mem, $3
    }')

    ${pkgs.jq}/bin/jq -nc \
      --arg text "⚠ $cmd $rss_human" \
      --arg tooltip "$tooltip" \
      '{text: $text, tooltip: $tooltip, textColor: "error"}'
  '';

  # Reads fan RPMs from hwmon. Bar shows the max across fans; tooltip lists each.
  # hwmon indices reshuffle across boots, so we discover at runtime instead of
  # hardcoding a path. Spinning ⇒ tertiary accent; idle ⇒ default color.
  fanWatch = pkgs.writeShellScript "fan-watch" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils ]}   # for bare cat/dirname/basename

    rows=""
    for input in /sys/class/hwmon/hwmon*/fan*_input; do
      [ -r "$input" ] || continue
      rpm=$(cat "$input" 2>/dev/null || echo "")
      case "$rpm" in ""|*[!0-9]*) continue ;; esac

      dir=$(dirname "$input")
      base=$(basename "$input" _input)
      chip=$(cat "$dir/name" 2>/dev/null || basename "$dir")
      label=$(cat "$dir/''${base}_label" 2>/dev/null || echo "$base")
      rows="$rows''${chip}/''${label}	''${rpm}
    "
    done

    if [ -z "$rows" ]; then
      printf '{"text":"","tooltip":"no fan sensors"}\n'
      exit 0
    fi

    max=$(printf '%s' "$rows" | ${pkgs.gawk}/bin/awk -F'\t' 'BEGIN{m=0} NF>=2 {if ($2+0 > m) m=$2+0} END{print m}')
    tooltip=$(printf '%s' "$rows" | ${pkgs.gawk}/bin/awk -F'\t' 'NF>=2 {printf "%-24s %5d rpm\n", $1, $2}')

    if [ "$max" -gt 0 ]; then
      ${pkgs.jq}/bin/jq -nc \
        --arg text "󰈐 $max" \
        --arg tooltip "$tooltip" \
        '{text: $text, tooltip: $tooltip, textColor: "tertiary"}'
    else
      ${pkgs.jq}/bin/jq -nc \
        --arg text "󰈐 $max" \
        --arg tooltip "$tooltip" \
        '{text: $text, tooltip: $tooltip}'
    fi
  '';

  # Combined storage/backup health pill — always visible. A shield-check icon
  # when the internal pool is healthy AND neither backup unit has failed; a red
  # shield-x naming the problem(s) otherwise. Tooltip always lists every
  # subsystem.
  #
  # Signals it folds together:
  #  - rpool: `zpool status -x` flags not just DEGRADED/FAULTED but
  #    checksum/read/write and scrub-found errors even while the pool reads
  #    ONLINE. Scoped to rpool — the external backup pool is exported except
  #    during a run, so its integrity is gated inside tempest-backup-external
  #    (system/backup-external.nix), surfacing here as a syncoid unit failure.
  #  - borg / syncoid units: both oneshots, so systemd latches `failed` until
  #    the next good run. A unit that never ran reports `inactive` (not
  #    `failed`), so a fresh boot or unrelated host never false-alarms.
  # All checks are unprivileged.
  healthWatch = pkgs.writeShellScript "health-watch" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.gnugrep pkgs.gawk pkgs.systemd pkgs.zfs pkgs.jq ]}

    borg_unit="${cfg.backupWidget.borgUnit}"
    usb_unit="${cfg.backupWidget.usbUnit}"

    unit_failed() { [ "$(systemctl is-failed "$1" 2>/dev/null || true)" = failed ]; }

    # Epoch of a unit's last finish. Falls back to the matching .timer's last
    # trigger, which survives reboots (the service's InactiveEnterTimestamp
    # resets each boot). 0 if it has genuinely never run.
    unit_last_epoch() {
      ts=$(systemctl show -p InactiveEnterTimestamp --value "$1" 2>/dev/null || true)
      [ -n "$ts" ] || ts=$(systemctl show -p LastTriggerUSec --value "''${1%.service}.timer" 2>/dev/null || true)
      [ -n "$ts" ] || { echo 0; return; }
      date -d "$ts" +%s 2>/dev/null || echo 0
    }

    # Epoch -> "Xh ago"; 0/blank -> "never".
    ago() {
      e=''${1:-0}
      [ "$e" -gt 0 ] 2>/dev/null || { echo never; return; }
      now=$(date +%s); d=$(( now - e ))
      if   [ "$d" -lt 0 ];     then echo "just now"
      elif [ "$d" -lt 3600 ];  then echo "$(( d / 60 ))m ago"
      elif [ "$d" -lt 86400 ]; then echo "$(( d / 3600 ))h ago"
      else echo "$(( d / 86400 ))d ago"
      fi
    }

    # Machine-policy guard: this readout describes a specific host's backup legs
    # (and its root pool). On a host where NEITHER configured backup unit exists
    # (LoadState not-found), there is nothing here to describe — collapse to
    # empty rather than false-alarming on the absent units or a foreign rpool.
    loaded() { [ "$(systemctl show -p LoadState --value "$1" 2>/dev/null || true)" = loaded ]; }
    if ! loaded "$borg_unit" && ! loaded "$usb_unit"; then
      printf '{"text":""}\n'
      exit 0
    fi

    # rpool: status -x catches checksum/read/write/scrub errors even while ONLINE.
    rpool_state=$(zpool list -H -o health rpool 2>/dev/null || echo "?")
    if zpool status -x rpool 2>/dev/null | grep -q "is healthy"; then rpool_ok=yes; else rpool_ok=no; fi
    rpool_errors=$(zpool status rpool 2>/dev/null | awk -F'errors: ' '/^errors:/ {print $2}')
    [ -n "$rpool_errors" ] || rpool_errors="—"
    scrub=$(zpool status rpool 2>/dev/null | awk -F' on ' '/scan:/ {print $2}')
    [ -n "$scrub" ] || scrub="never"

    # borg: oneshot last-finish time is a faithful "last backup" (it never no-ops).
    if unit_failed "$borg_unit"; then borg_stat=FAILED; else borg_stat=ok; fi
    borg_last=$(ago "$(unit_last_epoch "$borg_unit")")

    # USB: the syncoid service no-ops when the drive is absent, so its run time
    # lies. The truthful "last backup" is the newest syncoid_* sync-snapshot on
    # the SOURCE (always readable, created only on a real replication).
    if unit_failed "$usb_unit"; then usb_stat=FAILED; else usb_stat=ok; fi
    usb_epoch=$(zfs list -H -p -t snapshot -o creation,name 2>/dev/null \
      | grep -F "${cfg.backupWidget.syncoidSnapshotPrefix}" | sort -n | tail -1 | cut -f1)
    usb_last=$(ago "''${usb_epoch:-0}")

    problems=""
    if [ "$rpool_ok" = no ];      then problems="rpool $rpool_state"; fi
    if unit_failed "$borg_unit";  then problems="''${problems:+$problems, }borg"; fi
    if unit_failed "$usb_unit";   then problems="''${problems:+$problems, }syncoid"; fi

    if [ -z "$problems" ]; then header="󰄬 storage & backups healthy"; else header="󰀦 PROBLEMS: $problems"; fi

    # Raw tooltip — Noctalia's CustomButton HTML-escapes it itself (toHtml),
    # so unlike waybar we must NOT pre-escape '&'/'<'/'>' (that double-escapes).
    tooltip=$(printf '%s\n\n%-12s %s\n%-12s %s\n%-12s %s\n%-12s %s' \
      "$header" \
      "rpool"      "$rpool_state · errors: $rpool_errors" \
      "last scrub" "$scrub" \
      "borg"       "$borg_stat · last $borg_last" \
      "USB backup" "$usb_stat · last $usb_last")

    # Render the state as an ICON (Tabler name → NIcon), not a text glyph: a
    # text-only CustomButton pads the pill with pillOverlap dead space (it's
    # meant to tuck under an icon disc), which on a one-glyph readout shows as
    # blank space beside the mark. Healthy ⇒ icon only, so the pill collapses to
    # a clean circular disc; problem ⇒ icon + expanding red text.
    if [ -z "$problems" ]; then
      jq -nc --arg tooltip "$tooltip" '{icon: "shield-check", tooltip: $tooltip}'
    else
      jq -nc --arg text "$problems" --arg tooltip "$tooltip" \
        '{icon: "shield-x", text: $text, tooltip: $tooltip, iconColor: "error", textColor: "error"}'
    fi
  '';

  # ── Widget builders ────────────────────────────────────────────────────────
  # A CustomButton instance: our scripts carry their own glyphs, so showIcon is
  # off; leftClickUpdateText is off so a click never silently re-runs the poll;
  # showExecTooltip is off so the tooltip stays the script's own text (waybar
  # never dumped the click command — which here is a noisy /nix/store path).
  customButton = attrs: {
    id = "CustomButton";
    showIcon = false;
    leftClickUpdateText = false;
    showExecTooltip = false;
  } // attrs;

  # A single-metric SystemMonitor pill. Every show* flag is set explicitly
  # because the registry defaults turn several on (cpu usage + temp + memory).
  # compactMode MUST be false: it defaults true in the registry, and in compact
  # mode the pill draws a mini bar-gauge (NText is `visible:!compactMode`)
  # instead of the numeric "57%" / "62°C" text this rice wants.
  sysMonitor = shown: {
    id = "SystemMonitor";
    compactMode = false;
    useMonospaceFont = true;
    showCpuUsage = false;
    showCpuTemp = false;
    showMemoryUsage = false;
    showMemoryAsPercent = false;
  } // shown;
in
lib.mkIf cfg.enable {
  programs.noctalia-shell.settings.bar = {
    position = "top";

    # Floating bar: detach from the screen edges with a margin on every side and
    # rounded corners. barType "floating" is what makes Noctalia actually honour
    # marginVertical/marginHorizontal — they're inert in the default "simple"
    # mode (Bar.qml/BarExclusionZone.qml gate them on barType==="floating"), and
    # a floating bar always gets simple rounded corners regardless of
    # outerCorners. niri's windows are gapped + corner-rounded to match (see
    # niri.nix layout.gaps and window-rules.nix geometry-corner-radius); the
    # margins here equal niri's gap so window columns line up with the bar edges.
    barType = "floating";
    marginVertical = 8;
    marginHorizontal = 8;

    # Mirrors the old waybar arrangement 1:1. CustomButton/SystemMonitor IDs are
    # the QML component names; per-instance keys override BarWidgetRegistry
    # defaults. textColor in scripts is restricted to the 5-value vocabulary.
    widgets = {
      left = [
        { id = "Workspace"; }
        (sysMonitor { showCpuUsage = true; })
        (sysMonitor { showMemoryUsage = true; showMemoryAsPercent = true; })
        (sysMonitor { showCpuTemp = true; })
        (customButton {
          textCommand = "${fanWatch}";
          parseJson = true;
          textIntervalMs = 2000;
          hideMode = "alwaysExpanded";
        })
        (customButton {
          textCommand = "${cpuHogWatch}";
          parseJson = true;
          textIntervalMs = 10000;
          hideMode = "expandWithOutput";
          leftClickExec = "${pkgs.kitty}/bin/kitty --single-instance -e ${pkgs.btop}/bin/btop";
        })
        (customButton {
          textCommand = "${memHogWatch}";
          parseJson = true;
          textIntervalMs = 10000;
          hideMode = "expandWithOutput";
          leftClickExec = "${pkgs.kitty}/bin/kitty --single-instance -e ${pkgs.btop}/bin/btop";
        })
        (customButton {
          textCommand = "${healthWatch}";
          parseJson = true;
          textIntervalMs = 60000;
          hideMode = "alwaysExpanded";
          showIcon = true; # render shield-check / shield-x via the icon slot
          # Click → a one-shot snapshot of everything, then an interactive shell.
          leftClickExec = "${pkgs.kitty}/bin/kitty --single-instance -e ${pkgs.fish}/bin/fish -C '${pkgs.zfs}/bin/zpool status -v; ${pkgs.systemd}/bin/systemctl --no-pager --full status ${cfg.backupWidget.borgUnit} ${cfg.backupWidget.usbUnit}'";
        })
      ];

      center = [
        # Nearest flight overhead — reads the always-on flights-server
        # (./flights.nix). flights-waybar emits {text, tooltip, class}; the jq
        # wrapper folds its class into Noctalia's textColor vocabulary. Empty
        # when the sky is clear (collapses); click to open the full radar TUI.
        # TEMPORARILY DISABLED — re-add this block to restore the flights pill.
        # (customButton {
        #   textCommand = "${flights}/bin/flights-waybar | ${pkgs.jq}/bin/jq -c '{text, tooltip, textColor: ({\"\":\"tertiary\",\"stale\":\"secondary\",\"lost\":\"none\",\"error\":\"error\"}[.class] // \"none\")}'";
        #   parseJson = true;
        #   textIntervalMs = 5000;
        #   hideMode = "expandWithOutput";
        #   leftClickExec = "${pkgs.kitty}/bin/kitty --single-instance -e ${flights}/bin/flights";
        # })
        { id = "Clock"; }
      ];

      # Noctalia's stock right section. The ported readouts all sit on the
      # left/center; the right is left to Noctalia's own widgets. The system
      # Tray is intentionally omitted.
      right = [
        { id = "NotificationHistory"; }
        { id = "Battery"; }
        { id = "Volume"; }
        { id = "Brightness"; }
        { id = "ControlCenter"; }
      ];
    };
  };
}
