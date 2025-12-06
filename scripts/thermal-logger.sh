#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob
zone_dirs=(/sys/class/thermal/thermal_zone*)
if (( ${#zone_dirs[@]} == 0 )); then
  echo "No /sys/class/thermal/thermal_zone* found." >&2
  exit 1
fi

# Sort zones by numeric suffix so thermal_zone2 comes after thermal_zone1
zones_sorted="$(
  for z in "${zone_dirs[@]}"; do
    b="$(basename "$z")"
    n="${b#thermal_zone}"
    [[ "$n" =~ ^[0-9]+$ ]] && printf "%06d %s\n" "$n" "$b"
  done | sort -n | awk '{print $2}'
)"

mapfile -t zones < <(printf "%s\n" "$zones_sorted")

# Build header once (timestamp + one column per zone, including type)
header="timestamp"
for z in "${zones[@]}"; do
  zdir="/sys/class/thermal/$z"
  ztype="$(cat "$zdir/type" 2>/dev/null || echo "unknown")"
  # Column name includes both zone and type so it's self-describing
  header+=",${z}_${ztype}"
done
printf '%s\n' "$header"

echo "Logging ${#zones[@]} thermal zones (Ctrl+C to stop)" >&2

while :; do
  ts="$(date -Is)"
  row="$ts"

  for z in "${zones[@]}"; do
    zdir="/sys/class/thermal/$z"
    raw="$(cat "$zdir/temp" 2>/dev/null || true)"

    # Empty if unreadable
    if [[ -z "${raw:-}" || ! "$raw" =~ ^-?[0-9]+$ ]]; then
      row+=","
      continue
    fi

    # Convert millidegrees to degrees when needed
    if (( raw > 1000 || raw < -1000 )); then
      temp_c="$(awk -v v="$raw" 'BEGIN{printf "%.3f", v/1000.0}')"
    else
      temp_c="$(awk -v v="$raw" 'BEGIN{printf "%.3f", v}')"
    fi

    row+=",${temp_c}"
  done

  printf '%s\n' "$row"
  sleep 1
done
