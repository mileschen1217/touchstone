#!/usr/bin/env bash
# phase-record.sh — the phase-ship deterministic step. Runs the (unchanged)
# metrics reporter exactly as the dissolved skill body did, aggregates the
# per-run rows, and appends ONE markdown row to
# .touchstone/epics/<slug>/data-points.md — the SOLE writer of that file,
# append-only. Unmeasurable cells carry [unverified: …] VERBATIM from the
# reporter output; never replaced with a number or zero. Running the reporter
# also bounds the last still-open gate-run window (the stamp).
# Usage: phase-record.sh <epic-slug> <phase-label>
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLUG="${1:-}"; LABEL="${2:-}"
if [ -z "$SLUG" ] || [ -z "$LABEL" ]; then
  echo "phase-record: usage: phase-record.sh <epic-slug> <phase-label>" >&2
  exit 1
fi
SID="${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
[ -n "$SID" ] || { echo "phase-record: run inside a Claude Code session (CLAUDE_CODE_SESSION_ID unset)" >&2; exit 1; }

REPORT="${TOUCHSTONE_METRICS_REPORT:-$SCRIPT_DIR/../metrics-report.sh}"
OUT="$(bash "$REPORT" --session-id "$SID" ${TOUCHSTONE_OTEL_EXPORT:+--otel "$TOUCHSTONE_OTEL_EXPORT"})" \
  || { echo "phase-record: metrics reporter failed" >&2; exit 1; }

# per-run rows only (diagnostics/summary headers are not JSON rows)
ROWS="$(printf '%s\n' "$OUT" | jq -c -R 'fromjson? | select(type=="object" and has("run_id"))')"

AGG="$(printf '%s\n' "$ROWS" | jq -s '
  { runs: length,
    wall: (map(.wallclock_s // 0) | add // 0),
    tokens: ( if length == 0 then null
      elif any(.[]; (.codex|type)=="string" or (.cc_subagent|type)=="string") then
        ([ .[] | (if (.codex|type)=="string" then .codex else empty end),
                 (if (.cc_subagent|type)=="string" then .cc_subagent else empty end) ] | first)
      else (map(((.codex.in // 0) + (.codex.out // 0)) + (.cc_subagent.tokens // 0)) | add)
      end ),
    cost: ( if length == 0 then null
      elif any(.[]; (.dispatch_total_cost_usd|type)=="string" and (.dispatch_total_cost_usd|startswith("[unverified"))) then
        ([ .[] | .dispatch_total_cost_usd
           | select(type=="string" and startswith("[unverified")) ] | first)
      else (map(.dispatch_total_cost_usd | if type=="string" then tonumber else . end) | add)
      end ) }')"

RUNS="$(echo "$AGG" | jq -r '.runs')"
WALL="$(echo "$AGG" | jq -r '.wall')"
TOKENS="$(echo "$AGG" | jq -r '.tokens // empty')"
COST="$(echo "$AGG" | jq -r '.cost // empty')"
if [ "$RUNS" -eq 0 ]; then
  TOKENS="[unverified: no gate runs recorded for session $SID]"
  COST="[unverified: no gate runs recorded for session $SID]"
fi

# open-entry count: the one declared cross-script dependency (banner on
# stderr is discarded; count = stdout line count). Capture output and check
# the exit code EXPLICITLY (not through a pipeline, which would mask it) so
# a query failure degrades honestly instead of silently reading as 0.
OPEN_OUT="$(bash "$SCRIPT_DIR/../proposal/report.sh" open-entries 2>/dev/null)"
OPEN_RC=$?
if [ "$OPEN_RC" -eq 0 ]; then
  OPEN="$(printf '%s\n' "$OPEN_OUT" | grep -c . || true)"
  [ -n "$OPEN" ] || OPEN=0
else
  OPEN="[unverified: open-entries query failed]"
fi

if [ -n "${TOUCHSTONE_EPICS_DIR:-}" ]; then
  EPICS="$TOUCHSTONE_EPICS_DIR"
else
  TOP="$(git rev-parse --show-toplevel 2>/dev/null)"
  [ -n "$TOP" ] || { echo "phase-record: not inside a git repo; set TOUCHSTONE_EPICS_DIR" >&2; exit 1; }
  EPICS="$TOP/.touchstone/epics"
fi
DP="$EPICS/$SLUG/data-points.md"
mkdir -p "$(dirname "$DP")"
if [ ! -f "$DP" ]; then
  {
    echo "# data-points — $SLUG"
    echo
    echo "| date | phase | gate runs | tokens | wallclock_s | cost_usd | open entries | session |"
    echo "|---|---|---|---|---|---|---|---|"
  } > "$DP"
fi
ROW="| $(date -u +%Y-%m-%d) | $LABEL | $RUNS | $TOKENS | $WALL | $COST | $OPEN | $SID |"
printf '%s\n' "$ROW" >> "$DP"
printf '%s\n' "$ROW"
exit 0
