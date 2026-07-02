#!/usr/bin/env bash
# extract-transcript.sh — L0 digest extractor for Claude Code session
# transcripts. Streams user-authored records to stdout as digest/v1 JSONL,
# byte-cursor incremental per file. See
# .touchstone/specs/2026-07-02-catch-attribution-ledger-design.md (REQ-2).
#
# Usage: extract-transcript.sh [--since ISO] [--epic slug]
#                               [--propose-cursors FILE] [--dir DIR]
#
# Default mode (no --since/--epic/--propose-cursors): unfiltered,
# cursor-advancing — commits new cursors to
# $TOUCHSTONE_LEDGER_DIR/scan-state.json section "transcripts".
# --propose-cursors FILE: same unfiltered scan, but proposed cursor
# positions are written to FILE instead of scan-state.json (sweep mode —
# the caller commits after a successful ledger-append.sh).
# --since/--epic: read-only ad-hoc query — scans each file from byte 0,
# filters by ts, never touches scan-state.json or a propose file.
#
# Final-line-without-trailing-newline behavior (chosen, not the only valid
# choice): an unterminated final line is treated as still being written —
# it is NOT emitted and the cursor stops at its start byte, so the next run
# re-reads it whole once it gets a trailing newline.
#
# Cursor mechanics (tail-only scan, reset-on-shrink, section-scoped
# scan-state read/propose/commit) are shared with extract-firelog.sh — see
# cursor-lib.sh.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/cursor-lib.sh"

SENTINEL='[Request interrupted by user]'

SINCE=""
EPIC=""
PROPOSE_FILE=""
TRANSCRIPTS_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since|--epic|--propose-cursors|--dir)
      if [ $# -lt 2 ]; then
        echo "extract-transcript: $1 requires a value" >&2
        exit 1
      fi
      ;;
  esac
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --epic) EPIC="$2"; shift 2 ;;
    --propose-cursors) PROPOSE_FILE="$2"; shift 2 ;;
    --dir) TRANSCRIPTS_DIR="$2"; shift 2 ;;
    *) echo "extract-transcript: unknown arg: $1" >&2; exit 1 ;;
  esac
done

READONLY=0
if [ -n "$SINCE" ] || [ -n "$EPIC" ]; then
  READONLY=1
fi

# --epic best-effort resolution: use the epic index's `started:` frontmatter
# as a --since lower bound when the caller didn't already supply one; a
# missing index is not an error (best-effort, per spec Interfaces § CLI
# shapes — epic attribution on entries is nullable/best-effort).
if [ -n "$EPIC" ] && [ -z "$SINCE" ]; then
  EPIC_TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$EPIC_TOPLEVEL" ]; then
    EPIC_INDEX="$EPIC_TOPLEVEL/.touchstone/epics/$EPIC/index.md"
    if [ -f "$EPIC_INDEX" ]; then
      SINCE="$(grep -m1 '^started:' "$EPIC_INDEX" | sed 's/^started:[[:space:]]*//')"
    fi
  fi
fi

if [ -z "$TRANSCRIPTS_DIR" ]; then
  TRANSCRIPTS_DIR="$HOME/.claude/projects/$(pwd | tr '/._' '---')"
fi

ABS_DIR=""
if [ -d "$TRANSCRIPTS_DIR" ]; then
  ABS_DIR="$(cd "$TRANSCRIPTS_DIR" && pwd)"
fi

FILES=()
if [ -n "$ABS_DIR" ]; then
  while IFS= read -r f; do
    FILES+=("$f")
  done < <(find "$ABS_DIR" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | sort)
fi

OLD_TRANSCRIPTS='{}'
STATE_JSON='{}'
LDIR=""
if [ "$READONLY" -eq 0 ]; then
  LDIR="$(cursor_lib_resolve_ledger_dir extract-transcript)" || exit 1
  STATE_JSON="$(cursor_lib_load_state "$LDIR")"
  OLD_TRANSCRIPTS="$(cursor_lib_section "$STATE_JSON" transcripts)"
fi
NEW_TRANSCRIPTS="$OLD_TRANSCRIPTS"

# emit_digest <file> <start-cursor> — prints digest/v1 lines for the byte
# range [start-cursor, effective-end) of <file> on stdout; sets NEW_CURSOR
# to the effective end reached (the caller decides whether to persist it).
NEW_CURSOR=0
emit_digest() {
  local f="$1" cursor="$2"
  local fs_bytes effective_end

  fs_bytes="$(cursor_lib_fs_bytes "$f")"
  cursor="$(cursor_lib_reset_if_shrunk "$cursor" "$fs_bytes")"
  effective_end="$(cursor_lib_tail_effective_end "$f" "$fs_bytes")"

  NEW_CURSOR="$effective_end"

  if [ "$cursor" -ge "$effective_end" ]; then
    return 0
  fi

  head -c "$effective_end" -- "$f" \
    | tail -c +"$((cursor + 1))" \
    | LC_ALL=C awk -v off="$cursor" \
        '{ printf "%d %d %s\n", off, off+length($0)+1, $0; off+=length($0)+1 }' \
    | jq -Rc --arg path "$f" '
        capture("^(?<s>[0-9]+) (?<e>[0-9]+) (?<j>.*)$") as $m
        | try (
            ($m.j | fromjson)
            | select(.type=="user")
            | {schema:"digest/v1", source:"transcript",
               ref:("transcript:"+$path+"#"+$m.s+"-"+$m.e),
               ts:(.timestamp // ""),
               payload:{text:(.message.content
                   | if type=="string" then .
                     else ([.[]? | select(.type=="text") | .text] | join(" "))
                     end),
                 interrupt_pair:false}}
          ) catch empty
      ' \
    | jq -nc --arg sentinel "$SENTINEL" '
        foreach inputs as $r (
          {last_text: null, prev_last_text: null};
          {last_text: $r.payload.text, prev_last_text: .last_text};
          ((.prev_last_text) as $pt
           | ($r | .payload.interrupt_pair = (($pt // "") | contains($sentinel))))
        )
      ' \
    | if [ -n "$SINCE" ]; then jq -c --arg since "$SINCE" 'select(.ts >= $since)'; else cat; fi
}

for f in "${FILES[@]:-}"; do
  [ -n "$f" ] || continue
  if [ "$READONLY" -eq 1 ]; then
    START_CURSOR=0
  else
    START_CURSOR="$(printf '%s' "$OLD_TRANSCRIPTS" | jq -r --arg p "$f" '.[$p].cursor // 0')"
  fi

  emit_digest "$f" "$START_CURSOR"

  if [ "$READONLY" -eq 0 ]; then
    NEW_TRANSCRIPTS="$(printf '%s' "$NEW_TRANSCRIPTS" | jq -c --arg p "$f" --argjson c "$NEW_CURSOR" '.[$p] = {cursor: $c}')"
  fi
done

if [ "$READONLY" -eq 1 ]; then
  exit 0
fi

# prune keys whose source file no longer exists (AC: stale scan-state key
# for a deleted/rotated-away file is dropped at scan time).
NEW_TRANSCRIPTS="$(cursor_lib_prune_stale "$NEW_TRANSCRIPTS")"

if [ -n "$PROPOSE_FILE" ]; then
  cursor_lib_propose "$PROPOSE_FILE" "$NEW_TRANSCRIPTS" || { echo "extract-transcript: cannot create dir for $PROPOSE_FILE" >&2; exit 1; }
  exit 0
fi

cursor_lib_commit_section "$LDIR" "$STATE_JSON" transcripts "$NEW_TRANSCRIPTS" || { echo "extract-transcript: cannot create ledger dir $LDIR" >&2; exit 1; }

exit 0
