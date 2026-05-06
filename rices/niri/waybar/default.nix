{ lib, pkgs, hostname, ... }:
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

  baseSettings = lib.importJSON ./config.jsonc;
  withHogModules = map (bar: bar // {
    "modules-left" = bar."modules-left" ++ [ "custom/cpu-hog" "custom/mem-hog" ];
    "cpu" = bar."cpu" // {
      states = { warning = 70; critical = 90; };
    };
    "memory" = bar."memory" // {
      states = { warning = 70; critical = 90; };
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
    style = builtins.readFile ./style.css;
  };
}
