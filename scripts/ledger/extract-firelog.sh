#!/usr/bin/env bash
# extract-firelog.sh — L0 digest extractor for the checker fire log
# ($TOUCHSTONE_LEDGER_DIR/fire-log.jsonl, schema fire-event/v1, produced by
# hooks/run-project-checks.sh on every exit-2 block). Emits one per-check
# aggregate digest record per run over the scanned events.
#
# Usage: extract-firelog.sh [--since ISO] [--epic slug]
#
# Read-only, stateless: every run scans the whole fire log and filters
# individual fire-events by ts BEFORE aggregating when --since (or --epic,
# resolved to a since bound) is given. Incremental behavior across sweeps
# comes from the CALLER passing the last successful sweep's timestamp as
# --since (sweep-run.sh owns that state); re-emitted aggregates are deduped
# downstream by ledger-append.sh's refs_overlap check.
set -u

SINCE=""
EPIC=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since|--epic)
      if [ $# -lt 2 ]; then
        echo "extract-firelog: $1 requires a value" >&2
        exit 1
      fi
      ;;
  esac
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --epic) EPIC="$2"; shift 2 ;;
    *) echo "extract-firelog: unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -n "${TOUCHSTONE_LEDGER_DIR:-}" ]; then
  LDIR="$TOUCHSTONE_LEDGER_DIR"
else
  TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$TOPLEVEL" ]; then
    echo "extract-firelog: not inside a git repo; set TOUCHSTONE_LEDGER_DIR" >&2
    exit 1
  fi
  LDIR="$TOPLEVEL/.touchstone/ledger"
fi

# --epic best-effort resolution: same convention as extract-transcript.sh /
# extract-git.sh — a missing epic index is not an error.
if [ -n "$EPIC" ] && [ -z "$SINCE" ]; then
  EPIC_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$EPIC_TOPLEVEL" ]; then
    EPIC_INDEX="$EPIC_TOPLEVEL/.touchstone/epics/$EPIC/index.md"
    if [ -f "$EPIC_INDEX" ]; then
      SINCE="$(grep -m1 '^started:' "$EPIC_INDEX" | sed 's/^started:[[:space:]]*//')"
    fi
  fi
fi

FIRELOG_FILE="$LDIR/fire-log.jsonl"

if [ ! -f "$FIRELOG_FILE" ]; then
  # source absent (no check has ever fired here yet): emit nothing, exit 0.
  exit 0
fi

ABS_FIRELOG="$(cd "$(dirname "$FIRELOG_FILE")" && pwd)/$(basename "$FIRELOG_FILE")"

jq -Rc 'try (fromjson | select(.schema=="fire-event/v1")) catch empty' "$ABS_FIRELOG" \
  | if [ -n "$SINCE" ]; then jq -c --arg since "$SINCE" 'select(.ts >= $since)'; else cat; fi \
  | jq -sc --arg path "$ABS_FIRELOG" '
      group_by(.check)
      | map({
          schema: "digest/v1",
          source: "firelog",
          ref: ("firelog:" + $path + "#" + .[0].check),
          ts: (map(.ts) | max),
          payload: {
            check: .[0].check,
            count: length,
            first_ts: (map(.ts) | min),
            last_ts: (map(.ts) | max)
          }
        })
      | .[]
    ' \
  | sed '/^$/d'

exit 0
