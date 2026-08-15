# sitrep — one-screen health readout.
#
# Answers "is this machine OK right now?" without a browser, a Grafana login or
# eight separate commands. Everything abnormal is hoisted into an ALERTS block
# at the top; the sections below are the supporting detail for it.
#
# Every section feature-detects its inputs and degrades to a dim "n/a" rather
# than failing, so the same script is useful on tempest (ZFS + battery + amdgpu)
# and on a host that has none of those.
#
# Deliberate readings, not just a dump of the raw counters:
#   * Memory is reported as MemAvailable, never as "used %". On this host the ZFS
#     ARC lands in SUnreclaim and the amdgpu GTT/VRAM reservation is charged to
#     the process, so "used" structurally overstates pressure by many GiB. The
#     ARC / GPU / zram lines are broken out underneath so the gap is visible.
#   * Swap is shown as slots consumed (what /proc/meminfo reports) alongside the
#     zram pool's real physical footprint, because the two differ by the
#     compression ratio and only the second one actually costs RAM.
#   * Pressure stall averages get thresholds rather than being printed bare —
#     `some` is contention, `full` is total stall and matters far more.
#
# Structure: the render writes into $BODY inside a `{ ... } > "$BODY"` group,
# which is NOT a subshell, so the alert() calls made while rendering still reach
# the ALERTS array. The header and alert block are printed afterwards, above it.
# Any loop that raises an alert must therefore use `done < <(cmd)` rather than
# `cmd | while`, or the alert is lost in the pipeline's subshell.

set +o errexit
set -o nounset
set -o pipefail

# Only the character-classification category, so `pad` below counts the "→" and
# "●" glyphs as one character each no matter what the caller's environment is.
# LC_TIME and friends are left alone so dates still follow the user's locale.
export LC_CTYPE=C.UTF-8

# ── presentation ────────────────────────────────────────────────────────────

WIDTH=78
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\033[0m'; B=$'\033[1m'; D=$'\033[2m'
  RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; MAG=$'\033[35m'; CYA=$'\033[36m'
else
  R=""; B=""; D=""; RED=""; GRN=""; YEL=""; MAG=""; CYA=""
fi

ALERTS=()
alert() { ALERTS+=("bad|$1"); }
warn()  { ALERTS+=("warn|$1"); }

dot() {
  case "${1:-}" in
    ok)   printf '%s' "${GRN}●${R}" ;;
    warn) printf '%s' "${YEL}●${R}" ;;
    bad)  printf '%s' "${RED}●${R}" ;;
    *)    printf '%s' "${D}○${R}" ;;
  esac
}

dashes() {
  local n="$1" s
  [ "$n" -lt 0 ] && n=0
  printf -v s '%*s' "$n" ''
  printf '%s' "${s// /─}"
}

rule() { printf '%s%s%s\n' "$D" "$(dashes "$WIDTH")" "$R"; }

section() {
  printf '\n%s──%s %s%s%s %s%s%s\n' \
    "$D" "$R" "$B$CYA" "$1" "$R" "$D" "$(dashes $((WIDTH - ${#1} - 5)))" "$R"
}

# pad <string> <width> — printf's %-Ns pads by *bytes*, so a label containing a
# multi-byte glyph ("borg → repo") comes out two columns short. This pads by
# character count instead. Colour escapes must never be passed through here.
pad() {
  local s="$1" n=$(( $2 - ${#1} ))
  [ "$n" -lt 0 ] && n=0
  printf '%s%*s' "$s" "$n" ''
}

# row <label> <value...> — the label column is plain text so it pads by real
# character count; colour only ever appears in the value.
row() { local l="$1"; shift; printf '  %s%s%s %s\n' "$D" "$(pad "$l" 11)" "$R" "$*"; }

na() { printf '%sn/a%s' "$D" "$R"; }

have() { command -v "$1" >/dev/null 2>&1; }

readf() { [ -r "$1" ] && tr -d '\n' < "$1" 2>/dev/null; }

# ── numeric helpers ─────────────────────────────────────────────────────────

human() {
  awk -v b="${1:-0}" 'BEGIN{
    if (b+0 == 0) { print "0B"; exit }
    s = "BKMGTP"; i = 1
    while (b >= 1024 && i < 6) { b /= 1024; i++ }
    printf (b < 10 && i > 1) ? "%.1f%s" : "%.0f%s", b, substr(s, i, 1)
  }'
}

pct() { awk -v a="${1:-0}" -v b="${2:-0}" 'BEGIN{ printf "%.0f", (b+0 == 0) ? 0 : a*100/b }'; }

# dur <seconds> — compact, at most two units.
dur() {
  awk -v s="${1:-0}" 'BEGIN{
    s = int(s); if (s < 0) s = -s
    d = int(s/86400); s -= d*86400
    h = int(s/3600);  s -= h*3600
    m = int(s/60);    s -= m*60
    if (d > 0)      printf "%dd %dh", d, h
    else if (h > 0) printf "%dh %dm", h, m
    else if (m > 0) printf "%dm", m
    else            printf "%ds", s
  }'
}

# ago <epoch> — "2h 6m ago" / "in 21h", or a bare dash when the timestamp is
# unset. Returns plain text with no colour escapes, so callers can pad it.
ago() {
  local t="${1:-0}" delta
  if [ -z "$t" ] || [ "$t" = "0" ]; then printf '—'; return; fi
  delta=$(( $(date +%s) - t ))
  if [ "$delta" -ge 0 ]; then printf '%s ago' "$(dur "$delta")"
  else printf 'in %s' "$(dur "$delta")"; fi
}

# epoch <systemd timestamp> — systemd prints "Tue 2026-08-11 00:00:09 WEST";
# an unset timestamp comes back empty or as the literal "n/a".
epoch() {
  case "${1:-}" in ""|"n/a"|"0"|"infinity") echo 0; return ;; esac
  date -d "$1" +%s 2>/dev/null || echo 0
}

# ── facts gathered up front ─────────────────────────────────────────────────

HOST=$(readf /proc/sys/kernel/hostname)
KERNEL=$(uname -r)
UPTIME=$(dur "$(awk '{print int($1)}' /proc/uptime)")
OSREL=$(awk -F'"' '/^PRETTY_NAME=/{print $2}' /etc/os-release 2>/dev/null)

GEN=""; GEN_AGE=""
if [ -L /nix/var/nix/profiles/system ]; then
  GEN=$(readlink /nix/var/nix/profiles/system | sed 's/^system-//; s/-link$//')
  GEN_AGE=$(ago "$(stat -c '%Y' /nix/var/nix/profiles/system 2>/dev/null || echo 0)")
fi

NCPU=$(nproc 2>/dev/null || echo 1)
read -r L1 L5 L15 RUNQ _ < /proc/loadavg

# Load only means anything relative to core count; 1.5x cores is real saturation.
LOAD_STATE=$(awk -v l="$L1" -v n="$NCPU" 'BEGIN{
  r = l/n; print (r >= 1.5) ? "bad" : ((r >= 0.8) ? "warn" : "ok")
}')
[ "$LOAD_STATE" = bad ] && alert "load ${L1} across ${NCPU} cores — CPU saturated"

DEFAULT_IFACE=$(ip route show default 2>/dev/null | awk 'NR==1{print $5}')

# ── memory ──────────────────────────────────────────────────────────────────

mi() { awk -v k="$1:" '$1 == k { print $2 * 1024; exit }' /proc/meminfo; }

MEM_TOTAL=$(mi MemTotal)
MEM_AVAIL=$(mi MemAvailable)
SWAP_TOTAL=$(mi SwapTotal)
SWAP_USED=$(( SWAP_TOTAL - $(mi SwapFree) ))
AVAIL_PCT=$(pct "$MEM_AVAIL" "$MEM_TOTAL")

# psi <resource> <some|full> → "avg10 avg60 avg300"; empty if PSI is unavailable.
psi() {
  [ -r "/proc/pressure/$1" ] || return 0
  awk -v k="$2" '$1 == k {
    for (i = 2; i <= NF; i++) { split($i, p, "="); v[p[1]] = p[2] }
    print v["avg10"], v["avg60"], v["avg300"]
  }' "/proc/pressure/$1"
}

MEM_PSI=$(psi memory some | awk '{print $1+0}')

# Headroom is judged on MemAvailable and cross-checked against memory PSI: a low
# available figure with zero stall is a healthy cache, not a problem.
MEM_STATE=ok
if   [ "$AVAIL_PCT" -lt 10 ]; then MEM_STATE=bad
elif [ "$AVAIL_PCT" -lt 20 ]; then MEM_STATE=warn
fi
[ "$MEM_STATE" = bad ] &&
  alert "only ${AVAIL_PCT}% memory available ($(human "$MEM_AVAIL") of $(human "$MEM_TOTAL"))"

ARC_SIZE=""; ARC_MAX=""
if [ -r /proc/spl/kstat/zfs/arcstats ]; then
  ARC_SIZE=$(awk '$1 == "size"  { print $3 }' /proc/spl/kstat/zfs/arcstats)
  ARC_MAX=$(awk  '$1 == "c_max" { print $3 }' /proc/spl/kstat/zfs/arcstats)
fi

GTT=0; VRAM=0
for f in /sys/class/drm/card*/device/mem_info_gtt_used; do
  [ -r "$f" ] && GTT=$(( GTT + $(readf "$f") ))
done
for f in /sys/class/drm/card*/device/mem_info_vram_used; do
  [ -r "$f" ] && VRAM=$(( VRAM + $(readf "$f") ))
done

# zram stores compressed: mm_stat is orig / compressed / physical RAM consumed.
ZRAM_ORIG=0; ZRAM_PHYS=0
for f in /sys/block/zram*/mm_stat; do
  if [ -r "$f" ]; then
    ZRAM_ORIG=$(( ZRAM_ORIG + $(awk '{print $1}' "$f") ))
    ZRAM_PHYS=$(( ZRAM_PHYS + $(awk '{print $3}' "$f") ))
  fi
done

# ── services (computed early; the render only formats them) ─────────────────

FAILED_SYS=$(systemctl --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
FAILED_USR=$(systemctl --user --failed --no-legend --plain 2>/dev/null | awk '{print $1}')
N_FAILED_SYS=$(printf '%s' "$FAILED_SYS" | grep -c . )
N_FAILED_USR=$(printf '%s' "$FAILED_USR" | grep -c . )
N_RUNNING=$(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null | grep -c . )

for u in $FAILED_SYS; do alert "unit failed: $u"; done
for u in $FAILED_USR; do alert "user unit failed: $u"; done

# Enabled long-running services that are not up. oneshot/dbus/idle units are
# excluded because they are *supposed* to sit inactive between activations.
DOWN=$(systemctl list-unit-files --type=service --state=enabled --no-legend --plain 2>/dev/null |
  awk '{print $1}' | grep -v '@' |
  while read -r u; do
    case "$(systemctl show "$u" -p Type --value 2>/dev/null)" in oneshot|dbus|idle) continue ;; esac
    [ "$(systemctl is-active "$u" 2>/dev/null)" = active ] || printf '%s ' "${u%.service}"
  done | sed 's/ *$//')
[ -n "$DOWN" ] && warn "enabled but not running: $DOWN"

# ── section renderers ───────────────────────────────────────────────────────

# psi_state <value> <warn threshold> <bad threshold>
psi_state() {
  awk -v v="${1:-0}" -v w="$2" -v b="$3" 'BEGIN{
    print (v+0 >= b) ? "bad" : ((v+0 >= w) ? "warn" : "ok")
  }'
}

psi_row() {
  local res="$1" wsome="$2" bsome="$3" wfull="$4" bfull="$5"
  local some full s10 f10 st out
  some=$(psi "$res" some); full=$(psi "$res" full)
  [ -z "$some$full" ] && return 0

  s10=$(printf '%s' "$some" | awk '{print $1+0}')
  f10=$(printf '%s' "$full" | awk '{print $1+0}')

  # `full` means every task was stalled — weight it far above `some`.
  st=ok
  [ -n "$full" ] && st=$(psi_state "$f10" "$wfull" "$bfull")
  [ "$st" = ok ] && [ -n "$some" ] && st=$(psi_state "$s10" "$wsome" "$bsome")

  # irq exposes only `full`; blank-fill the `some` block so its numbers still
  # land under the right column headings.
  if [ -n "$some" ]; then
    out=$(printf '%ssome%s %s' "$D" "$R" \
      "$(printf '%s' "$some" | awk '{printf "%5.1f %5.1f %5.1f", $1, $2, $3}')")
  else
    out=$(printf '%22s' '')
  fi
  [ -n "$full" ] && out=$(printf '%s   %sfull%s %s' "$out" "$D" "$R" \
    "$(printf '%s' "$full" | awk '{printf "%5.1f %5.1f %5.1f", $1, $2, $3}')")

  printf '  %s %s%-7s%s %s\n' "$(dot "$st")" "$D" "$res" "$R" "$out"

  case "$st" in
    bad)  alert "$res pressure high — full stall ${f10}% over 10s" ;;
    warn) warn  "$res pressure elevated — some ${s10}% over 10s" ;;
  esac
}

pool_report() {
  local p="$1" health size alloc cap frag status errs scan st rw
  read -r health size alloc cap frag < <(
    zpool list -H -o health,size,alloc,cap,frag "$p" 2>/dev/null
  )
  [ -z "${health:-}" ] && return 0

  status=$(zpool status "$p" 2>/dev/null)

  # Sum READ/WRITE/CKSUM across every vdev row inside the config block.
  rw=$(printf '%s\n' "$status" | awk '
    /^config:/ { c = 1; next }
    /^errors:/ { c = 0 }
    c && NF >= 5 && $2 ~ /^(ONLINE|DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED)$/ {
      r += $3; w += $4; k += $5
    }
    END { print r+0, w+0, k+0 }')
  local P_R P_W P_K
  read -r P_R P_W P_K <<<"$rw"

  errs=$(printf '%s\n' "$status" | sed -n 's/^errors: *//p' | head -1)

  # The scan block wraps over several indented lines; flatten it into one.
  scan=$(printf '%s\n' "$status" |
    awk '/^[[:space:]]*scan:/ { f = 1 } /^[[:space:]]*config:/ { f = 0 } f' |
    sed 's/^[[:space:]]*scan:[[:space:]]*//; s/[[:space:]]\+/ /g' | tr -d '\n')

  st=ok
  case "$health" in
    ONLINE) ;;
    *) st=bad; alert "pool $p is $health" ;;
  esac
  if [ "$(( P_R + P_W + P_K ))" -gt 0 ]; then
    st=bad; alert "pool $p has I/O errors — read $P_R write $P_W cksum $P_K"
  fi
  case "$errs" in
    "No known data errors"|"") ;;
    *) st=bad; alert "pool $p: $errs" ;;
  esac
  # Past ~85% full, ZFS allocation slows down badly.
  if [ "${cap%\%}" -ge 90 ]; then
    st=bad; alert "pool $p is $cap full"
  elif [ "${cap%\%}" -ge 85 ] && [ "$st" = ok ]; then
    st=warn; warn "pool $p is $cap full"
  fi

  printf '  %s %-8s %-9s %s / %s  %s used  %sfrag %s%s\n' \
    "$(dot "$st")" "$p" "$health" "$alloc" "$size" "$cap" "$D" "$frag" "$R"
  printf '      %serrors%s read %s  write %s  cksum %s   %s%s%s\n' \
    "$D" "$R" "$P_R" "$P_W" "$P_K" "$D" "${errs:-unknown}" "$R"

  # Condense the scan line: percent + ETA while running, age + repairs after.
  local scanline when when_e rep
  case "${scan:-}" in
    *"in progress"*)
      scanline=$(printf '%s' "$scan" |
        sed -n 's/.*\([0-9.]*%\) done, \([0-9:]*\) to go.*/\1 done · \2 to go/p')
      printf '      %sscrub %s %s%s%s\n' "$D" "$R" "$CYA" "${scanline:-in progress}" "$R"
      ;;
    *repaired*)
      when=$(printf '%s' "$scan" | sed -n 's/.* on \(.*\)$/\1/p')
      rep=$(printf  '%s' "$scan" | sed -n 's/.*repaired \([^ ]*\) in.*/\1/p')
      when_e=$(epoch "$when")
      # Data that has not been scrubbed in ~5 weeks is unverified data.
      if [ "$when_e" -gt 0 ] && [ "$(( ($(date +%s) - when_e) / 86400 ))" -gt 35 ]; then
        warn "pool $p has not been scrubbed since $(ago "$when_e")"
      fi
      printf '      %sscrub %s %s  %srepaired %s%s\n' \
        "$D" "$R" "$(ago "$when_e")" "$D" "${rep:-0B}" "$R"
      ;;
    "") printf '      %sscrub %s %snever%s\n' "$D" "$R" "$YEL" "$R" ;;
    *)  printf '      %sscrub %s %s%s%s\n' "$D" "$R" "$D" "$scan" "$R" ;;
  esac
}

# NVMe SMART. The health log needs root, so an unprivileged run falls back to
# the hwmon temperature and says so, rather than printing zeroes that read as OK.
smart_report() {
  local dev="$1" name temp h j crit used spare media poh unsafe st
  name=$(lsblk -dno MODEL "$dev" 2>/dev/null | sed 's/ *$//')

  temp=""
  for h in /sys/class/hwmon/hwmon*; do
    if [ "$(readf "$h/name")" = nvme ] && [ -r "$h/temp1_input" ]; then
      temp=$(( $(readf "$h/temp1_input") / 1000 )); break
    fi
  done

  j=""
  have smartctl && j=$(smartctl -j -H -A "$dev" 2>/dev/null)
  crit=$(printf '%s' "$j" | jq -r '.nvme_smart_health_information_log.critical_warning // empty' 2>/dev/null)

  if [ -z "$crit" ]; then
    printf '  %s %-9s %-24s %s%s°C%s  %sSMART needs root — "sudo sitrep" adds wear/errors%s\n' \
      "$(dot '')" "${dev##*/}" "${name:-unknown}" "$B" "${temp:-?}" "$R" "$D" "$R"
    return 0
  fi

  used=$(printf   '%s' "$j" | jq -r '.nvme_smart_health_information_log.percentage_used  // 0')
  spare=$(printf  '%s' "$j" | jq -r '.nvme_smart_health_information_log.available_spare  // 100')
  media=$(printf  '%s' "$j" | jq -r '.nvme_smart_health_information_log.media_errors     // 0')
  poh=$(printf    '%s' "$j" | jq -r '.nvme_smart_health_information_log.power_on_hours   // 0')
  unsafe=$(printf '%s' "$j" | jq -r '.nvme_smart_health_information_log.unsafe_shutdowns // 0')

  st=ok
  [ "$crit"  != 0 ]   && { st=bad; alert "${dev##*/}: SMART critical warning (bitmask $crit)"; }
  [ "$media" -gt 0 ]  && { st=bad; alert "${dev##*/}: $media media errors"; }
  [ "$spare" -lt 20 ] && { st=bad; alert "${dev##*/}: available spare down to ${spare}%"; }
  [ "$used"  -ge 90 ] && { st=bad; alert "${dev##*/}: ${used}% of rated write endurance used"; }
  [ "$st" = ok ] && [ "$used" -ge 70 ] &&
    { st=warn; warn "${dev##*/}: ${used}% of rated write endurance used"; }
  [ "${temp:-0}" -ge 70 ] && { st=bad; alert "${dev##*/} running at ${temp}°C"; }

  printf '  %s %-9s %-24s %s%s°C%s\n' "$(dot "$st")" "${dev##*/}" "${name:-unknown}" "$B" "${temp:-?}" "$R"
  printf '      %swear%s %s%%  %sspare%s %s%%  %smedia errors%s %s  %spowered%s %sh  %sunsafe shutdowns%s %s\n' \
    "$D" "$R" "$used" "$D" "$R" "$spare" "$D" "$R" "$media" "$D" "$R" "$poh" "$D" "$R" "$unsafe"
}

# Curated, because these are the units that actually protect data. A generic
# "every timer" list buries them under logrotate and fwupd-refresh.
BACKUP_UNITS=(
  "borgbackup-job-home-irene|borg → remote repo"
  "tempest-backup-external|zfs send → usb ssd"
  "sanoid|local zfs snapshots"
  "backup-vaultwarden|vaultwarden dump"
  "vaultwarden-mirror-refresh|vaultwarden mirror"
  # "zfs-scrub timer", not "rpool scrub": this row reports whether the *unit* has
  # fired, which is a different fact from when the pool was last scrubbed. A
  # scrub kicked off by hand or by the backup orchestrator leaves this unit at
  # "never run" while ZFS POOLS above correctly shows a recent scrub.
  "zfs-scrub|zfs-scrub timer"
  # `nh-clean`, not `nix-gc`: GC moved to programs.nh.clean (hosts/tempest/
  # default.nix) and nix.gc.automatic is off, so nix-gc.service does not exist —
  # this row read "never run" forever while the real job went unwatched.
  "nh-clean|nix store gc"
)

backup_row() {
  local unit="$1" label="$2" props state result last next last_e next_e st note col

  # A curated unit that does not exist is a MONITORING GAP, not a no-op: it means
  # the unit was renamed or dropped and this row has been silently absent ever
  # since. (This is exactly how `nix-gc` sat here unnoticed after GC moved to
  # programs.nh.clean.) Say so instead of returning, so a rename surfaces on the
  # next run rather than never.
  if ! systemctl cat "$unit.service" >/dev/null 2>&1; then
    warn "$unit.service does not exist — renamed or removed? this row is unmonitored"
    printf '  %s %s %s%s%s\n' \
      "$(dot warn)" "$(pad "$label" 21)" "$YEL" "$(pad "no such unit" 12)" "$R"
    return 0
  fi

  props=$(systemctl show "$unit.service" \
    -p ActiveState -p Result -p ActiveEnterTimestamp -p InactiveEnterTimestamp 2>/dev/null)
  state=$(printf  '%s\n' "$props" | sed -n 's/^ActiveState=//p')
  result=$(printf '%s\n' "$props" | sed -n 's/^Result=//p')
  last=$(printf   '%s\n' "$props" | sed -n 's/^InactiveEnterTimestamp=//p')
  [ -z "$last" ] && last=$(printf '%s\n' "$props" | sed -n 's/^ActiveEnterTimestamp=//p')

  next=$(systemctl show "$unit.timer" -p NextElapseUSecRealtime --value 2>/dev/null)
  last_e=$(epoch "$last"); next_e=$(epoch "$next")

  st=ok; note="ok"
  case "$state" in
    active|activating)
      note="running now"
      # A backup wedged in `activating` is the failure that looks fine: no failed
      # unit, no notification, and no fresh backup either.
      if [ "$last_e" -gt 0 ] && [ "$(( ($(date +%s) - last_e) / 3600 ))" -gt 12 ]; then
        st=warn; note="running 12h+"
        warn "$unit has been running over 12h — check for a hung job"
      fi
      ;;
    failed) st=bad; note="FAILED"; alert "$unit failed" ;;
    *)
      # A unit that has never run also reports Result=success, so the absence of
      # a last-run timestamp is what distinguishes "fine" from "never happened".
      if [ "$last_e" -eq 0 ]; then st=""; note="never run"
      else
        case "$result" in
          success) st=ok;  note="ok" ;;
          *)       st=bad; note="${result:-unknown}"; alert "$unit last exited: $result" ;;
        esac
      fi
      ;;
  esac

  # Overdue: the timer's next-elapse point is in the past and it still hasn't run.
  if [ "$next_e" -gt 0 ] && [ "$next_e" -lt "$(date +%s)" ] && [ "$state" != active ]; then
    st=warn; warn "$unit is overdue (was due $(ago "$next_e"))"
  fi

  col=""
  [ "$st" = bad ]  && col="$RED"
  [ "$st" = warn ] && col="$YEL"
  [ "$st" = ""   ] && col="$D"
  printf '  %s %s %s%s%s %s %snext %s%s\n' \
    "$(dot "$st")" "$(pad "$label" 21)" "$col" "$(pad "$note" 12)" "$R" \
    "$(pad "$(ago "$last_e")" 15)" "$D" "$(ago "$next_e")" "$R"
}

hwmon_temp() {
  local want="$1" h l
  for h in /sys/class/hwmon/hwmon*; do
    [ "$(readf "$h/name")" = "$want" ] || continue
    for l in temp1_input temp2_input; do
      if [ -r "$h/$l" ]; then
        awk -v v="$(readf "$h/$l")" 'BEGIN{ printf "%.0f", v/1000 }'
        return 0
      fi
    done
  done
}

# ════════════════════════════════════════════════════════════════════════════
# Render into $BODY. This is a brace group, not a subshell, so alert() calls
# made in here still land in ALERTS — which is printed above $BODY afterwards.
# ════════════════════════════════════════════════════════════════════════════

BODY=$(mktemp)
trap 'rm -f "$BODY"' EXIT

{

section "LOAD & PRESSURE"
row "load" "$(printf '%s%s%s  %s  %s   %s%s cores · %s runnable%s' \
  "$B" "$L1" "$R" "$L5" "$L15" "$D" "$NCPU" "${RUNQ%%/*}" "$R")"
printf '  %s%-9s %-4s %5s %5s %5s   %-4s %5s %5s %5s%s\n' \
  "$D" "" "" "10s" "60s" "5m" "" "10s" "60s" "5m" "$R"
psi_row cpu    20 50  5 20
psi_row io     20 50  5 20
psi_row memory 10 30  1 10
psi_row irq    20 50 20 50

section "MEMORY"
case "$MEM_STATE" in bad) MC="$RED" ;; warn) MC="$YEL" ;; *) MC="$GRN" ;; esac
row "available" "$(printf '%s%s%s of %s   %s%s%% free%s   %s← judge headroom here, not on \"used\"%s' \
  "$B" "$(human "$MEM_AVAIL")" "$R" "$(human "$MEM_TOTAL")" "$MC" "$AVAIL_PCT" "$R" "$D" "$R")"
row "" "$(printf '%sstall %s%% avg10 — 0 means the cache is doing its job%s' "$D" "${MEM_PSI:-0}" "$R")"
[ -n "$ARC_SIZE" ] && row "zfs arc" "$(printf '%s of %s cap   %scounted as SUnreclaim, not as cache%s' \
  "$(human "$ARC_SIZE")" "$(human "$ARC_MAX")" "$D" "$R")"
{ [ "$GTT" -gt 0 ] || [ "$VRAM" -gt 0 ]; } && row "amdgpu" "$(printf '%s gtt + %s vram   %scharged to the process%s' \
  "$(human "$GTT")" "$(human "$VRAM")" "$D" "$R")"
row "swap" "$(printf '%s of %s slots used%s' "$(human "$SWAP_USED")" "$(human "$SWAP_TOTAL")" \
  "$([ "$ZRAM_PHYS" -gt 0 ] && printf '   %szram: %s of data in %s of RAM%s' \
     "$D" "$(human "$ZRAM_ORIG")" "$(human "$ZRAM_PHYS")" "$R")")"

if have zpool; then
  section "ZFS POOLS"
  POOLS=$(zpool list -H -o name 2>/dev/null)
  if [ -z "$POOLS" ]; then
    printf '  %s no pools imported\n' "$(dot '')"
  else
    for p in $POOLS; do pool_report "$p"; done
  fi
  # The USB backup pool is exported between runs by design — say so, so its
  # absence never reads as a missing disk.
  if ! printf '%s\n' "$POOLS" | grep -qx backup; then
    printf '  %s %-8s %snot imported — exported between backup runs, which is normal%s\n' \
      "$(dot '')" "backup" "$D" "$R"
  fi
fi

section "DISKS"
for d in /dev/nvme?n?; do [ -e "$d" ] && smart_report "$d"; done
if have lsblk; then
  printf '\n      %sattached block devices%s\n' "$D" "$R"
  lsblk -dno NAME,SIZE,MODEL,TRAN 2>/dev/null | grep -vE '^(zram|loop|sr)' |
    awk -v d="$D" -v r="$R" '{
      n = $1; s = $2; $1 = ""; $2 = ""; sub(/^ +/, "")
      printf "      %s%-9s %-7s %s%s\n", d, n, s, $0, r
    }'
fi

section "FILESYSTEMS"
while read -r target fstype size used pcent; do
  p=${pcent%\%}
  st=ok
  if [ "$p" -ge 90 ]; then st=bad; alert "$target is $pcent full"
  elif [ "$p" -ge 80 ]; then st=warn; warn "$target is $pcent full"
  fi
  printf '  %s %-22s %s%-6s%s %6s used of %-6s %s\n' \
    "$(dot "$st")" "$target" "$D" "$fstype" "$R" "$used" "$size" "$pcent"
done < <(df -h -x devtmpfs -x squashfs -x efivarfs -x ramfs -x overlay \
           --output=target,fstype,size,used,pcent 2>/dev/null |
         grep -vE '^/(run|dev|sys|proc)' | tail -n +2)

section "BACKUPS & SCHEDULED JOBS"
for entry in "${BACKUP_UNITS[@]}"; do backup_row "${entry%%|*}" "${entry#*|}"; done

section "SERVICES"
if [ "$N_FAILED_SYS" -eq 0 ]; then
  printf '  %s %-21s %s%s running · 0 failed%s\n' "$(dot ok)" "system units" "$D" "$N_RUNNING" "$R"
else
  printf '  %s %-21s %s%s failed%s\n' "$(dot bad)" "system units" "$RED" "$N_FAILED_SYS" "$R"
  for u in $FAILED_SYS; do printf '      %s%s%s\n' "$RED" "$u" "$R"; done
fi
if [ "$N_FAILED_USR" -eq 0 ]; then
  printf '  %s %-21s %s0 failed%s\n' "$(dot ok)" "user units" "$D" "$R"
else
  printf '  %s %-21s %s%s failed%s\n' "$(dot bad)" "user units" "$RED" "$N_FAILED_USR" "$R"
  for u in $FAILED_USR; do printf '      %s%s%s\n' "$RED" "$u" "$R"; done
fi
[ -n "$DOWN" ] && printf '  %s %-21s %s\n' "$(dot warn)" "enabled but down" "$DOWN"

section "NETWORK"
# Carrier-down interfaces are collapsed into one dim line: docker0 and the
# per-network bridges sit DOWN whenever no container is up, and listing each one
# buries the links that actually carry traffic.
NET_DOWN=""
while read -r iface state addrs; do
  case "$state" in
    UP|UNKNOWN)
      mark=" "; [ "$iface" = "$DEFAULT_IFACE" ] && mark="→"
      printf '  %s %s %s %s%s%s %s\n' \
        "$(dot ok)" "$mark" "$(pad "$iface" 16)" "$D" "$(pad "$state" 8)" "$R" "$addrs"
      ;;
    *) NET_DOWN="$NET_DOWN$iface " ;;
  esac
done < <(ip -br -4 addr show 2>/dev/null | grep -v '^lo ')

# Wi-Fi link quality: a weak signal explains slowness that otherwise looks like
# a broken NIC. −67 dBm is the usual floor for reliable throughput.
if have iw; then
  for w in /sys/class/net/*/wireless; do
    [ -d "$w" ] || continue
    dev=$(basename "$(dirname "$w")")
    link=$(iw dev "$dev" link 2>/dev/null)
    case "$link" in *"Not connected"*|"") continue ;; esac
    ssid=$(printf '%s\n' "$link" | sed -n 's/.*SSID: *//p' | head -1)
    sig=$(printf  '%s\n' "$link" | sed -n 's/.*signal: *\(-\{0,1\}[0-9]*\).*/\1/p' | head -1)
    rate=$(printf '%s\n' "$link" | sed -n 's/.*tx bitrate: *\([0-9.]*\) MBit.*/\1/p' | head -1)
    st=ok
    if [ -n "$sig" ]; then
      [ "$sig" -lt -67 ] && st=warn
      [ "$sig" -lt -75 ] && { st=bad; warn "wifi signal ${sig} dBm on $dev — weak link"; }
    fi
    printf '  %s   %s %-20s %s%s dBm · %s Mbit/s%s\n' \
      "$(dot "$st")" "$(pad "$dev" 16)" "${ssid:-?}" "$D" "${sig:-?}" "${rate:-?}" "$R"
  done
fi

# Printed last so the links that actually carry traffic stay at the top.
[ -n "$NET_DOWN" ] && printf '  %s   %sno carrier: %s%s\n' "$(dot '')" "$D" "${NET_DOWN% }" "$R"

section "POWER & THERMAL"
for bat in /sys/class/power_supply/BAT*; do
  [ -d "$bat" ] || continue
  cap=$(readf "$bat/capacity"); bstat=$(readf "$bat/status")
  cycles=$(readf "$bat/cycle_count")

  # Two sysfs families exist and a battery exposes exactly one: energy_* (µWh,
  # with power_now in µW) or charge_* (µAh, with current_now in µA — this is
  # what the Framework reports, and it needs voltage_now to reach watts).
  # Everything below is normalised to µWh / µW so one code path handles both.
  enow=$(readf "$bat/energy_now"); efull=$(readf "$bat/energy_full")
  edesign=$(readf "$bat/energy_full_design"); uw=$(readf "$bat/power_now")
  if [ -z "${enow:-}" ]; then
    volt=$(readf "$bat/voltage_now")
    if [ "${volt:-0}" -gt 0 ]; then
      scale() { awk -v a="${1:-0}" -v v="$volt" 'BEGIN{ printf "%d", a*v/1000000 }'; }
      enow=$(scale "$(readf "$bat/charge_now")")
      efull=$(scale "$(readf "$bat/charge_full")")
      edesign=$(scale "$(readf "$bat/charge_full_design")")
      uw=$(scale "$(readf "$bat/current_now")")
    fi
  fi

  # Below ~0.1 W the reading is float noise on a battery that is neither
  # charging nor discharging; printing "0.0W" there just looks broken.
  watts=""; eta=""
  if [ "${uw:-0}" -gt 100000 ]; then
    watts=$(awk -v v="$uw" 'BEGIN{ printf "%.1fW", v/1000000 }')
    if [ "$bstat" = Discharging ] && [ "${enow:-0}" -gt 0 ]; then
      eta="~$(dur "$(awk -v e="$enow" -v p="$uw" 'BEGIN{ printf "%d", e*3600/p }')") left"
    fi
  fi

  health=""
  if [ "${edesign:-0}" -gt 0 ]; then
    health=$(pct "$efull" "$edesign")
    [ "$health" -lt 70 ] && warn "battery health is ${health}% of design capacity"
  fi

  st=ok
  if [ "$bstat" = Discharging ]; then
    [ "${cap:-100}" -lt 20 ] && st=warn
    [ "${cap:-100}" -lt 10 ] && { st=bad; alert "battery at ${cap}% and discharging"; }
  fi

  row "${bat##*/}" "$(printf '%s %s%s%%%s %s%s%s %s%s %shealth %s%% · %s cycles%s' \
    "$(dot "$st")" "$B" "${cap:-?}" "$R" "$D" "${bstat:-?}" "$R" \
    "${watts:-}" "${eta:+ $eta}" "$D" "${health:-?}" "${cycles:-?}" "$R")"
done
[ -r /sys/class/power_supply/ACAD/online ] &&
  row "ac" "$([ "$(readf /sys/class/power_supply/ACAD/online)" = 1 ] && printf 'connected' || printf 'on battery')"

TEMPS=""
for probe in cpu:k10temp gpu:amdgpu nvme:nvme wifi:mt7925_phy0 board:acpitz chassis:framework_laptop; do
  lbl="${probe%%:*}"; t=$(hwmon_temp "${probe#*:}")
  [ -z "$t" ] && continue
  col=""
  [ "$t" -ge 80 ] && col="$YEL"
  [ "$t" -ge 90 ] && { col="$RED"; alert "$lbl at ${t}°C"; }
  TEMPS="$TEMPS$(printf '%s%s%s %s%s°C%s  ' "$D" "$lbl" "$R" "$col" "$t" "$R")"
done
[ -n "$TEMPS" ] && row "temps" "$TEMPS"

section "ERRORS THIS BOOT"
# Collapse by message shape, so 400 identical bluetoothd lines read as one row.
# PIDs, MACs, hex and bare numbers are the parts that vary, so they get masked.
if have journalctl; then
  JOUT=$(journalctl -p 3 -b --no-pager -q -o short 2>/dev/null)
  TOTAL=$(printf '%s' "$JOUT" | grep -c . )
  if [ "${TOTAL:-0}" -eq 0 ]; then
    printf '  %s nothing logged at priority error or above\n' "$(dot ok)"
  else
    printf '  %s%s messages at priority ≤ error, grouped by shape:%s\n\n' "$D" "$TOTAL" "$R"
    SHAPES=$(printf '%s\n' "$JOUT" |
      sed -E 's/^[A-Z][a-z]{2} +[0-9]+ [0-9:]+ [^ ]+ //
              s/\[[0-9]+\]//g
              s/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/<mac>/g
              s/0x[0-9a-fA-F]+/<hex>/g
              s/[0-9]+/N/g' |
      sort | uniq -c | sort -rn)
    while read -r count msg; do
      st=warn; [ "$count" -ge 50 ] && st=bad
      printf '  %s %s%5s×%s %.66s\n' "$(dot "$st")" "$B" "$count" "$R" "$msg"
    done < <(printf '%s\n' "$SHAPES" | head -8)

    # Only the loudest repeater is worth hoisting into ALERTS.
    TOPN=$(printf '%s\n' "$SHAPES" | head -1 | awk '{print $1}')
    TOPMSG=$(printf '%s\n' "$SHAPES" | head -1 | sed -E 's/^ *[0-9]+ +//' | cut -c1-52)
    [ "${TOPN:-0}" -ge 100 ] && warn "$TOPN identical log errors this boot — $TOPMSG"
  fi
else
  printf '  %s\n' "$(na)"
fi

printf '\n'
rule
printf '  %sdig deeper:%s systemctl --failed · zpool status -v · journalctl -p3 -b · btop\n' "$D" "$R"

} > "$BODY"

# ── print: header, then alerts, then the body ───────────────────────────────

printf '\n'
printf ' %s%s%s%s   %s%s · gen %s (%s) · up %s%s\n' \
  "$B" "$MAG" "$HOST" "$R" "$D" "$KERNEL" "${GEN:-?}" "${GEN_AGE:-?}" "$UPTIME" "$R"
printf ' %s%s · %s%s\n\n' "$D" "${OSREL:-Linux}" "$(date '+%a %d %b %Y · %H:%M %Z')" "$R"

rule
if [ "${#ALERTS[@]}" -eq 0 ]; then
  printf '  %s %sall nominal%s %s— no failed units, no disk errors, backups current%s\n' \
    "$(dot ok)" "$GRN" "$R" "$D" "$R"
else
  for a in "${ALERTS[@]}"; do printf '  %s %s\n' "$(dot "${a%%|*}")" "${a#*|}"; done
fi
rule

cat "$BODY"
printf '\n'
