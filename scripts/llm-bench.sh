# llm-bench — tune the local llama-server against this machine, then report.
#
# Reads the llama-cpp unit's own command line, so it always tests what
# services.llama-cpp actually deploys, stops the unit for the duration (and
# starts it again afterwards if it was running), then:
#
#   1. fit      llama-server with the unit's real arguments — full context and
#               all — at decreasing --n-cpu-moe, to find the lowest value that
#               fits in VRAM. "Fits" is judged from amdgpu's sysfs counters,
#               not from whether the load succeeded: when VRAM runs out the
#               kernel quietly moves buffers to GTT (system RAM over PCIe) and
#               the server reports healthy anyway. On a 16 GiB card
#               n-cpu-moe 0 "loads" with 7 GiB sitting in GTT.
#   2. experts  llama-bench pp/tg across the n-cpu-moe values that fit.
#   3. ubatch   prompt processing across --ubatch-size.
#   4. threads  token generation across --threads.
#   5. depth    generation deep into the context, per KV cache type. Skipped
#               by --quick; it's the slow phase.
#   6. verify   the recommended settings in a real llama-server with the full
#               context, one ~4K-token request, against the current settings.
#
# Phase 1 uses the server rather than llama-bench because llama-bench only
# allocates KV for its own few thousand tokens: a value that fits there can
# still spill under the unit's full context.
#
# A setting is only recommended over the current one when it beats it by more
# than 2%, so run-to-run noise doesn't churn the config.
#
# The report and every raw llama-bench JSON / server log land in
# $XDG_STATE_HOME/llm-bench/<timestamp>/.

# jq programs are single-quoted on purpose; their $vars are jq's, not ours.
# shellcheck disable=SC2016
set -o errexit
set -o nounset
set -o pipefail

UNIT=${LLM_BENCH_UNIT:-llama-cpp}
PORT=${LLM_BENCH_PORT:-18080}
REPS=${LLM_BENCH_REPS:-3}
MARGIN_MIB=${LLM_BENCH_MARGIN_MIB:-512}
SPILL_MIB=256
OUT=${XDG_STATE_HOME:-$HOME/.local/state}/llm-bench
QUICK=0
MODEL_ARG=''

usage() {
  cat <<EOF
usage: llm-bench [--quick] [--model GGUF] [--out DIR]

Stops $UNIT, tunes n-cpu-moe / ubatch-size / threads against this GPU, checks
the result in a real llama-server, restores the unit, and writes a markdown
report. About 15 minutes; about 9 with --quick.

  --quick     skip the long-context / KV-type phase
  --model F   tune another GGUF with the unit's other settings (e.g. to
              compare quants before switching the unit to one)
  --out DIR   where reports go (default: $OUT)

Environment: LLM_BENCH_UNIT, LLM_BENCH_DEVICE (e.g. Vulkan1), LLM_BENCH_PORT,
LLM_BENCH_REPS, LLM_BENCH_MARGIN_MIB (VRAM to leave free, default 512).
EOF
}

while [ $# -gt 0 ]; do
  case $1 in
    --quick) QUICK=1 ;;
    --model)
      MODEL_ARG=${2:?--model needs a GGUF file}
      shift
      ;;
    --out)
      OUT=${2:?--out needs a directory}
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
  shift
done

# ── output ──────────────────────────────────────────────────────────────────

if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\e[1m' DIM=$'\e[2m' YEL=$'\e[33m' RST=$'\e[0m'
else
  BOLD='' DIM='' YEL='' RST=''
fi

WARNINGS=()
NOTES=()
step() { printf '%s==>%s %s\n' "$BOLD" "$RST" "$*" >&2; }
info() { printf '    %s%s%s\n' "$DIM" "$*" "$RST" >&2; }
warn() {
  WARNINGS+=("$*")
  printf '    %s! %s%s\n' "$YEL" "$*" "$RST" >&2
}
die() {
  printf 'llm-bench: %s\n' "$*" >&2
  exit 1
}
# Markdown goes to whichever section file $MD_OUT names; they're stitched
# together at the end so the summary can sit above the detail it summarises.
md() { printf '%s\n' "$@" >>"$MD_OUT"; }
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }
mib() { echo $(($1 / 1048576)); }
pct() { awk -v a="$1" -v b="$2" 'BEGIN { if (a > 0) printf "%+.1f%%", (b - a) / a * 100; else printf "n/a" }'; }
max() { if [ "$1" -gt "$2" ]; then echo "$1"; else echo "$2"; fi; }

# ── what the unit runs ──────────────────────────────────────────────────────

exec_start=$(systemctl show "$UNIT" -p ExecStart --value)
argv=$(sed -n 's/.*argv\[\]=\([^;]*\) ;.*/\1/p' <<<"$exec_start")
[ -n "$argv" ] || die "can't read the command line of $UNIT (is services.llama-cpp enabled?)"
read -ra ARGV <<<"$argv"
SERVER=${ARGV[0]}
BENCH=$(dirname "$SERVER")/llama-bench
[ -x "$BENCH" ] || die "no llama-bench next to $SERVER"

# CFG holds the unit's settings by long option name. KEEP_ARGS is the unit's
# argument list minus the options each probe sets itself, so a probe server is
# the unit's server with only those swapped out.
declare -A CFG=()
KEEP_ARGS=()
i=1
while [ "$i" -lt "${#ARGV[@]}" ]; do
  key=${ARGV[i]#--}
  val=${ARGV[i + 1]:-}
  if [ -z "$val" ] || [[ $val == --* ]]; then
    CFG[$key]=''
    width=1
  else
    CFG[$key]=$val
    width=2
  fi
  case $key in
    n-cpu-moe | ubatch-size | batch-size | threads | host | port | device) ;;
    *) KEEP_ARGS+=("${ARGV[@]:i:width}") ;;
  esac
  i=$((i + width))
done
cfg() { printf '%s' "${CFG[$1]:-$2}"; }

if [ -n "$MODEL_ARG" ]; then
  CFG[model]=$(readlink -f "$MODEL_ARG")
  for i in "${!KEEP_ARGS[@]}"; do
    if [ "${KEEP_ARGS[i]}" = --model ]; then KEEP_ARGS[i + 1]=${CFG[model]}; fi
  done
fi

MODEL=$(cfg model '')
[ -r "$MODEL" ] || die "model not readable: ${MODEL:-<unset>}"
PHYS=$(lscpu -p=core,socket | grep -v '^#' | sort -u | wc -l)
CTX=$(cfg ctx-size 4096)
CTK=$(cfg cache-type-k f16)
CTV=$(cfg cache-type-v f16)
NGL=$(cfg n-gpu-layers 99)
FA=$(cfg flash-attn auto)
LM=$(cfg load-mode auto)
NC0=$(cfg n-cpu-moe 0)
UB0=$(cfg ubatch-size 512)
BS0=$(cfg batch-size 2048)
T0=$(cfg threads "$PHYS")

# ── which GPU ───────────────────────────────────────────────────────────────

# The biggest amdgpu VRAM pool over 2 GiB; an APU's carve-out is far smaller.
CARD=''
VRAM_TOTAL=0
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  [ -r "$c/device/mem_info_vram_total" ] || continue
  t=$(<"$c/device/mem_info_vram_total")
  if [ "$t" -gt $((2 << 30)) ] && [ "$t" -gt "$VRAM_TOTAL" ]; then
    CARD=$(readlink -f "$c/device")
    VRAM_TOTAL=$t
  fi
done
[ -n "$CARD" ] || die "no amdgpu with more than 2 GiB of VRAM (the fit test reads amdgpu's sysfs counters)"
vram_used() { cat "$CARD/mem_info_vram_used"; }
gtt_used() { cat "$CARD/mem_info_gtt_used"; }

# llama.cpp's device for that card: the one whose total matches its VRAM. Not
# the biggest one — an APU reports all of shared system RAM as its own.
find_device() {
  "$BENCH" --list-devices 2>&1 | awk -v want="$(mib "$VRAM_TOTAL")" '
    !found && match($0, /^ *([A-Za-z]+[0-9]+): .*\(([0-9]+) MiB, [0-9]+ MiB free\)/, m) {
      d = m[2] - want; if (d < 0) d = -d
      if (d * 50 < want) found = m[1]
    }
    END { print found }'
}
DEV=${LLM_BENCH_DEVICE:-$(find_device)}
[ -n "$DEV" ] || die "couldn't match the GPU to a llama.cpp device; set LLM_BENCH_DEVICE (see $BENCH --list-devices)"
GPU_NAME=$("$BENCH" --list-devices 2>&1 | sed -n "s/^ *$DEV: \(.*\) ([0-9]* MiB.*/\1/p")

# The root port above the card is the real slot link; the ports below it on a
# Navi board are the card's internal switch and always report full speed.
pci_path=${CARD#*/pci????:??/}
ROOT_PORT=/sys/bus/pci/devices/${pci_path%%/*}
pci_path=${pci_path#*/}
CARD_PORT=/sys/bus/pci/devices/${pci_path%%/*}

# ── take the GPU ────────────────────────────────────────────────────────────

WAS_ACTIVE=0
if systemctl is-active --quiet "$UNIT"; then WAS_ACTIVE=1; fi

step "llm-bench: $(basename "$MODEL") on $GPU_NAME ($DEV)"
info "sudo is used to stop/start $UNIT and to read RAM speed with dmidecode"
as_root true || die "needs sudo"
KEEPALIVE=''
if [ "$(id -u)" -ne 0 ]; then
  (while sleep 60; do sudo -n -v 2>/dev/null || exit 0; done) &
  KEEPALIVE=$!
fi

PROBE=''
stop_probe() {
  if [ -n "$PROBE" ]; then
    kill "$PROBE" 2>/dev/null || true
    wait "$PROBE" 2>/dev/null || true
    PROBE=''
  fi
}
cleanup() {
  stop_probe
  if [ "$WAS_ACTIVE" = 1 ]; then
    step "restarting $UNIT"
    as_root systemctl start "$UNIT" || printf 'llm-bench: could not restart %s\n' "$UNIT" >&2
  fi
  if [ -n "$KEEPALIVE" ]; then kill "$KEEPALIVE" 2>/dev/null || true; fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if [ "$WAS_ACTIVE" = 1 ]; then
  step "stopping $UNIT for the duration"
  as_root systemctl stop "$UNIT"
fi
if pgrep -x 'llama-(server|bench)' >/dev/null; then
  die "another llama-server / llama-bench is running; stop it first"
fi
for _ in $(seq 20); do
  if [ "$(vram_used)" -lt $((1 << 30)) ]; then break; fi
  sleep 0.5
done
[ "$(vram_used)" -lt $((1 << 30)) ] || die "$(mib "$(vram_used)") MiB of VRAM still in use with $UNIT stopped"
if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then die "port $PORT is in use; set LLM_BENCH_PORT"; fi

DIR=$OUT/$(date +%Y%m%d-%H%M%S)
mkdir -p "$DIR"
MD_OUT=$DIR/phases.md

# ── probes ──────────────────────────────────────────────────────────────────

start_server() { # n-cpu-moe ubatch threads
  "$SERVER" "${KEEP_ARGS[@]}" --device "$DEV" --n-cpu-moe "$1" \
    --ubatch-size "$2" --batch-size "$(max "$2" "$BS0")" --threads "$3" \
    --host 127.0.0.1 --port "$PORT" >"$DIR/server-ncmoe$1-ub$2-t$3.log" 2>&1 &
  PROBE=$!
  for _ in $(seq 300); do
    sleep 1
    if ! kill -0 "$PROBE" 2>/dev/null; then
      wait "$PROBE" 2>/dev/null || true
      PROBE=''
      return 1
    fi
    if curl -sf -o /dev/null "http://127.0.0.1:$PORT/health"; then return 0; fi
  done
  stop_probe
  return 1
}

FIT_ROWS=()
fits() { # n-cpu-moe ubatch threads [keep] — 0 if it fits; "keep" leaves it running
  local gtt0 vram gtt free verdict ok=1
  gtt0=$(gtt_used)
  info "llama-server  n-cpu-moe=$1 ubatch=$2 threads=$3 ctx=$CTX"
  if ! start_server "$1" "$2" "$3"; then
    FIT_ROWS+=("| $1 | $2 | — | — | — | failed to load |")
    return 1
  fi
  # Measure after one full-size batch, not after the load: the compute buffer
  # for a large ubatch is only allocated when the first batch needs it. At
  # ubatch 4096 that's ~1.6 GiB more than the load leaves room for.
  request 1 >/dev/null || true
  vram=$(vram_used)
  gtt=$(($(gtt_used) - gtt0))
  free=$((VRAM_TOTAL - vram))
  if [ "$gtt" -gt $((SPILL_MIB << 20)) ]; then
    verdict="spills $(mib "$gtt") MiB to system RAM"
  elif [ "$free" -lt $((MARGIN_MIB << 20)) ]; then
    verdict="under the $MARGIN_MIB MiB margin"
  else
    verdict=fits
    ok=0
  fi
  info "  VRAM $(mib "$vram") MiB used, $(mib "$free") MiB free, GTT +$(mib "$gtt") MiB: $verdict"
  FIT_ROWS+=("| $1 | $2 | $(mib "$vram") MiB | $(mib "$free") MiB | $(mib "$gtt") MiB | $verdict |")
  if [ "$ok" != 0 ] || [ "${4:-}" != keep ]; then stop_probe; fi
  return "$ok"
}

bench() { # phase-name llama-bench-args…
  local name=$1
  shift
  info "llama-bench $*"
  if ! "$BENCH" -m "$MODEL" -dev "$DEV" -ngl "$NGL" -fa "$FA" -lm "$LM" -r "$REPS" \
    -o json "$@" >"$DIR/$name.json" 2>"$DIR/$name.log"; then
    warn "llama-bench failed in the $name phase; see $DIR/$name.log"
    return 1
  fi
}

bench_table() { # json files…
  md "| n-cpu-moe | ubatch | threads | KV | test | t/s |" "|---:|---:|---:|---|---|---:|"
  jq -r '.[] | "| \(.n_cpu_moe) | \(.n_ubatch) | \(.n_threads) | \(.type_k) | \(if .n_prompt > 0 then "pp\(.n_prompt)" else "tg\(.n_gen)" end)\(if .n_depth > 0 then " @ \(.n_depth) deep" else "" end) | \(.avg_ts * 10 | round / 10) ± \(.stddev_ts * 10 | round / 10) |"' "$@" >>"$MD_OUT"
  md ""
}

# The value of $key to use: the current one unless another beats it by >2%.
pick() { # json key current test-filter
  jq -r --arg k "$2" --argjson cur "$3" '
    [.[] | select('"$4"')] as $t
    | ($t | map(.avg_ts) | max) as $m
    | ($t | map(select(.[$k] == $cur)) | first) as $c
    | if $c != null and $c.avg_ts >= $m * 0.98 then $cur else ($t | max_by(.avg_ts) | .[$k]) end' "$1"
}

# Prose a bit longer than the largest ubatch tested (~59 tokens a paragraph),
# so every probe runs at least one full-size batch; less if the context is
# small.
para="The lighthouse keeper logged the weather every hour: wind from the north-west, swell rising, visibility falling as the fog came in off the banks. Ships passed in the night and each was entered in the book with its heading, its lights, and the time it cleared the headland."
nparas=$((($(max 4096 "$UB0") + 512) / 59 + 1))
if [ "$nparas" -gt $((CTX / 140)) ]; then nparas=$((CTX / 140)); fi
PROMPT=$(for _ in $(seq "$nparas"); do printf '%s\n' "$para"; done; printf 'Summarise the log above.\n')

request() { # n-predict → the response's timings object
  jq -n --arg p "$PROMPT" --argjson n "$1" '{prompt: $p, n_predict: $n, ignore_eos: true, cache_prompt: false}' |
    curl -sf "http://127.0.0.1:$PORT/completion" -H 'Content-Type: application/json' --data-binary @- |
    jq -c .timings
}

LINK_LOADED=''
declare -A E2E_PP=() E2E_TG=()
E2E_ROWS=()
e2e() { # label n-cpu-moe ubatch threads — against the running probe
  local t sampler=''
  request 256 >/dev/null || true # first request compiles the remaining pipelines
  # amdgpu drops the link speed when idle, so sample it mid-request.
  if [ -z "$LINK_LOADED" ] && [ -r "$ROOT_PORT/current_link_speed" ]; then
    (sleep 3 && cat "$ROOT_PORT/current_link_speed" >"$DIR/link-under-load") &
    sampler=$!
  fi
  if ! t=$(request 256); then
    warn "the $1 request to llama-server failed; see $DIR/server-ncmoe$2-ub$3-t$4.log"
    return 1
  fi
  if [ -n "$sampler" ]; then wait "$sampler" || true; fi
  if [ -z "$LINK_LOADED" ] && [ -s "$DIR/link-under-load" ]; then LINK_LOADED=$(<"$DIR/link-under-load"); fi
  E2E_PP[$1]=$(jq -r .prompt_per_second <<<"$t")
  E2E_TG[$1]=$(jq -r .predicted_per_second <<<"$t")
  E2E_ROWS+=("$(jq -r --arg l "$1" --arg c "$2 / $3 / $4" '"| \($l) | \($c) | \(.prompt_n) | \(.prompt_per_second | round) | \(.predicted_per_second * 10 | round / 10) |"' <<<"$t")")
  info "  $1: pp $(printf '%.0f' "${E2E_PP[$1]}") t/s, tg $(printf '%.1f' "${E2E_TG[$1]}") t/s"
}

# ── 1. fit ──────────────────────────────────────────────────────────────────

step "1/6  VRAM fit at the unit's full context ($CTX tokens)"
n=$NC0
BASE_FITS=0
if fits "$n" "$UB0" "$T0"; then
  BASE_FITS=1
  while [ "$n" -gt 0 ] && fits $((n - 1)) "$UB0" "$T0"; do n=$((n - 1)); done
else
  warn "the current n-cpu-moe $NC0 does not fit cleanly at ctx $CTX"
  found=0
  while [ "$n" -lt $((NC0 + 16)) ]; do
    n=$((n + 1))
    if fits "$n" "$UB0" "$T0"; then
      found=1
      break
    fi
  done
  [ "$found" = 1 ] || die "nothing up to n-cpu-moe $n fits in VRAM at ctx $CTX"
fi
NC_FIT=$n
info "lowest n-cpu-moe that fits: $NC_FIT"

md "## 1. VRAM fit" "" \
  "llama-server with the unit's own arguments: ${CTX}-token context, KV $CTK/$CTV, ubatch $UB0." \
  "\"Spills\" means amdgpu moved buffers to GTT (system RAM over PCIe) instead of failing the load." \
  "The margin keeps $MARGIN_MIB MiB of VRAM free." "" \
  "| n-cpu-moe | ubatch | VRAM used | VRAM free | GTT growth | result |" \
  "|---:|---:|---:|---:|---:|---|" "${FIT_ROWS[@]}" ""
FIT_ROWS=()

# ── 2. experts on CPU ───────────────────────────────────────────────────────

step "2/6  experts on CPU vs GPU"
if [ "$BASE_FITS" = 1 ] && [ $((NC0 - NC_FIT)) -le 5 ]; then
  cands=$(seq -s, "$NC_FIT" "$NC0")
elif [ "$BASE_FITS" = 1 ]; then
  cands="$(seq -s, "$NC_FIT" $((NC_FIT + 3))),$NC0"
else
  cands=$(seq -s, "$NC_FIT" $((NC_FIT + 2)))
fi
NC=$NC_FIT
if bench experts -ncmoe "$cands" -ub "$UB0" -b "$(max "$UB0" "$BS0")" -t "$T0" \
  -ctk "$CTK" -ctv "$CTV" -p 4096 -n 128; then
  NC=$(pick "$DIR/experts.json" n_cpu_moe "$NC0" '.n_gen > 0')
  md "## 2. Experts on CPU" "" "Only values that fit in phase 1. Picked on tg: **n-cpu-moe $NC**." ""
  bench_table "$DIR/experts.json"
elif [ "$BASE_FITS" = 1 ]; then
  NC=$NC0
fi
NC2=$NC
info "n-cpu-moe: $NC"

# ── 3. ubatch ───────────────────────────────────────────────────────────────

step "3/6  prompt-processing batch size"
ubs=$(printf '%s\n' 512 1024 2048 4096 "$UB0" | sort -nu | paste -sd,)
UB=$UB0
if bench ubatch -ncmoe "$NC" -ub "$ubs" -b "$(max 4096 "$UB0")" -t "$T0" \
  -ctk "$CTK" -ctv "$CTV" -p 4096 -n 0; then
  UB=$(pick "$DIR/ubatch.json" n_ubatch "$UB0" '.n_prompt > 0')
  md "## 3. ubatch-size" "" "Picked on pp: **ubatch-size $UB**." ""
  bench_table "$DIR/ubatch.json"
fi
info "ubatch-size: $UB"

# ── 4. threads ──────────────────────────────────────────────────────────────

step "4/6  CPU threads"
ts=$(printf '%s\n' $((PHYS / 2)) $((PHYS - 2)) $((PHYS - 1)) "$PHYS" "$(nproc)" "$T0" |
  awk '$1 > 0' | sort -nu | paste -sd,)
T=$T0
if bench threads -ncmoe "$NC" -ub "$UB" -b "$(max "$UB" "$BS0")" -t "$ts" \
  -ctk "$CTK" -ctv "$CTV" -p 0 -n 128; then
  T=$(pick "$DIR/threads.json" n_threads "$T0" '.n_gen > 0')
  md "## 4. threads" "" "$PHYS physical cores, $(nproc) threads. Picked on tg: **threads $T**." ""
  bench_table "$DIR/threads.json"
fi
info "threads: $T"

# ── 5. depth / KV type ──────────────────────────────────────────────────────

DEPTH=$((CTX / 2))
if [ "$DEPTH" -gt 32768 ]; then DEPTH=32768; fi
if [ "$QUICK" = 1 ]; then
  step "5/6  long context: skipped (--quick)"
else
  step "5/6  generation $DEPTH tokens deep, per KV type"
  depth_files=()
  for ty in $(printf '%s\n' "$CTK" bf16 | awk '!seen[$0]++'); do
    if REPS=2 bench "depth-$ty" -ncmoe "$NC" -ub "$UB" -b "$(max "$UB" "$BS0")" -t "$T" \
      -ctk "$ty" -ctv "$ty" -d "0,$DEPTH" -p 512 -n 128; then
      depth_files+=("$DIR/depth-$ty.json")
    fi
  done
  if [ "${#depth_files[@]}" -gt 0 ]; then
    md "## 5. Long context" "" \
      "Speed at the start of the context and $DEPTH tokens into it. bf16 KV is Unsloth's recommendation for this model family; this shows what it costs." ""
    jq -rs --argjson d "$DEPTH" '
      add | map(select(.n_gen > 0)) | group_by(.type_k)[]
      | (map(select(.n_depth == 0))[0].avg_ts) as $a
      | (map(select(.n_depth == $d))[0].avg_ts) as $b
      | "- \(.[0].type_k) KV: tg \($a * 10 | round / 10) → \($b * 10 | round / 10) t/s at \($d) deep (\(($b - $a) / $a * 100 | round)%)"' \
      "${depth_files[@]}" >>"$MD_OUT" || true
    md ""
    bench_table "${depth_files[@]}"
  fi
fi

# ── 6. verify ───────────────────────────────────────────────────────────────

step "6/6  end-to-end in llama-server, full context"

# The benchmark phases run with a small context, so their picks are only
# candidates. Each one is run end-to-end here and the winner is chosen on the
# measured numbers. "tuned" is everything combined; "tuned-ub$UB0" keeps the
# current ubatch, whose compute buffer phase 1 already fitted — if the bigger
# ubatch doesn't fit next to the experts it would otherwise cost the n-cpu-moe
# win as well.
declare -A V_NC=() V_UB=() V_T=()
verify() { # label n-cpu-moe ubatch threads
  local nc=$2
  while [ "$nc" -le $((NC_FIT + 16)) ]; do
    if fits "$nc" "$3" "$4" keep; then
      if e2e "$1" "$nc" "$3" "$4"; then V_NC[$1]=$nc V_UB[$1]=$3 V_T[$1]=$4; fi
      stop_probe
      return 0
    fi
    nc=$((nc + 1))
  done
  return 1
}
# Worth switching to: >2% more tg, or the same tg and >5% more pp.
beats() { # label reference-label
  awk -v t="${E2E_TG[$1]}" -v p="${E2E_PP[$1]}" -v rt="${E2E_TG[$2]}" -v rp="${E2E_PP[$2]}" \
    'BEGIN { exit !(t > rt * 1.02 || (t >= rt * 0.98 && p > rp * 1.05)) }'
}

if [ "$BASE_FITS" = 1 ]; then verify current "$NC0" "$UB0" "$T0" || true; fi
cands=()
if [ "$NC" != "$NC0" ] || [ "$UB" != "$UB0" ] || [ "$T" != "$T0" ]; then
  verify tuned "$NC" "$UB" "$T" || true
  cands+=(tuned)
fi
if [ "$UB" != "$UB0" ] && { [ "$NC2" != "$NC0" ] || [ "$T" != "$T0" ]; }; then
  verify "tuned-ub$UB0" "$NC2" "$UB0" "$T" || true
  cands+=("tuned-ub$UB0")
fi

best=''
if [ -n "${V_NC[current]:-}" ]; then best=current; fi
for c in "${cands[@]}"; do
  [ -n "${V_NC[$c]:-}" ] || continue
  if [ -z "$best" ] || beats "$c" "$best"; then best=$c; fi
done
if [ -z "$best" ]; then
  warn "no configuration could be verified end-to-end; keeping the current settings"
  best=current V_NC[current]=$NC0 V_UB[current]=$UB0 V_T[current]=$T0
elif [ "$best" = current ] && [ "${#cands[@]}" -gt 0 ]; then
  warn "none of the benchmark picks beat the current settings end-to-end, so keeping them"
fi
NC=${V_NC[$best]} UB=${V_UB[$best]} T=${V_T[$best]}
SAME=0
if [ "$NC" = "$NC0" ] && [ "$UB" = "$UB0" ] && [ "$T" = "$T0" ]; then SAME=1; fi
info "chosen: $best (n-cpu-moe $NC, ubatch $UB, threads $T)"

md "## 6. End-to-end" "" \
  "A real llama-server with the full ${CTX}-token context: one warm-up request, then one ~$((nparas * 59))-token prompt with 256 generated tokens. Chosen: **$best**." "" \
  "| settings | n-cpu-moe / ubatch / threads | prompt tokens | pp t/s | tg t/s |" \
  "|---|---:|---:|---:|---:|" "${E2E_ROWS[@]}" ""
if [ "${#FIT_ROWS[@]}" -gt 0 ]; then
  md "VRAM at each end-to-end load:" "" \
    "| n-cpu-moe | ubatch | VRAM used | VRAM free | GTT growth | result |" \
    "|---:|---:|---:|---:|---:|---|" "${FIT_ROWS[@]}" ""
fi

# ── host ────────────────────────────────────────────────────────────────────

step "host checks"
MD_OUT=$DIR/host.md
md "## Host" "" "| | |" "|---|---|"
md "| GPU | $GPU_NAME ($DEV), $(mib "$VRAM_TOTAL") MiB, power level $(cat "$CARD/power_dpm_force_performance_level" 2>/dev/null || echo n/a) |"
if [ -r "$ROOT_PORT/current_link_speed" ]; then
  slot_max=$(<"$ROOT_PORT/max_link_speed")
  card_max=$(cat "$CARD_PORT/max_link_speed" 2>/dev/null || echo "$slot_max")
  link=${LINK_LOADED:-$(<"$ROOT_PORT/current_link_speed")}
  md "| PCIe | ${link% PCIe} x$(<"$ROOT_PORT/current_link_width") under load (slot max ${slot_max% PCIe}, card max ${card_max% PCIe}) |"
  if [ "${link%% *}" != "${slot_max%% *}" ]; then
    warn "the GPU link ran at ${link% PCIe} under load, below the slot's ${slot_max% PCIe}; check the card is in the CPU x16 slot and the BIOS PCIe setting"
  fi
  if awk -v s="${slot_max%% *}" -v c="${card_max%% *}" 'BEGIN { exit !(s < c) }'; then
    NOTES+=("The slot tops out at ${slot_max% PCIe}; the card supports ${card_max% PCIe}. Prompt processing streams the CPU-side experts over this link, so only a faster slot would lift pp further. Nothing to fix in software.")
  fi
fi
md "| CPU | $(lscpu | sed -n 's/^Model name: *//p'), $PHYS cores / $(nproc) threads |"
cpufreq=/sys/devices/system/cpu/cpu0/cpufreq
gov=$(cat "$cpufreq/scaling_governor" 2>/dev/null || echo n/a)
epp=$(cat "$cpufreq/energy_performance_preference" 2>/dev/null || echo n/a)
md "| CPU governor / EPP | $gov / $epp |"
if [ "$epp" = power ]; then warn "the CPU energy-performance preference is \"power\"; token generation leans on the CPU-side experts"; fi
if dmidecode=$(command -v dmidecode) && dmi=$(as_root "$dmidecode" -t memory 2>/dev/null); then
  rated=$(awk -F': ' '/^\tSpeed: [0-9]/ { print $2 + 0; exit }' <<<"$dmi")
  conf=$(awk -F': ' '/^\tConfigured Memory Speed: [0-9]/ { print $2 + 0; exit }' <<<"$dmi")
  md "| RAM | $(free -g | awk '/^Mem:/ { print $2 }') GiB at ${conf:-?} MT/s (JEDEC ${rated:-?}) |"
  if [ -n "$conf" ] && [ -n "$rated" ] && [ "$conf" -le "$rated" ]; then
    warn "RAM runs at its JEDEC $conf MT/s, so EXPO/XMP looks off; the CPU-side experts are memory-bound, so this caps tg directly"
  fi
fi
md "| Kernel | $(uname -r) |"
if [ -s "$DIR/experts.json" ]; then
  md "| llama.cpp | $(jq -r '.[0] | "build \(.build_number) (\(.build_commit)), \(.backends)"' "$DIR/experts.json") |"
fi
md ""

# ── report ──────────────────────────────────────────────────────────────────

MD_OUT=$DIR/summary.md
md "# llm-bench: $(uname -n), $(date '+%F %R')" "" \
  "$(basename "$MODEL") ($(mib "$(stat -c %s "$MODEL")") MiB) · unit \`$UNIT\` · ctx $CTX · KV $CTK/$CTV · took $((SECONDS / 60)) min" "" \
  "## Summary" ""
if [ "$SAME" = 1 ]; then
  md "- **The current settings are already the best found** (n-cpu-moe $NC0, ubatch-size $UB0, threads $T0)."
else
  md "- **Recommended:** n-cpu-moe $NC (now $NC0), ubatch-size $UB (now $UB0), threads $T (now $T0)."
fi
if [ -n "${E2E_TG[$best]:-}" ] && [ -n "${E2E_TG[current]:-}" ] && [ "$SAME" = 0 ]; then
  md "- End-to-end at full context: tg $(printf '%.1f' "${E2E_TG[current]}") → $(printf '%.1f' "${E2E_TG[$best]}") t/s ($(pct "${E2E_TG[current]}" "${E2E_TG[$best]}")), pp $(printf '%.0f' "${E2E_PP[current]}") → $(printf '%.0f' "${E2E_PP[$best]}") t/s ($(pct "${E2E_PP[current]}" "${E2E_PP[$best]}"))."
elif [ -n "${E2E_TG[$best]:-}" ]; then
  md "- End-to-end at full context: tg $(printf '%.1f' "${E2E_TG[$best]}") t/s, pp $(printf '%.0f' "${E2E_PP[$best]}") t/s."
fi
for w in "${WARNINGS[@]}"; do md "- ⚠ $w"; done
for n in "${NOTES[@]}"; do md "- $n"; done
md ""
if [ "$SAME" = 0 ]; then
  md "Change in \`services.llama-cpp.settings\`:" "" '```nix'
  if [ "$NC" != "$NC0" ]; then md "n-cpu-moe = $NC; # was $NC0"; fi
  if [ "$UB" != "$UB0" ]; then md "ubatch-size = $UB; # was $UB0"; fi
  if [ "$UB" -gt "$BS0" ]; then md "batch-size = $UB; # was $BS0; must be at least ubatch-size"; fi
  if [ "$T" != "$T0" ]; then md "threads = $T; # was $T0"; fi
  md '```' ""
fi

REPORT=$DIR/report.md
cat "$DIR/summary.md" "$DIR/host.md" "$DIR/phases.md" >"$REPORT"
rm -f "$DIR/summary.md" "$DIR/host.md" "$DIR/phases.md" "$DIR/link-under-load"

printf '\n' >&2
cat "$REPORT"
step "report: $REPORT"
