# llm-stress — one person's coding-agent session against llama-server, the way
# opencode drives it, measured turn by turn.
#
# Runs a real agent loop: the model gets opencode-shaped tools (read_file,
# list_dir, grep, write_file) over a read-only view of a project and a task
# that keeps it reading and rewriting files, so the context grows turn by turn
# toward --target tokens like a long session does. Each turn records what the
# user waits for: how many tokens the server had to (re)process, prefill time,
# generation speed, and the GPU/CPU/RAM temperatures and power meanwhile.
#
# History goes back the way opencode sends it (assistant content and tool
# calls, no reasoning_content), since that's what decides whether the prompt
# cache hits. Qwen3.6 is a hybrid (Gated DeltaNet), so llama.cpp can't partly
# roll its state back: a turn whose history doesn't match the cache is
# re-processed from the last checkpoint, which at 100K is a minute. Those turns
# are flagged as cache misses. At the end one request with a changed first
# token measures the worst case: prefilling the whole context cold.
#
# write_file never writes. It answers "wrote" and the content is dropped. It's
# there because rewriting a file is the most repetitive output an agent makes,
# which is what n-gram speculative decoding speeds up.
#
#   llm-stress            against the running server; leaves the unit alone
#   llm-stress --sweep    stops the unit, runs the same session once per server
#                         variant, then starts the unit again
#
# Reports and per-turn TSVs land in $XDG_STATE_HOME/llm-stress/<timestamp>/.

# jq/awk programs are single-quoted on purpose; their $vars aren't ours.
# shellcheck disable=SC2016
set -o errexit
set -o nounset
set -o pipefail

URL=http://127.0.0.1:8080
TARGET=''
ROOT=/persist/source-of-truth
if [ ! -d "$ROOT" ]; then ROOT=$PWD; fi
MAX_TURNS=150
GEN_MAX=16384
SWEEP=0
KEEP_REASONING=0
THINK=1
VARIANTS=()
UNIT=${LLM_STRESS_UNIT:-llama-cpp}
PORT=${LLM_STRESS_PORT:-18081}
OUT=${XDG_STATE_HOME:-$HOME/.local/state}/llm-stress

usage() {
  cat <<EOF
usage: llm-stress [options]

One agent session, grown turn by turn to --target tokens of context.

  --url URL           server to drive (default $URL); ignored by --sweep
  --target N          context to grow to, e.g. 100K (default: 64K, or 3/4 of
                      the server's context if that's smaller)
  --root DIR          project the agent works on, read-only (default $ROOT)
  --max-turns N       give up after N turns (default $MAX_TURNS)
  --max-output N      output-token limit per reply (default $GEN_MAX, opencode
                      uses the model's limit.output)
  --no-think          disable Qwen's thinking mode for every request
  --keep-reasoning    send reasoning_content back in the history (opencode
                      doesn't; this shows what it would change)
  --sweep             stop $UNIT and run the session once per variant
  --variant NAME=FLAGS
                      a variant for --sweep: llama-server long options added to
                      the unit's own, replacing any it already sets. Repeat for
                      several; implies --sweep. Default set: current and ngram-mod
                      (--spec-type ngram-mod). A variant that needs more VRAM,
                      like bf16 KV, needs its own --n-cpu-moe too.
  --out DIR           where reports go (default $OUT)

A 64K session takes about 20 minutes per variant, mostly generation.
EOF
}

while [ $# -gt 0 ]; do
  case $1 in
    --url)
      URL=${2:?--url needs a URL}
      shift
      ;;
    --target)
      TARGET=${2:?--target needs a token count}
      shift
      ;;
    --root)
      ROOT=${2:?--root needs a directory}
      shift
      ;;
    --max-turns)
      MAX_TURNS=${2:?--max-turns needs a number}
      shift
      ;;
    --max-output)
      GEN_MAX=${2:?--max-output needs a number}
      shift
      ;;
    --no-think) THINK=0 ;;
    --keep-reasoning) KEEP_REASONING=1 ;;
    --sweep) SWEEP=1 ;;
    --variant)
      VARIANTS+=("${2:?--variant needs NAME=FLAGS}")
      SWEEP=1
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
step() { printf '%s==>%s %s\n' "$BOLD" "$RST" "$*" >&2; }
info() { printf '    %s%s%s\n' "$DIM" "$*" "$RST" >&2; }
warn() {
  WARNINGS+=("$*")
  printf '    %s! %s%s\n' "$YEL" "$*" "$RST" >&2
}
die() {
  printf 'llm-stress: %s\n' "$*" >&2
  exit 1
}
md() { printf '%s\n' "$@" >>"$MD_OUT"; }
as_root() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi; }
mib() { echo $(($1 / 1048576)); }
kfmt() { awk -v n="$1" 'BEGIN { printf "%.1fK", n / 1024 }'; }

ROOT=$(realpath -e -- "$ROOT") || die "no such directory: $ROOT"
[ -d "$ROOT" ] || die "not a directory: $ROOT"
case $TARGET in *[kK]) TARGET=$((${TARGET%[kK]} * 1024)) ;; esac

# ── the agent's tools ───────────────────────────────────────────────────────

# A path the agent gave, resolved inside ROOT, or failure. Symlinks are
# resolved before the check, and hidden files and directories are refused so
# nothing like a .git or a stray key ends up in the transcript.
safe_path() {
  local p
  # Models pass ".", "hosts/x.nix", "/hosts/x.nix" and the absolute project
  # path interchangeably; all of them mean somewhere under ROOT.
  case $1 in
    "$ROOT" | "$ROOT"/*) p=$1 ;;
    *) p=$ROOT/${1#/} ;;
  esac
  p=$(realpath -m -- "$p") || return 1
  case $p in "$ROOT" | "$ROOT"/*) ;; *) return 1 ;; esac
  # Checked on the resolved path, so "." and "./x" pass but ".git" doesn't.
  case ${p#"$ROOT"}/ in */.*) return 1 ;; esac
  local IFS=/ part g
  for part in ${p#"$ROOT"}; do
    for g in "${EXCLUDE[@]}"; do
      # shellcheck disable=SC2254  # $g is a glob on purpose
      case $part in $g) return 1 ;; esac
    done
  done
  printf '%s' "$p"
}
# Never shown to the model: its transcript is saved in the report directory.
EXCLUDE=(passwords secrets '*secret*' '*.key' '*.pem' 'id_*' '*.age')
GREP_EXCLUDE=(--exclude-dir='.?*' --exclude='.?*')
for g in "${EXCLUDE[@]}"; do GREP_EXCLUDE+=(--exclude-dir="$g" --exclude="$g"); done

run_tool() { # name args-json → the tool's output
  local p pat
  case $1 in
    read_file)
      if ! p=$(safe_path "$(jq -r '(.path? // "") | tostring' <<<"$2")"); then
        echo "error: path is outside the project"
      elif [ ! -f "$p" ]; then
        echo "error: no such file"
      elif ! grep -Iq . "$p"; then
        echo "error: empty or binary file"
      else
        # Cut long files like opencode does, without a pipe that could die of
        # SIGPIPE under pipefail.
        awk 'NR > 400 || n > 24000 { print "[... truncated]"; exit } { n += length($0) + 1; print }' "$p"
      fi
      ;;
    list_dir)
      if ! p=$(safe_path "$(jq -r '(.path? // ".") | tostring' <<<"$2")"); then
        echo "error: path is outside the project"
      elif [ ! -d "$p" ]; then
        echo "error: no such directory"
      else
        local e
        while IFS= read -r e; do
          if safe_path "${p#"$ROOT"}/${e%/}" >/dev/null; then printf '%s\n' "$e"; fi
        done < <(find "$p" -mindepth 1 -maxdepth 1 -printf '%f%y\n' | sed 's/d$/\//; s/[fl]$//' | sort) |
          awk 'NR <= 200'
      fi
      ;;
    grep)
      pat=$(jq -r '(.pattern? // "") | tostring' <<<"$2")
      if ! p=$(safe_path "$(jq -r '(.path? // ".") | tostring' <<<"$2")"); then
        echo "error: path is outside the project"
      elif [ -z "$pat" ]; then
        echo "error: empty pattern"
      else
        p=${p#"$ROOT"}
        p=${p#/}
        (cd "$ROOT" && { grep -rnIE "${GREP_EXCLUDE[@]}" -e "$pat" -- "${p:-.}" 2>/dev/null || true; }) |
          awk 'NR <= 100 { print } END { if (NR == 0) print "no matches"; else if (NR > 100) print "[" NR - 100 " more]" }'
      fi
      ;;
    write_file)
      jq -r '"Wrote \((.path? // "?") | tostring) (\((.content? // "") | tostring | split("\n") | length) lines)."' <<<"$2"
      ;;
    *) echo "error: unknown tool $1" ;;
  esac
}

tools_json() {
  jq -n '[
    {type: "function", function: {name: "read_file",
      description: "Read a text file. Paths are relative to the project root. Files longer than 400 lines are cut.",
      parameters: {type: "object", properties: {path: {type: "string", description: "Path relative to the project root"}}, required: ["path"]}}},
    {type: "function", function: {name: "list_dir",
      description: "List a directory. Subdirectories end in /.",
      parameters: {type: "object", properties: {path: {type: "string", description: "Directory relative to the project root; . for the root"}}, required: ["path"]}}},
    {type: "function", function: {name: "grep",
      description: "Search file contents with an extended regular expression. Returns file:line:text, at most 100 matches.",
      parameters: {type: "object", properties: {pattern: {type: "string"}, path: {type: "string", description: "Directory to search; default ."}}, required: ["pattern"]}}},
    {type: "function", function: {name: "write_file",
      description: "Replace a file with new content. Always write the complete file.",
      parameters: {type: "object", properties: {path: {type: "string"}, content: {type: "string", description: "The complete new file"}}, required: ["path", "content"]}}}
  ]'
}

# Shaped like an agent harness's prompt: rules first, then the project's own
# instruction files, which opencode loads from AGENTS.md / CLAUDE.md.
SYSTEM="You are a coding agent working in a software project. You act only through the tools you are given; every path is relative to the project root.

# How to work
- Make one tool call at a time and wait for its result.
- Read a file before changing it. To change a file, call write_file with the complete new file; never abbreviate with comments like \"rest unchanged\".
- Keep replies short. Don't announce what you're about to do; do it.
- Don't ask questions and don't summarise your progress. Keep going until the task is done."
for f in AGENTS.md CLAUDE.md; do
  if [ -f "$ROOT/$f" ]; then
    SYSTEM+=$'\n\n'"# Project instructions ($f)"$'\n\n'"$(<"$ROOT/$f")"
  fi
done
TASK="Add a one-line summary comment at the top of every source file in this project, one file at a time. For each file, read it with read_file, then call write_file with the complete file content, unchanged except for a new first line: a comment in that language's syntax saying in one sentence what the file does. Start with list_dir on the project root, then go directory by directory. Do one file per step, and don't stop until every file is done."
NUDGE="Continue with the next file."

# ── hardware sampling ───────────────────────────────────────────────────────

hwmon_named() {
  local h
  for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = "$1" ]; then
      echo "$h"
      return
    fi
  done
}
CARD='' VRAM_TOTAL=0 GPU_HW=''
for c in /sys/class/drm/card*; do
  case ${c##*/} in *-*) continue ;; esac
  if [ -r "$c/device/mem_info_vram_total" ]; then
    t=$(<"$c/device/mem_info_vram_total")
    if [ "$t" -gt $((2 << 30)) ] && [ "$t" -gt "$VRAM_TOTAL" ]; then
      CARD=$(readlink -f "$c/device")
      VRAM_TOTAL=$t
    fi
  fi
done
if [ -n "$CARD" ]; then
  for h in "$CARD"/hwmon/hwmon*; do
    if [ -d "$h" ]; then GPU_HW=$h; fi
    break
  done
fi
CPU_HW=$(hwmon_named k10temp)
if [ -z "$CPU_HW" ]; then CPU_HW=$(hwmon_named coretemp); fi
RAM_HW=()
for h in /sys/class/hwmon/hwmon*; do
  if [ "$(cat "$h/name" 2>/dev/null)" = spd5118 ]; then RAM_HW+=("$h"); fi
done

milli() { if [ -r "$1" ]; then echo $(($(<"$1") / 1000)); else echo -; fi; }
# One line: VRAM MiB, GTT MiB, GPU junction °C, GPU memory °C, GPU W, CPU °C,
# hottest DIMM °C. "-" for anything this machine doesn't have.
sample() {
  local vram=- gtt=- w=- ram=- p h t
  if [ -n "$CARD" ]; then
    vram=$(mib "$(<"$CARD/mem_info_vram_used")")
    gtt=$(mib "$(<"$CARD/mem_info_gtt_used")")
  fi
  for p in "$GPU_HW/power1_average" "$GPU_HW/power1_input"; do
    if [ -r "$p" ]; then
      w=$(($(<"$p") / 1000000))
      break
    fi
  done
  for h in "${RAM_HW[@]}"; do
    t=$(milli "$h/temp1_input")
    if [ "$t" != - ] && { [ "$ram" = - ] || [ "$t" -gt "$ram" ]; }; then ram=$t; fi
  done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$vram" "$gtt" "$(milli "$GPU_HW/temp2_input")" \
    "$(milli "$GPU_HW/temp3_input")" "$w" "$(milli "$CPU_HW/temp1_input")" "$ram"
}
sampler() { while :; do sample >>"$1"; sleep 2; done; }
# The per-column maximum of a sampler file; a turn's peaks, not its end state.
hw_max() {
  awk -F'\t' '
    { for (i = 1; i <= 7; i++) if ($i != "-" && (!(i in m) || $i + 0 > m[i])) m[i] = $i + 0 }
    END { for (i = 1; i <= 7; i++) printf "%s%s", (i in m) ? m[i] : "-", (i < 7) ? "\t" : "\n" }' "$1"
}

# ── the session ─────────────────────────────────────────────────────────────

declare -A S_STOP=() S_BAD=() S_CUT=() S_COLD=() S_NOTES=()
SPID=""
GTT0=0

run_session() { # label base-url
  local label=$1 base=$2 d=$DIR/$1
  local msgs=$d/messages.json tsv=$d/turns.tsv
  local turn=0 ctx=0 prev=0 idle=0 bad=0 cut=0 stop
  stop="reached $(kfmt "$TARGET") of context"
  local resp t0 t1 cache_n prompt_n prompt_ms gen_n gen_ms draft_n draft_ok finish
  local prefill_s gen_tps turn_s miss ncalls k name id args out names kind hw
  mkdir -p "$d"
  jq -n --arg sys "$SYSTEM" --arg task "$TASK" \
    '[{role: "system", content: $sys}, {role: "user", content: $task}]' >"$msgs"
  printf 'turn\tctx\tcache_n\tprompt_n\tprefill_s\tgen_n\tgen_tps\tdraft_n\tdraft_ok\tturn_s\tkind\tmiss\ttools\tvram_mib\tgtt_mib\tgpu_junction_c\tgpu_mem_c\tgpu_w\tcpu_c\tram_c\n' >"$tsv"

  while [ "$ctx" -lt "$TARGET" ]; do
    if [ "$turn" -ge "$MAX_TURNS" ]; then
      stop="hit --max-turns $MAX_TURNS"
      break
    fi
    turn=$((turn + 1))
    jq -c --slurpfile tools "$DIR/tools.json" --argjson max "$GEN_MAX" --argjson think "$THINK" \
      '{messages: ., tools: $tools[0], max_tokens: $max}
       + (if $think == 1 then {} else {chat_template_kwargs: {enable_thinking: false}} end)' \
      "$msgs" >"$d/request.json"
    : >"$d/hw.tmp"
    sampler "$d/hw.tmp" &
    SPID=$!
    t0=$EPOCHREALTIME
    if ! resp=$(curl -sS --max-time 1800 "$base/v1/chat/completions" \
      -H 'Content-Type: application/json' --data-binary @"$d/request.json"); then
      kill "$SPID" 2>/dev/null || true
      stop="turn $turn: the request failed"
      warn "[$label] $stop"
      break
    fi
    t1=$EPOCHREALTIME
    kill "$SPID" 2>/dev/null || true
    wait "$SPID" 2>/dev/null || true
    if ! jq -e '.choices[0].message' >/dev/null 2>&1 <<<"$resp"; then
      stop="turn $turn: $(jq -r '(.error.message // "unexpected response")[:300]' <<<"$resp" 2>/dev/null || echo "non-JSON response")"
      warn "[$label] $stop"
      break
    fi

    IFS=$'\t' read -r cache_n prompt_n prompt_ms gen_n gen_ms draft_n draft_ok finish < <(
      jq -r '[.timings.cache_n // 0, .timings.prompt_n // 0, .timings.prompt_ms // 0,
              .timings.predicted_n // 0, .timings.predicted_ms // 0, .timings.draft_n // 0,
              .timings.draft_n_accepted // 0, .choices[0].finish_reason // "none"] | @tsv' <<<"$resp"
    )
    IFS=$'\t' read -r prefill_s gen_tps turn_s < <(
      awk -v pm="$prompt_ms" -v gn="$gen_n" -v gm="$gen_ms" -v a="$t0" -v b="$t1" \
        'BEGIN { printf "%.2f\t%.1f\t%.1f\n", pm / 1000, (gm > 0 ? gn / (gm / 1000) : 0), b - a }'
    )
    ctx=$((cache_n + prompt_n))
    miss=0
    if [ "$turn" -gt 1 ] && [ $((cache_n * 10)) -lt $((prev * 9)) ]; then miss=1; fi
    prev=$ctx

    jq -c --argjson keep "$KEEP_REASONING" '.choices[0].message
      | {role: "assistant", content: (.content // ""), tool_calls, reasoning_content}
      | if (.tool_calls // []) == [] then del(.tool_calls) else . end
      | if $keep == 1 and .reasoning_content != null then . else del(.reasoning_content) end' \
      <<<"$resp" >"$d/assistant.json"
    ncalls=$(jq '.tool_calls // [] | length' "$d/assistant.json")
    names=''
    printf '[]' >"$d/tool-results.json"
    k=0
    while [ "$k" -lt "$ncalls" ]; do
      name=$(jq -r --argjson k "$k" '.tool_calls[$k].function.name // ""' "$d/assistant.json")
      id=$(jq -r --argjson k "$k" '.tool_calls[$k].id // ""' "$d/assistant.json")
      if args=$(jq -ec --argjson k "$k" \
        '.tool_calls[$k].function.arguments | (if type == "string" then fromjson else . end) | objects' \
        "$d/assistant.json" 2>/dev/null); then
        out=$(run_tool "$name" "$args")
      elif [ "$finish" = length ]; then
        bad=$((bad + 1))
        out="error: your reply hit the $GEN_MAX-token output limit and this call was cut off before its arguments were complete"
      else
        bad=$((bad + 1))
        out='error: the arguments were not a valid JSON object'
      fi
      jq -c --arg id "$id" --arg out "$out" '. + [{role: "tool", tool_call_id: $id, content: $out}]' \
        "$d/tool-results.json" >"$d/tool-results.tmp"
      mv "$d/tool-results.tmp" "$d/tool-results.json"
      names+="${names:+,}$name"
      k=$((k + 1))
    done
    if [ "$finish" = length ]; then
      cut=$((cut + 1))
      names+=" (cut off)"
    fi
    # llama-server re-parses every tool call in the history and rejects the
    # whole request if one doesn't parse, so a broken call goes back as {}
    # (its error result above says why) rather than killing the session.
    jq -c '.tool_calls |= (if . == null then . else map(.function.arguments |=
        (if ((try (if type == "string" then fromjson else . end) catch null) | type) == "object"
         then . else "{}" end)) end)' "$d/assistant.json" >"$d/assistant.tmp"
    mv "$d/assistant.tmp" "$d/assistant.json"
    if [ "$ncalls" -gt 0 ]; then
      idle=0
      jq -c --slurpfile a "$d/assistant.json" --slurpfile t "$d/tool-results.json" '. + $a + $t[0]' \
        "$msgs" >"$msgs.tmp"
    else
      idle=$((idle + 1))
      jq -c --slurpfile a "$d/assistant.json" --arg n "$NUDGE" '. + $a + [{role: "user", content: $n}]' \
        "$msgs" >"$msgs.tmp"
    fi
    mv "$msgs.tmp" "$msgs"
    kind=other
    case ,$names, in *,write_file,*) kind=edit ;; esac

    hw=$(hw_max "$d/hw.tmp")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$turn" "$ctx" "$cache_n" \
      "$prompt_n" "$prefill_s" "$gen_n" "$gen_tps" "$draft_n" "$draft_ok" "$turn_s" "$kind" "$miss" \
      "${names:-none}" "$hw" >>"$tsv"
    info "$(printf 'turn %3d  ctx %7s  new %7s  prefill %5.1fs  gen %4d @ %5.1f t/s  %-5s %s%s' \
      "$turn" "$(kfmt "$ctx")" "$(kfmt "$prompt_n")" "$prefill_s" "$gen_n" "$gen_tps" "$kind" \
      "${names:-no tool call ($finish)}" "$([ "$miss" = 1 ] && echo '  CACHE MISS')")"

    if [ "$idle" -ge 5 ]; then
      stop="the model stopped calling tools for 5 turns"
      break
    fi
  done
  rm -f "$d/hw.tmp" "$d/request.json" "$d/assistant.json" "$d/tool-results.json"
  S_STOP[$label]=$stop
  S_BAD[$label]=$bad
  S_CUT[$label]=$cut

  # Worst case: the same context with nothing reusable, as after a cache miss
  # or a fresh server. A changed first token invalidates every cached position.
  S_COLD[$label]=-
  if [ "$turn" -gt 0 ]; then
    info "cold prefill of the whole $(kfmt "$ctx") context"
    if resp=$(jq -c --slurpfile tools "$DIR/tools.json" \
      '.[0].content = "[cold cache] " + .[0].content | {messages: ., tools: $tools[0], max_tokens: 1}' "$msgs" |
      curl -sS --max-time 1800 "$base/v1/chat/completions" -H 'Content-Type: application/json' --data-binary @-) &&
      jq -e '.timings.prompt_n' >/dev/null 2>&1 <<<"$resp"; then
      S_COLD[$label]=$(jq -r '.timings | "\(.prompt_ms / 1000 * 10 | round / 10) s for \(.prompt_n / 1024 * 10 | round / 10)K tokens (\(.prompt_per_second | round) t/s)"' <<<"$resp")
      info "  ${S_COLD[$label]}"
    else
      warn "[$label] the cold-prefill request failed: $(jq -r '(.error.message // "")[:200]' <<<"${resp:-}" 2>/dev/null || true)"
    fi
  fi
}

# ── sweep: probe servers built from the unit's command line ─────────────────

PROBE=''
stop_probe() {
  if [ -n "$PROBE" ]; then
    kill "$PROBE" 2>/dev/null || true
    wait "$PROBE" 2>/dev/null || true
    PROBE=''
  fi
}
# Runs on every exit, in both modes: a sampler left behind by a run killed
# mid-request would otherwise poll sysfs forever, reparented to init.
stop_sampler() {
  if [ -n "$SPID" ]; then
    kill "$SPID" 2>/dev/null || true
    SPID=''
  fi
}

gtt_mib() { if [ -n "$CARD" ]; then mib "$(<"$CARD/mem_info_gtt_used")"; else echo 0; fi; }
# A variant that doesn't fit in VRAM still runs, just slowly, with amdgpu
# spilling buffers into GTT. Its numbers would then measure the spill, not the
# setting, so say so loudly. (bf16 KV at 128K is ~1.2 GiB more than q8_0, which
# is three expert layers' worth: it needs its own --n-cpu-moe.)
check_spill() { # label
  local peak
  if [ "$HW" != 1 ] || [ -z "$CARD" ]; then return; fi
  peak=$(awk -F'\t' 'NR > 1 && $15 != "-" && $15 + 0 > m { m = $15 + 0 } END { print m + 0 }' "$DIR/$1/turns.tsv")
  if [ $((peak - GTT0)) -gt 512 ]; then
    warn "[$1] $((peak - GTT0)) MiB spilled from VRAM into system RAM (GTT): this setup doesn't fit, so its numbers measure the spill, not the setting. Give it a higher --n-cpu-moe."
  fi
}

# The unit's arguments minus host/port and every long option the variant sets,
# then the variant's own. Long options only, like services.llama-cpp emits.
variant_args() { # flags
  local -a v=()
  local -A drop=([host]=1 [port]=1)
  local i=0 key val w
  read -ra v <<<"$1"
  for key in "${v[@]}"; do
    if [[ $key == --* ]]; then drop[${key#--}]=1; fi
  done
  VARGS=()
  while [ "$i" -lt "${#BASE_ARGS[@]}" ]; do
    key=${BASE_ARGS[i]#--}
    val=${BASE_ARGS[i + 1]:-}
    if [ -z "$val" ] || [[ $val == --* ]]; then w=1; else w=2; fi
    if [ -z "${drop[$key]:-}" ]; then VARGS+=("${BASE_ARGS[@]:i:w}"); fi
    i=$((i + w))
  done
  VARGS+=("${v[@]}" --host 127.0.0.1 --port "$PORT")
}

start_probe() { # label flags
  variant_args "$2"
  mkdir -p "$DIR/$1"
  "$SERVER" "${VARGS[@]}" >"$DIR/$1/server.log" 2>&1 &
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

# ── main ────────────────────────────────────────────────────────────────────

DIR=$OUT/$(date +%Y%m%d-%H%M%S)
mkdir -p "$DIR"
tools_json >"$DIR/tools.json"
N_CTX=''
HW=0

if [ "$SWEEP" = 1 ]; then
  exec_start=$(systemctl show "$UNIT" -p ExecStart --value)
  argv=$(sed -n 's/.*argv\[\]=\([^;]*\) ;.*/\1/p' <<<"$exec_start")
  [ -n "$argv" ] || die "can't read the command line of $UNIT"
  read -ra ARGV <<<"$argv"
  SERVER=${ARGV[0]}
  BASE_ARGS=("${ARGV[@]:1}")
  for ((i = 0; i < ${#BASE_ARGS[@]}; i++)); do
    if [ "${BASE_ARGS[i]}" = --ctx-size ]; then N_CTX=${BASE_ARGS[i + 1]}; fi
  done
  if [ "${#VARIANTS[@]}" -eq 0 ]; then
    VARIANTS=("current=" "ngram-mod=--spec-type ngram-mod")
  fi
  HW=1
else
  curl -sf -o /dev/null "$URL/health" || die "no llama-server answering at $URL"
  N_CTX=$(curl -sf "$URL/props" | jq -r '.default_generation_settings.n_ctx // empty') || true
  host=${URL#*://}
  host=${host%%[:/]*}
  case $host in localhost | 127.* | "[::1]" | "$(uname -n)" | "$(uname -n)".*) HW=1 ;; esac
fi
if [ -z "$TARGET" ]; then
  TARGET=65536
  if [ -n "$N_CTX" ] && [ $((N_CTX * 3 / 4)) -lt "$TARGET" ]; then TARGET=$((N_CTX * 3 / 4)); fi
fi
if [ -n "$N_CTX" ] && [ "$TARGET" -gt $((N_CTX - GEN_MAX - 1024)) ]; then
  die "--target $TARGET leaves no room to generate in a $N_CTX-token context"
fi
if [ "$HW" = 0 ]; then
  sample() { printf -- '-\t-\t-\t-\t-\t-\t-\n'; }
  info "the server isn't local, so no temperature or VRAM readings"
fi
DEEP=$((TARGET * 2 / 3))

if [ "$SWEEP" = 1 ]; then
  WAS_ACTIVE=0
  if systemctl is-active --quiet "$UNIT"; then WAS_ACTIVE=1; fi
  as_root true || die "--sweep needs sudo to stop and start $UNIT"
  KEEPALIVE=''
  if [ "$(id -u)" -ne 0 ]; then
    (while sleep 60; do sudo -n -v 2>/dev/null || exit 0; done) &
    KEEPALIVE=$!
  fi
  cleanup() {
    stop_sampler
    stop_probe
    if [ "$WAS_ACTIVE" = 1 ]; then
      step "restarting $UNIT"
      as_root systemctl start "$UNIT" || printf 'llm-stress: could not restart %s\n' "$UNIT" >&2
    fi
    if [ -n "$KEEPALIVE" ]; then kill "$KEEPALIVE" 2>/dev/null || true; fi
  }
  trap cleanup EXIT
  trap 'exit 130' INT TERM
  if [ "$WAS_ACTIVE" = 1 ]; then
    step "stopping $UNIT for the sweep"
    as_root systemctl stop "$UNIT"
  fi
  if pgrep -x 'llama-(server|bench)' >/dev/null; then die "another llama-server / llama-bench is running"; fi
  if curl -s -o /dev/null "http://127.0.0.1:$PORT/"; then die "port $PORT is in use; set LLM_STRESS_PORT"; fi

  LABELS=()
  for v in "${VARIANTS[@]}"; do
    label=${v%%=*}
    flags=${v#*=}
    step "variant $label: ${flags:-as deployed}"
    GTT0=$(gtt_mib)
    if ! start_probe "$label" "$flags"; then
      warn "[$label] llama-server didn't start; see $DIR/$label/server.log"
      continue
    fi
    LABELS+=("$label")
    run_session "$label" "http://127.0.0.1:$PORT"
    check_spill "$label"
    # Speculation can be refused or reconfigured at load (a hybrid model's
    # state has to be rolled back on a rejected draft), so keep what it said.
    S_NOTES[$label]=$(awk 'tolower($0) ~ /specul|draft/ && !/print_timing/ && n++ < 5' "$DIR/$label/server.log")
    stop_probe
  done
else
  step "session against $URL: growing to $(kfmt "$TARGET") of context"
  LABELS=(live)
  trap stop_sampler EXIT
  trap 'exit 130' INT TERM
  # The server is already loaded, so there is no before-load baseline: a
  # healthy one keeps GTT near zero, so anything over 1 GiB is a spill.
  GTT0=$(gtt_mib)
  if [ "$HW" = 1 ] && [ "$GTT0" -gt 1024 ]; then
    warn "the server already has $GTT0 MiB in GTT at the start, so it is spilling out of VRAM; restart it with the GPU free before trusting these numbers"
  fi
  GTT0=0
  run_session live "$URL"
  check_spill live
fi

# ── report ──────────────────────────────────────────────────────────────────

MED='function med(a, n,   b, m) { if (n == 0) return ""; m = asort(a, b); return (m % 2) ? b[(m + 1) / 2] : (b[m / 2] + b[m / 2 + 1]) / 2 }
     function f(x, u) { return x == "" ? "–" : sprintf("%.1f%s", x, u) }'

summary_row() { # label
  gawk -F'\t' -v label="$1" -v deep="$DEEP" -v cold="${S_COLD[$1]}" -v bad="${S_BAD[$1]}" -v cut="${S_CUT[$1]}" "$MED"'
    NR == 1 { next }
    {
      turns++; ctx = $2; total += $10; miss += $12; dn += $8; da += $9
      if ($2 >= deep) {
        pre[++np] = $5; ts[np] = $10
        if ($6 >= 32) { if ($11 == "edit") te[++ne] = $7; else to[++no] = $7 }
      }
      for (i = 16; i <= 18; i++) if ($i != "-" && $i + 0 > mx[i]) mx[i] = $i + 0
    }
    END {
      printf "| %s | %d | %.1fK | %.0f min | %s | %s | %s | %s | %s | %s | %d | %d | %d | %s / %s / %s |\n",
        label, turns, ctx / 1024, total / 60, f(med(pre, np), " s"), f(med(ts, np), " s"),
        f(med(to, no), ""), f(med(te, ne), ""), (dn > 0 ? sprintf("%.0f%%", 100 * da / dn) : "–"),
        cold, miss, bad, cut, mx[16] ? mx[16] "°C" : "–", mx[17] ? mx[17] "°C" : "–", mx[18] ? mx[18] " W" : "–"
    }' "$DIR/$1/turns.tsv"
}

depth_table() { # label
  md "| context | turns | new tokens/turn | prefill | tg t/s, other | tg t/s, write_file | turn | cache misses |" \
    "|---|---:|---:|---:|---:|---:|---:|---:|"
  gawk -F'\t' "$MED"'
    NR == 1 { next }
    {
      b = ($2 < 16384) ? 1 : ($2 < 32768) ? 2 : ($2 < 65536) ? 3 : ($2 < 98304) ? 4 : 5
      n[b]++; nw[b][n[b]] = $4; pre[b][n[b]] = $5; ts[b][n[b]] = $10; ms[b] += $12
      if ($6 >= 32) { if ($11 == "edit") te[b][++ne[b]] = $7; else to[b][++no[b]] = $7 }
    }
    END {
      split("0–16K 16–32K 32–64K 64–96K 96K+", name, " ")
      for (b = 1; b <= 5; b++) {
        if (!n[b]) continue
        printf "| %s | %d | %.0f | %s | %s | %s | %s | %d |\n", name[b], n[b], med(nw[b], n[b]),
          f(med(pre[b], n[b]), " s"), f(med(to[b], no[b]), ""), f(med(te[b], ne[b]), ""),
          f(med(ts[b], n[b]), " s"), ms[b]
      }
    }' "$DIR/$1/turns.tsv" >>"$MD_OUT"
  md ""
}

turn_table() { # label
  md "<details><summary>Every turn</summary>" "" \
    "| # | context | new | prefill s | gen | t/s | draft accepted | turn s | tools | GPU °C | GPU W |" \
    "|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|"
  awk -F'\t' 'NR > 1 {
      printf "| %s | %.1fK | %s | %s | %s | %s | %s | %s | %s%s | %s | %s |\n", $1, $2 / 1024, $4, $5, $6, $7,
        ($8 > 0 ? $9 "/" $8 : "–"), $10, $13, ($12 ? " **miss**" : ""), $16, $18
    }' "$DIR/$1/turns.tsv" >>"$MD_OUT"
  md "" "</details>" ""
}

MD_OUT=$DIR/report.md
mode="live, against $URL"
if [ "$SWEEP" = 1 ]; then mode="sweep of $UNIT's settings"; fi
md "# llm-stress: $(uname -n), $(date '+%F %R')" "" \
  "$mode · project \`$ROOT\` · target $(kfmt "$TARGET") · thinking $([ "$THINK" = 1 ] && echo on || echo off) · reasoning $([ "$KEEP_REASONING" = 1 ] && echo kept || echo dropped) in history · took $((SECONDS / 60)) min" "" \
  "One agent session per row, grown to the target. \"Deep\" is the last third: context ≥ $(kfmt "$DEEP"). Prefill is what you wait before the first token of a turn; *turn* is the whole reply, thinking and tool call included." "" \
  "| variant | turns | reached | total | prefill, deep | turn, deep | tg other, deep | tg write_file, deep | draft accepted | cold prefill at the end | cache misses | bad tool calls | replies cut off | peak GPU junction / memory / power |" \
  "|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|"
for l in "${LABELS[@]}"; do summary_row "$l" >>"$MD_OUT"; done
md ""
for w in "${WARNINGS[@]}"; do md "- ⚠ $w"; done
md ""
for l in "${LABELS[@]}"; do
  md "## $l" "" "Stopped: ${S_STOP[$l]}." ""
  if [ -n "${S_NOTES[$l]:-}" ]; then md '```' "${S_NOTES[$l]}" '```' ""; fi
  depth_table "$l"
  turn_table "$l"
done

printf '\n' >&2
cat "$MD_OUT"
step "report: $MD_OUT"
