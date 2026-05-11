{ config, lib, pkgs, hostname, ... }:
let
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

  c = config.lib.stylix.colors.withHashtag;
  monoFont = config.stylix.fonts.monospace.name;

  baseSettings = lib.importJSON ./config.jsonc;
  withHogModules = map (bar: bar // {
    "modules-left" = bar."modules-left" ++ [ "custom/fans" "custom/cpu-hog" "custom/mem-hog" ];
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
    "custom/cpu-hog" = {
      exec = "${cpuHogWatch}";
      return-type = "json";
      interval = 10;
      on-click = "${pkgs.kitty}/bin/kitty -e ${pkgs.btop}/bin/btop";
    };
    "custom/mem-hog" = {
      exec = "${memHogWatch}";
      return-type = "json";
      interval = 10;
      on-click = "${pkgs.kitty}/bin/kitty -e ${pkgs.btop}/bin/btop";
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
    '';
  };
}
