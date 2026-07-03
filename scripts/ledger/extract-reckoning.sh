#!/usr/bin/env bash
# extract-reckoning.sh — L0 digest extractor for epic-close Evidence
# Reckoning artifacts: `[unverified: ...]` table rows and Amendment Log
# entries in an epic's index.md, plus the spec files it references. Emits
# CANDIDATES for L1 judgment — every row/entry found is emitted, including
# non-miss corrective amendments (e.g. a typo fix); filtering is L1's job,
# never the extractor's.
#
# Usage: extract-reckoning.sh --epic-dir <path>
#
# Reckoning needs no cursor: it is read once, at the owning epic's close
# (spec Interfaces § scan-state.json). No --since/--epic/--propose-cursors
# — there is no natural per-row timestamp to filter on, and re-running
# this extractor always re-reads the whole artifact set; the writer's
# evidence-ref dedupe absorbs any replay.
#
# Row/entry detection (grep/awk, no cursor state):
#  - Caveat: the "|"+"[unverified:" heuristic can also fire on a prose
#    bullet that happens to use "|" inside a backtick span (e.g. a code
#    snippet quoting a shell pipe) rather than an actual table row. This
#    is over-inclusive by design (intentional over-extraction, see note
#    below) — L1 filters.
#  - "[unverified" row: a markdown table row (contains "|") whose matched
#    cell contains "[unverified:" (colon required), EXCLUDING the table's
#    own COLUMN HEADER row (first non-empty cell is the literal "AC") — the
#    colon heuristic alone is not enough because the close-procedure table
#    template shipped its header cell as "[unverified: reason]" WITH colon,
#    which turned every reckoning table header into a false record. The
#    row's identifier is its first non-empty table cell when it matches
#    AC-<n>[<suffix>]; otherwise "row-<line-number>".
#  - Amendment entry: any "## Amendment Log" section's "###" subsections
#    each become one entry (identifier = an AC-<n> pattern found in the
#    heading, else "amendment-<n>"); when a Log has no "###" subsections,
#    its top-level "- " bullets become entries instead. Every "###"
#    subsection is counted, including non-entry ones like an "Old → new AC
#    mapping" table heading — intentional over-extraction: L0 candidates
#    are not filtered for miss-vs-non-miss meaning.
set -u

EPIC_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --epic-dir)
      if [ $# -lt 2 ]; then
        echo "extract-reckoning: $1 requires a value" >&2
        exit 1
      fi
      EPIC_DIR="$2"; shift 2 ;;
    *) echo "extract-reckoning: unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$EPIC_DIR" ]; then
  echo "extract-reckoning: --epic-dir is required" >&2
  exit 1
fi

INDEX="$EPIC_DIR/index.md"

if [ ! -f "$INDEX" ]; then
  # source absent: nothing to scan, exit 0 (Error Handling § source absent).
  exit 0
fi

SOH=$'\x01'

# scan_file <path> — prints SOH-delimited "row_kind SOH identifier SOH
# snippet" lines for every [unverified: ...] row and Amendment Log entry
# in <path>.
scan_file() {
  local path="$1"
  awk -v SOH="$SOH" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function flush_entry() {
      if (in_h3_entry) {
        print "amendment" SOH entry_id SOH trim(entry_text)
        in_h3_entry = 0
        entry_id = ""
        entry_text = ""
      }
    }
    {
      line = $0

      if (index(line, "|") > 0 && index(line, "[unverified:") > 0) {
        n = split(line, cells, "|")
        ident = ""
        for (i = 1; i <= n; i++) {
          c = trim(cells[i])
          if (c != "") { ident = c; break }
        }
        gsub(/\*\*/, "", ident); gsub(/`/, "", ident)
        if (ident != "AC") {
          if (ident !~ /^AC-[0-9]+[A-Za-z]*$/) { ident = "row-" NR }
          cell_text = ""
          for (i = 1; i <= n; i++) {
            if (index(cells[i], "[unverified:") > 0) { cell_text = trim(cells[i]); break }
          }
          print "unverified" SOH ident SOH cell_text
        }
      }

      if (line ~ /^##[ \t]+Amendment Log/) {
        in_amend_section = 1
        seen_h3_in_section = 0
        next
      }
      if (in_amend_section && line ~ /^##[ \t]/ && line !~ /^###/) {
        flush_entry()
        in_amend_section = 0
        next
      }
      if (in_amend_section) {
        if (line ~ /^###[ \t]/) {
          flush_entry()
          seen_h3_in_section = 1
          heading = line
          sub(/^###[ \t]+/, "", heading)
          id = "amendment-" (++amend_counter)
          if (match(heading, /AC-[0-9]+[A-Za-z]*/)) {
            id = substr(heading, RSTART, RLENGTH)
          }
          in_h3_entry = 1
          entry_id = id
          entry_text = heading
          next
        }
        if (in_h3_entry) {
          entry_text = entry_text " " line
          next
        }
        if (!seen_h3_in_section && line ~ /^-[ \t]+/) {
          bline = line
          sub(/^-[ \t]+/, "", bline)
          id = "amendment-" (++amend_counter)
          if (match(bline, /AC-[0-9]+[A-Za-z]*/)) {
            id = substr(bline, RSTART, RLENGTH)
          }
          print "amendment" SOH id SOH trim(bline)
          next
        }
      }
    }
    END { flush_entry() }
  ' "$path"
}

# resolve_files — the epic index itself, plus every `.touchstone/specs/*.md`
# path referenced (as an inline-code span) in the index body, resolved
# against the repo toplevel. Missing/broken references are skipped
# (best-effort, per the general CLI shapes convention for referenced
# artifacts).
FILES=("$INDEX")
TOPLEVEL="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$TOPLEVEL" ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    cand="$TOPLEVEL/$rel"
    if [ -f "$cand" ]; then
      FILES+=("$cand")
    fi
  done < <(grep -oE '\.touchstone/specs/[A-Za-z0-9_./-]+\.md' "$INDEX" | sort -u)
fi

for f in "${FILES[@]:-}"; do
  [ -n "$f" ] || continue
  ABS_F="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
  scan_file "$f" \
    | jq -Rc --arg soh "$SOH" --arg path "$ABS_F" '
        select(length > 0)
        | split($soh) as $f
        | {schema: "digest/v1", source: "reckoning",
           ref: ("reckoning:" + $path + "#" + $f[1]),
           ts: "",
           payload: {row_kind: $f[0], identifier: $f[1], snippet: ($f[2][0:500])}}
      '
done

exit 0
