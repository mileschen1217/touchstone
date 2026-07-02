#!/usr/bin/env bash
# extract-firelog.sh — L0 digest extractor for the checker fire log
# ($TOUCHSTONE_LEDGER_DIR/fire-log.jsonl, schema fire-event/v1, produced by
# hooks/run-project-checks.sh on every exit-2 block). Emits one per-check
# aggregate digest record per run over the newly-scanned tail. See
# .touchstone/specs/2026-07-02-catch-attribution-ledger-design.md (REQ-4).
#
# Usage: extract-firelog.sh [--since ISO] [--epic slug] [--propose-cursors FILE]
#
# Default mode (no --since/--epic/--propose-cursors): unfiltered,
# cursor-advancing — commits the new cursor to
# $TOUCHSTONE_LEDGER_DIR/scan-state.json section "firelog". Byte-cursor
# tail-only, IDENTICAL contract to extract-transcript.sh (AC-5/AC-6
# semantics apply here too) — mechanics shared via cursor-lib.sh.
# --propose-cursors FILE: same unfiltered scan, but the proposed cursor is
# written to FILE instead of scan-state.json (sweep mode — the caller
# commits after a successful ledger-append.sh).
# --since/--epic: read-only ad-hoc query — scans from byte 0, filters
# individual fire-events by ts BEFORE aggregating, never touches
# scan-state.json or a propose file.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/cursor-lib.sh"

SINCE=""
EPIC=""
PROPOSE_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since|--epic|--propose-cursors)
      if [ $# -lt 2 ]; then
        echo "extract-firelog: $1 requires a value" >&2
        exit 1
      fi
      ;;
  esac
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --epic) EPIC="$2"; shift 2 ;;
    --propose-cursors) PROPOSE_FILE="$2"; shift 2 ;;
    *) echo "extract-firelog: unknown arg: $1" >&2; exit 1 ;;
  esac
done

READONLY=0
if [ -n "$SINCE" ] || [ -n "$EPIC" ]; then
  READONLY=1
fi

LDIR="$(cursor_lib_resolve_ledger_dir extract-firelog)" || exit 1

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

OLD_FIRELOG='{}'
STATE_JSON='{}'
if [ "$READONLY" -eq 0 ]; then
  STATE_JSON="$(cursor_lib_load_state "$LDIR")"
  OLD_FIRELOG="$(cursor_lib_section "$STATE_JSON" firelog)"
fi

if [ "$READONLY" -eq 1 ]; then
  START_CURSOR=0
else
  START_CURSOR="$(printf '%s' "$OLD_FIRELOG" | jq -r --arg p "$ABS_FIRELOG" '.[$p].cursor // 0')"
fi

FS_BYTES="$(cursor_lib_fs_bytes "$ABS_FIRELOG")"
START_CURSOR="$(cursor_lib_reset_if_shrunk "$START_CURSOR" "$FS_BYTES")"
EFFECTIVE_END="$(cursor_lib_tail_effective_end "$ABS_FIRELOG" "$FS_BYTES")"

if [ "$START_CURSOR" -lt "$EFFECTIVE_END" ]; then
  head -c "$EFFECTIVE_END" -- "$ABS_FIRELOG" \
    | tail -c +"$((START_CURSOR + 1))" \
    | jq -Rc 'try (fromjson | select(.schema=="fire-event/v1")) catch empty' \
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
fi

if [ "$READONLY" -eq 1 ]; then
  exit 0
fi

NEW_FIRELOG="$(printf '%s' "$OLD_FIRELOG" | jq -c --arg p "$ABS_FIRELOG" --argjson c "$EFFECTIVE_END" '.[$p] = {cursor: $c}')"

# prune keys whose source file no longer exists (same contract as
# extract-transcript.sh — a rotated-away fire log's stale key is dropped).
NEW_FIRELOG="$(cursor_lib_prune_stale "$NEW_FIRELOG")"

if [ -n "$PROPOSE_FILE" ]; then
  cursor_lib_propose "$PROPOSE_FILE" "$NEW_FIRELOG" || { echo "extract-firelog: cannot create dir for $PROPOSE_FILE" >&2; exit 1; }
  exit 0
fi

cursor_lib_commit_section "$LDIR" "$STATE_JSON" firelog "$NEW_FIRELOG" || { echo "extract-firelog: cannot create ledger dir $LDIR" >&2; exit 1; }

exit 0
