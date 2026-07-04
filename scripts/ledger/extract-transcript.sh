#!/usr/bin/env bash
# extract-transcript.sh — L0 digest extractor for Claude Code session
# transcripts. Streams user-authored records to stdout as digest/v1 JSONL.
#
# Usage: extract-transcript.sh [--since ISO] [--epic slug] [--dir DIR]
#
# Read-only, stateless: every run scans each file from byte 0 and filters by
# record ts when --since (or --epic, resolved to a since bound) is given.
# Incremental behavior across sweeps comes from the CALLER passing the last
# successful sweep's timestamp as --since (sweep-run.sh owns that state);
# over-emission of already-swept records is deduped downstream by
# ledger-append.sh's refs_overlap check on the byte-range refs.
#
# A final line without a trailing newline is still emitted when it parses as
# JSON; a partial (still being written) line fails the parse and is dropped —
# the next run re-reads it whole. Byte-offset refs are computed from the
# file's actual byte positions, so they are stable across runs.
set -u

SENTINEL='[Request interrupted by user]'

SINCE=""
EPIC=""
TRANSCRIPTS_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --since|--epic|--dir)
      if [ $# -lt 2 ]; then
        echo "extract-transcript: $1 requires a value" >&2
        exit 1
      fi
      ;;
  esac
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    --epic) EPIC="$2"; shift 2 ;;
    --dir) TRANSCRIPTS_DIR="$2"; shift 2 ;;
    *) echo "extract-transcript: unknown arg: $1" >&2; exit 1 ;;
  esac
done

# --epic best-effort resolution: use the epic index's `started:` frontmatter
# as a --since lower bound when the caller didn't already supply one; a
# missing index is not an error (best-effort — epic attribution on entries
# is nullable/best-effort).
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

# emit_digest <file> — prints digest/v1 lines for <file> on stdout, refs
# carrying half-open byte ranges computed from the file's real offsets.
emit_digest() {
  local f="$1"
  LC_ALL=C awk '{ printf "%d %d %s\n", off, off+length($0)+1, $0; off+=length($0)+1 }' "$f" \
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
  emit_digest "$f"
done

exit 0
