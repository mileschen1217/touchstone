#!/usr/bin/env bash
# codex-probe.sh — codex dispatch stability probe (spec REQ-5, AC-17/AC-20).
#
# Reproduces the production dispatch shape from agents/codex-reviewer.md
# (Path C):
#   timeout <T> codex exec --json --skip-git-repo-check \
#     -o <dir>/last-message.txt "<prompt>" </dev/null
#
# Appends one JSON line per attempted cell to --out. Resumable: every
# invocation only appends, so calling it again (e.g. with a different
# --only) never loses prior lines, and every attempted cell writes a line
# even on failure — nothing is skipped silently.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: codex-probe.sh --out <record-file> [--sizes 1k,10k,50k,100k] [--reps 2]
                       [--timeouts 600,1200] [--only <size>] [--smoke]

  --out <file>        record file to append JSON lines to (required)
  --sizes <list>      comma-separated target sizes, e.g. 1k,10k,50k,100k
  --reps <n>          repetitions per (size, timeout) cell (default 2)
  --timeouts <list>   comma-separated timeout_s values, e.g. 600,1200
  --only <size>       restrict to a single size (one matrix column)
  --smoke             smallest size, 1 rep, 120s timeout; asserts envelope
                       shape; SKIPs (exit 0) when codex CLI is absent
EOF
}

out_file=""
sizes="1k,10k,50k,100k"
reps=2
timeouts="600,1200"
only=""
smoke=0

while [ $# -gt 0 ]; do
  case "$1" in
    --out) out_file="$2"; shift 2 ;;
    --sizes) sizes="$2"; shift 2 ;;
    --reps) reps="$2"; shift 2 ;;
    --timeouts) timeouts="$2"; shift 2 ;;
    --only) only="$2"; shift 2 ;;
    --smoke) smoke=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "codex-probe.sh: unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$smoke" -eq 1 ]; then
  sizes="1k"
  reps=1
  timeouts="120"
  only="1k"
fi

if [ -z "$out_file" ]; then
  echo "codex-probe.sh: --out is required" >&2
  usage >&2
  exit 2
fi

out_dir="$(dirname "$out_file")"
mkdir -p "$out_dir"

if ! command -v codex >/dev/null 2>&1; then
  if [ "$smoke" -eq 1 ]; then
    echo "SKIP: codex CLI not installed — probe not run"
    exit 0
  fi
  echo "codex-probe.sh: codex CLI not on PATH — nothing to probe" >&2
  echo "SKIP: codex CLI not installed — probe not run"
  exit 0
fi

# size_to_bytes <label> -- "1k" -> 1024, "10k" -> 10240, "1m" -> 1048576,
# a bare number passes through unchanged.
size_to_bytes() {
  case "$1" in
    *k|*K) echo $(( ${1%[kK]} * 1024 )) ;;
    *m|*M) echo $(( ${1%[mM]} * 1024 * 1024 )) ;;
    *) echo "$1" ;;
  esac
}

# gen_target <bytes> -- deterministic synthetic review target of exactly
# <bytes> bytes; no network, no external state, reproducible across runs.
gen_target() {
  awk -v n="$1" 'BEGIN {
    i = 0
    buf = ""
    while (length(buf) < n) {
      i++
      buf = buf sprintf("+ line %06d: deterministic synthetic review content for codex probe sizing.\n", i)
    }
    print substr(buf, 1, n)
  }'
}

# json_escape <text> -- backslash- and quote-escape for embedding in a JSON string.
json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# run_cell <size_bytes> <rep> <timeout_s> -- one probe attempt; always
# appends exactly one JSON line to $out_file, whatever the outcome.
run_cell() {
  size_bytes="$1"; rep="$2"; timeout_s="$3"

  cell_dir="$(mktemp -d)"
  # production dispatch shape (agents/codex-reviewer.md, redesigned): the target
  # rides as a task FILE streamed via stdin; the prompt carries only the role line.
  gen_target "$size_bytes" > "$cell_dir/task.md"
  prompt='You are being probed for dispatch latency. The stdin block is the probe target. Reply with exactly one line: OK'

  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  start_epoch=$(date +%s)
  timeout "$timeout_s" codex exec --json --skip-git-repo-check \
    -o "$cell_dir/last-message.txt" \
    "$prompt" < "$cell_dir/task.md" >"$cell_dir/raw_codex.jsonl" 2>&1
  exit_code=$?
  end_epoch=$(date +%s)
  latency_s=$((end_epoch - start_epoch))

  out_bytes=0
  if [ -s "$cell_dir/last-message.txt" ]; then
    out_bytes=$(wc -c < "$cell_dir/last-message.txt" | tr -d ' ')
  fi

  jsonl_events=0
  if [ -f "$cell_dir/raw_codex.jsonl" ]; then
    jsonl_events=$(wc -l < "$cell_dir/raw_codex.jsonl" | tr -d ' ')
  fi

  note=""
  if [ "$exit_code" -eq 124 ] || [ "$exit_code" -eq 137 ]; then
    outcome="timeout"
    note="timeout command killed the run after ${timeout_s}s"
  elif [ "$out_bytes" -gt 0 ]; then
    outcome="ok"
  else
    fail_line="$(grep -m1 -E '"type"[[:space:]]*:[[:space:]]*"(error|turn\.failed)"|auth.*failed|sandbox.*violation' "$cell_dir/raw_codex.jsonl" 2>/dev/null || true)"
    if [ -n "$fail_line" ]; then
      outcome="error"
      note="$fail_line"
    elif [ "$exit_code" -ne 0 ]; then
      outcome="error"
      note="exit_code=${exit_code}, no matching terminal-failure event"
    else
      # -o file missing/empty, process exited 0, no terminal failure event
      # in the JSON stream — the observed failure shape motivating REQ-5.
      outcome="no_response"
      note="process exited 0, -o file missing/empty, no terminal failure event"
    fi
  fi

  note="$(printf '%s' "$note" | tr -d '\n' | cut -c1-300)"

  printf '{"ts":"%s","size_bytes":%s,"rep":%s,"timeout_s":%s,"outcome":"%s","latency_s":%s,"exit_code":%s,"out_file_bytes":%s,"jsonl_events":%s,"note":"%s"}\n' \
    "$ts" "$size_bytes" "$rep" "$timeout_s" "$outcome" "$latency_s" "$exit_code" "$out_bytes" "$jsonl_events" "$(json_escape "$note")" >> "$out_file"

  rm -rf "$cell_dir"
}

IFS=',' read -r -a size_arr <<< "$sizes"
IFS=',' read -r -a timeout_arr <<< "$timeouts"

if [ -n "$only" ]; then
  size_arr=("$only")
fi

for size_label in "${size_arr[@]}"; do
  size_bytes="$(size_to_bytes "$size_label")"
  for timeout_s in "${timeout_arr[@]}"; do
    rep=1
    while [ "$rep" -le "$reps" ]; do
      run_cell "$size_bytes" "$rep" "$timeout_s"
      rep=$((rep + 1))
    done
  done
done

if [ "$smoke" -eq 1 ]; then
  last_line="$(tail -n1 "$out_file")"
  if printf '%s' "$last_line" | grep -q '"outcome"'; then
    echo "PASS: codex-probe smoke — record line written, outcome field present"
    exit 0
  fi
  echo "FAIL: codex-probe smoke — no outcome field in record line"
  exit 1
fi
