{ config, lib, pkgs, inputs, hostname, ... }:
let
  # The flights radar package (TUI + waybar client), backed by the always-on
  # flights-server enabled in ../flights.nix.
  flights = inputs.flights.packages.${pkgs.system}.flights;

  # Detects sustained per-process CPU usage and surfaces the worst offender.
  # %CPU is per-core (so 100 = one full core pegged).
  cpuHogWatch = pkgs.writeShellScript "cpu-hog-watch" ''
    set -eu
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
      '{text: $text, tooltip: $tooltip, class: "hog", alt: "hog"}'
  '';

  # Detects processes holding lots of resident memory.
  # Threshold is %MEM (percent of total physical RAM).
  memHogWatch = pkgs.writeShellScript "mem-hog-watch" ''
    set -eu
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
      '{text: $text, tooltip: $tooltip, class: "hog", alt: "hog"}'
  '';

  # Reads fan RPMs from hwmon. Bar shows the max across fans; tooltip lists each.
  # hwmon indices reshuffle across boots, so we discover at runtime instead of
  # hardcoding a path.
  fanWatch = pkgs.writeShellScript "fan-watch" ''
    set -eu

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
      printf '{"text":"","tooltip":"no fan sensors","class":"off","alt":"off"}\n'
      exit 0
    fi

    max=$(printf '%s' "$rows" | ${pkgs.gawk}/bin/awk -F'\t' 'BEGIN{m=0} NF>=2 {if ($2+0 > m) m=$2+0} END{print m}')
    tooltip=$(printf '%s' "$rows" | ${pkgs.gawk}/bin/awk -F'\t' 'NF>=2 {printf "%-24s %5d rpm\n", $1, $2}')

    if [ "$max" -gt 0 ]; then class="on"; else class="off"; fi

    ${pkgs.jq}/bin/jq -nc \
      --arg text "󰈐 $max" \
      --arg tooltip "$tooltip" \
      --arg class "$class" \
      '{text: $text, tooltip: $tooltip, class: $class, alt: $class}'
  '';

  # Combined storage/backup health pill — always visible. Green check when the
  # internal pool is healthy AND neither backup unit has failed; red and naming
  # the problem(s) otherwise. Tooltip always lists every subsystem.
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

    borg_unit="borgbackup-job-home-irene.service"
    usb_unit="tempest-backup-external.service"

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
      | grep -F syncoid_tempest | sort -n | tail -1 | cut -f1)
    usb_last=$(ago "''${usb_epoch:-0}")

    problems=""
    if [ "$rpool_ok" = no ];      then problems="rpool $rpool_state"; fi
    if unit_failed "$borg_unit";  then problems="''${problems:+$problems, }borg"; fi
    if unit_failed "$usb_unit";   then problems="''${problems:+$problems, }syncoid"; fi

    if [ -z "$problems" ]; then header="󰄬 storage & backups healthy"; else header="󰀦 PROBLEMS: $problems"; fi

    tooltip=$(printf '%s\n\n%-12s %s\n%-12s %s\n%-12s %s\n%-12s %s' \
      "$header" \
      "rpool"      "$rpool_state · errors: $rpool_errors" \
      "last scrub" "$scrub" \
      "borg"       "$borg_stat · last $borg_last" \
      "USB backup" "$usb_stat · last $usb_last")

    # Waybar renders tooltips as Pango markup, so a literal '&' (or '<'/'>')
    # makes the whole tooltip fail to parse and show empty. Escape them.
    tooltip=''${tooltip//&/&amp;}
    tooltip=''${tooltip//</&lt;}
    tooltip=''${tooltip//>/&gt;}

    if [ -z "$problems" ]; then
      jq -nc --arg tooltip "$tooltip" '{text: "󰄬", tooltip: $tooltip, class: "ok", alt: "ok"}'
    else
      jq -nc --arg text "󰀦 $problems" --arg tooltip "$tooltip" \
        '{text: $text, tooltip: $tooltip, class: "failed", alt: "failed"}'
    fi
  '';

  c = config.lib.stylix.colors.withHashtag;
  monoFont = config.stylix.fonts.monospace.name;

  baseSettings = lib.importJSON ./config.jsonc;
  withHogModules = map (bar: bar // {
    "modules-left" = bar."modules-left" ++ [ "custom/fans" "custom/cpu-hog" "custom/mem-hog" "custom/health" ];
    "modules-center" = [ "custom/flights" ] ++ bar."modules-center";
    "cpu" = bar."cpu" // {
      states = { warning = 70; critical = 90; };
    };
    "memory" = bar."memory" // {
      states = { warning = 70; critical = 90; };
    };
    "custom/fans" = {
      exec = "${fanWatch}";
      return-type = "json";
      interval = 2;
      tooltip = true;
    };
    "custom/health" = {
      exec = "${healthWatch}";
      return-type = "json";
      interval = 60;
      tooltip = true;
      # Click → a one-shot snapshot of everything, then an interactive shell.
      on-click = "${pkgs.kitty}/bin/kitty --single-instance -e ${pkgs.fish}/bin/fish -C '${pkgs.zfs}/bin/zpool status -v; ${pkgs.systemd}/bin/systemctl --no-pager --full status borgbackup-job-home-irene.service tempest-backup-external.service'";
    };
    "custom/cpu-hog" = {
      exec = "${cpuHogWatch}";
      return-type = "json";
      interval = 10;
      on-click = "${pkgs.kitty}/bin/kitty --single-instance -e ${pkgs.btop}/bin/btop";
    };
    "custom/mem-hog" = {
      exec = "${memHogWatch}";
      return-type = "json";
      interval = 10;
      on-click = "${pkgs.kitty}/bin/kitty --single-instance -e ${pkgs.btop}/bin/btop";
    };
    # Nearest flight overhead — reads the always-on flights-server (../flights.nix).
    # Empty when the sky is clear; click to open the full radar TUI.
    "custom/flights" = {
      exec = "${flights}/bin/flights-waybar";
      return-type = "json";
      interval = 5;
      on-click = "${pkgs.kitty}/bin/kitty --single-instance -e ${flights}/bin/flights";
    };
  }) baseSettings;
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = withHogModules;
    style = ''
      * {
        border: none;
        border-radius: 0;
        min-height: 0;
        font-family: "${monoFont}", monospace;
        font-weight: bold;
        font-size: 14px;
        padding: 0;
      }

      window#waybar {
        background-color: ${c.base00};
      }

      tooltip {
        background-color: ${c.base01};
        border: 2px solid ${c.base03};
      }

      #clock,
      #tray,
      #cpu,
      #memory,
      #battery,
      #language,
      #backlight,
      #temperature,
      #custom-fans,
      #custom-power,
      #network,
      #pulseaudio {
        padding: 4px 10px;
      }

      #workspaces {
        background-color: ${c.base00};
      }

      #workspaces button {
        all: initial;
        min-width: 0;
        box-shadow: inset 0 -3px transparent;
        padding: 4px 10px;
        color: ${c.base0E};
      }

      #workspaces button.active {
        color: ${c.base05};
      }

      #workspaces button.urgent {
        background-color: ${c.base08};
      }

      #clock {
        background-color: ${c.base00};
        color: ${c.base05};
      }

      #tray {
        background-color: ${c.base00};
      }

      #battery,
      #battery.charging,
      #battery.plugged,
      #custom-fans.on {
        background-color: ${c.base00};
        color: ${c.base0B};
      }

      #cpu,
      #memory,
      #network,
      #language,
      #backlight,
      #temperature,
      #custom-power,
      #pulseaudio {
        background-color: ${c.base00};
        color: ${c.base0E};
      }

      #cpu.critical,
      #memory.critical,
      #temperature.critical,
      #custom-fans.off,
      #custom-fans {
        background-color: ${c.base00};
        color: ${c.base08};
      }

      #battery.warning,
      #battery.critical,
      #battery.urgent {
        background-color: ${c.base00};
        color: ${c.base08};
      }

      #custom-cpu-hog,
      #custom-mem-hog {
        background-color: ${c.base00};
        color: ${c.base0E};
        padding: 4px 10px;
      }

      #custom-cpu-hog.hog,
      #custom-mem-hog.hog {
        background-color: ${c.base08};
        color: ${c.base00};
      }

      /* combined storage/backup health pill — green check when all is well,
         red alarm naming the problem otherwise (always visible) */
      #custom-health {
        background-color: ${c.base00};
        padding: 4px 10px;
      }

      #custom-health.ok {
        color: ${c.base0B};
      }

      #custom-health.failed {
        background-color: ${c.base08};
        color: ${c.base00};
      }

      /* live nearest flight — bright cyan accent so it stands out in the centre */
      #custom-flights {
        background-color: ${c.base00};
        color: ${c.base0C};
        font-weight: bold;
        padding: 4px 10px;
      }

      /* nearest flight froze: retained and badged, never dropped */
      #custom-flights.lost {
        color: ${c.base03};
      }

      /* the whole picture has aged */
      #custom-flights.stale {
        color: ${c.base0A};
      }

      /* server unreachable / no data */
      #custom-flights.error {
        color: ${c.base08};
      }
    '';
  };
}
