# tempest-backup-verify — is the external USB backup current, and is it intact?
#
# POOL / PARENT / ALTROOT / SCRUB_MAX_AGE / PAIRS are injected by
# backup-external.nix, so this check always reads the same pool and the same
# replication pairs the orchestrator actually writes. Adding a dataset to
# `pairs` there extends this verification automatically.
#
# The complement to the orchestrator's own health check: that one runs inside a
# backup and fails the unit on a sick pool, so it only ever looks at the moment
# a backup happens to run. This is the on-demand version — "is my backup good?"
# answered without writing to the drive.
#
# Deliberately conservative, because this is the only copy of /persist that is
# not on the NVMe:
#   * imported READ-ONLY, so nothing here can alter the drive
#   * imported with -N, so nothing is mounted
#   * under an altroot, so the replicated /persist mountpoints can never
#     collide with the live ones
#   * the encryption key is NEVER loaded — snapshot names, creation times and
#     pool integrity are all unencrypted metadata, so verification needs no data
#     access at all, and a verify run therefore cannot expose plaintext
#   * every zpool/zfs call is wrapped in `timeout`, because a faulted USB drive
#     suspends the pool and makes these calls block forever rather than fail
#     (the same failure mode that hangs the orchestrator in `activating`)
#   * if the pool was already imported on entry it is left exactly as found —
#     someone is browsing it, or a backup is mid-run
#
# Two things this deliberately does NOT do, both consequences of staying
# read-only: it cannot repair anything, and it cannot scrub. It reports what the
# last scrub found rather than re-verifying every block. A real scrub rides
# along with the backup run (scrub-if-stale in the orchestrator).

set +o errexit

if [ "$(id -u)" -ne 0 ]; then
  echo "tempest-backup-verify: needs root — e.g. doas tempest-backup-verify" >&2
  echo "(sudo works too, but sudo-rs requires a real terminal to authenticate," >&2
  echo " so it fails when invoked from a non-interactive context)" >&2
  exit 1
fi

if [ -t 1 ]; then
  b=$'\033[1m'; d=$'\033[2m'; r=$'\033[0m'
  red=$'\033[31m'; grn=$'\033[32m'; yel=$'\033[33m'
else
  b=""; d=""; r=""; red=""; grn=""; yel=""
fi

VERDICT=0
ok()   { printf '  %s●%s %s\n' "$grn" "$r" "$1"; }
bad()  { printf '  %s●%s %s\n' "$red" "$r" "$1"; VERDICT=1; }
note() { printf '  %s●%s %s\n' "$yel" "$r" "$1"; }

# newest <dataset> — creation epoch of its most recent snapshot, empty if none.
newest()      { timeout 30 zfs list -t snapshot -d 1 -H -p -o creation -s creation "$1" 2>/dev/null | tail -1; }
newest_name() { timeout 30 zfs list -t snapshot -d 1 -H    -o name     -s creation "$1" 2>/dev/null | tail -1; }
oldest_name() { timeout 30 zfs list -t snapshot -d 1 -H    -o name     -s creation "$1" 2>/dev/null | head -1; }

# span <seconds> — compact duration, at most two units.
span() {
  awk -v s="${1:-0}" 'BEGIN{
    s = int(s); if (s < 0) s = -s
    d = int(s/86400); h = int((s%86400)/3600); m = int((s%3600)/60)
    if (d)      printf "%dd %dh", d, h
    else if (h) printf "%dh %dm", h, m
    else        printf "%dm", m
  }'
}

printf '\n%s── external backup verification ──%s\n\n' "$b" "$r"

# ── import ──────────────────────────────────────────────────────────────────

if timeout 30 systemctl is-active --quiet "$USB_UNIT"; then
  note "a backup run is IN PROGRESS — figures below are a moving target"
fi

PREIMPORTED=no
if timeout 30 zpool list -H -o name "$POOL" >/dev/null 2>&1; then
  PREIMPORTED=yes
  note "pool was already imported — leaving it as found, not exporting at the end"
else
  mkdir -p "$ALTROOT"
  if ! timeout 120 zpool import -N -o readonly=on -R "$ALTROOT" -d /dev/disk/by-id "$POOL" 2>&1; then
    printf '  %s●%s could not import "%s" — drive detached, faulted, or in use\n' "$red" "$r" "$POOL"
    exit 1
  fi
  ok "imported '$POOL' read-only (not mounted, key not loaded)"
fi

# Export on EVERY exit path, including failures below — a verify run must never
# be what leaves the drive imported, since that silently makes the next
# orchestrator run skip ("already imported (manual session?)") and quietly
# produce no backup at all.
# shellcheck disable=SC2329  # invoked via the EXIT trap
cleanup() {
  [ "$PREIMPORTED" = yes ] && return 0
  printf '\n'
  if timeout 60 zpool export "$POOL" 2>/dev/null; then
    printf '  %s●%s exported — safe to unplug\n\n' "$grn" "$r"
  else
    printf '  %s●%s EXPORT FAILED — run: doas zpool export %s\n\n' "$red" "$r" "$POOL"
  fi
}
trap cleanup EXIT

# ── integrity ───────────────────────────────────────────────────────────────

printf '\n%sintegrity%s\n' "$b" "$r"

STATUS=$(timeout 60 zpool status "$POOL" 2>/dev/null)
HEALTH=$(timeout 30 zpool list -H -o health "$POOL" 2>/dev/null)

if [ "$HEALTH" = ONLINE ]; then ok "health: ONLINE"; else bad "health: ${HEALTH:-unknown}"; fi

# Per-vdev error counters. A pool reads ONLINE while still carrying these, so
# `health` alone is not an integrity check.
read -r ERR_R ERR_W ERR_K < <(printf '%s\n' "$STATUS" | awk '
  /^config:/ { c = 1; next }
  /^errors:/ { c = 0 }
  c && NF >= 5 && $2 ~ /^(ONLINE|DEGRADED|FAULTED|OFFLINE|UNAVAIL|REMOVED)$/ { r += $3; w += $4; k += $5 }
  END { print r+0, w+0, k+0 }')
if [ $(( ERR_R + ERR_W + ERR_K )) -eq 0 ]; then
  ok "error counters: read 0, write 0, checksum 0"
else
  bad "error counters: read $ERR_R, write $ERR_W, checksum $ERR_K"
fi

DATAERR=$(printf '%s\n' "$STATUS" | sed -n 's/^errors: *//p' | head -1)
if [ "$DATAERR" = "No known data errors" ]; then ok "$DATAERR"; else bad "${DATAERR:-unknown}"; fi

# The scrub is the only signal here that reflects reading every allocated block;
# everything above is metadata that stays clean over rotting data. The
# orchestrator stamps this property after each scrub-if-stale pass — it travels
# with the drive, so it is readable exactly when the pool is imported.
SCRUBBED=$(timeout 30 zfs get -H -o value tempest:scrubbed "$POOL" 2>/dev/null)
case "$SCRUBBED" in
  "" | "-")
    bad "last scrub: never stamped — no full-block verification has ever run"
    ;;
  *)
    SCRUB_AGE=$(( $(date +%s) - SCRUBBED ))
    if [ "$SCRUB_AGE" -le "$SCRUB_MAX_AGE" ]; then
      ok "last scrub: $(span "$SCRUB_AGE") ago (policy: every $(span "$SCRUB_MAX_AGE"))"
    else
      # Not a corruption finding — it means corruption would not yet have been
      # detected. The fix is a backup run with the drive left attached.
      note "last scrub: $(span "$SCRUB_AGE") ago — past the $(span "$SCRUB_MAX_AGE") policy; next backup run will scrub"
    fi
    ;;
esac

SCAN=$(printf '%s\n' "$STATUS" |
  awk '/^[[:space:]]*scan:/ { f = 1 } /^[[:space:]]*config:/ { f = 0 } f' |
  sed 's/^[[:space:]]*scan:[[:space:]]*//; s/[[:space:]]\+/ /g' | tr -d '\n')
[ -n "$SCAN" ] && printf '    %s%s%s\n' "$d" "$SCAN" "$r"

# ── freshness ───────────────────────────────────────────────────────────────

printf '\n%sfreshness%s\n' "$b" "$r"

for pair in "${PAIRS[@]}"; do
  src=${pair%%:*}
  dst=${pair#*:}

  if ! timeout 30 zfs list -H -o name "$dst" >/dev/null 2>&1; then
    bad "$dst — MISSING on the backup pool"
    continue
  fi

  s_epoch=$(newest "$src")
  d_epoch=$(newest "$dst")
  count=$(timeout 30 zfs list -t snapshot -d 1 -H -o name "$dst" 2>/dev/null | grep -c .)

  if [ -z "$d_epoch" ]; then
    bad "$dst — no snapshots at all"
    continue
  fi

  # The gap that matters is backup-vs-source, not backup-vs-now: sanoid only
  # snapshots the source periodically, so a backup whose newest snapshot is
  # hours old can still hold literally everything the source has.
  if [ -n "$s_epoch" ]; then
    LAG=$(( s_epoch - d_epoch ))
    if   [ "$LAG" -le 0 ];     then ok "$dst — level with source ($count snapshots)"
    elif [ "$LAG" -lt 86400 ]; then ok "$dst — $(span "$LAG") behind source ($count snapshots)"
    else                            bad "$dst — $(span "$LAG") behind source ($count snapshots)"
    fi
  else
    note "$dst — $count snapshots (source has none to compare against)"
  fi

  printf '    %snewest: %s  (%s ago)%s\n' "$d" "$(newest_name "$dst")" \
    "$(span "$(( $(date +%s) - d_epoch ))")" "$r"
  printf '    %soldest: %s%s\n' "$d" "$(oldest_name "$dst")" "$r"
done

# ── capacity ────────────────────────────────────────────────────────────────

printf '\n%scapacity%s\n' "$b" "$r"

# A read-only import gives NO usable pool-level space accounting: the metaslab
# space maps are never loaded, so `zpool list` reports ALLOC 0 / FREE = full
# size / 0% however full the pool actually is. Taking that at face value would
# describe a pool holding a terabyte of snapshots as "0% used", and — worse —
# would let a fill-level threshold pass for entirely the wrong reason. So read
# the per-dataset `used` accounting, which is stored with the dataset itself and
# survives a read-only import, and refuse to print a pool percentage at all.
ALLOC=$(timeout 30 zpool list -Hp -o allocated "$POOL" 2>/dev/null)
SIZE=$(timeout 30 zpool list -Hp -o size "$POOL" 2>/dev/null)
USED=$(timeout 30 zfs get -Hp -o value used "$PARENT" 2>/dev/null)

[ -n "${USED:-}" ] && [ "$USED" -gt 0 ] &&
  printf '    %s%s holds %s (dataset accounting)%s\n' "$d" "$PARENT" \
    "$(awk -v v="$USED" 'BEGIN{ printf "%.0f GiB", v/1073741824 }')" "$r"

if [ "${ALLOC:-0}" -eq 0 ] && [ -n "${USED:-}" ] && [ "$USED" -gt 0 ]; then
  printf '    %spool fill %%: unavailable under a read-only import — zpool list%s\n' "$d" "$r"
  printf '    %swould claim 0%%. Re-import read-write to measure it.%s\n' "$d" "$r"
elif [ "${SIZE:-0}" -gt 0 ]; then
  CAP=$(( ALLOC * 100 / SIZE ))
  printf '    %s%s%% of %s allocated%s\n' "$d" "$CAP" \
    "$(awk -v v="$SIZE" 'BEGIN{ printf "%.2f TiB", v/1099511627776 }')" "$r"
  [ "$CAP" -ge 85 ] && note "pool is ${CAP}% full — replication will start failing"
fi

# ── verdict ─────────────────────────────────────────────────────────────────

printf '\n'
if [ "$VERDICT" -eq 0 ]; then
  printf '%sVERDICT: backup is current and shows no corruption%s\n' "$grn$b" "$r"
else
  printf '%sVERDICT: needs attention — see the flagged lines above%s\n' "$red$b" "$r"
fi
exit "$VERDICT"
