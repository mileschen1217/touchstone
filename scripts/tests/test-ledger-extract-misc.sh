#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
XR="$REPO_ROOT/scripts/ledger/extract-reckoning.sh"
XF="$REPO_ROOT/scripts/ledger/extract-firelog.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ============================================================
# AC-9 — reckoning outcomes digest
# ============================================================

EPIC_DIR="$TMP/ac9/epic"
mkdir -p "$EPIC_DIR"
cat > "$EPIC_DIR/index.md" <<'EOF'
---
slug: demo
status: active
---

# Demo epic

## Evidence Reckoning

| AC | Covered by | [unverified] | live-bearing? | waiver | Issue |
|----|----|----|----|----|----|
| AC-1 | some coverage | — | no | — | — |
| AC-2 | none | [unverified: no test asserts this] | no | — | — |
| AC-3 | none | [unverified: missing live artifact] | yes | — | — |

## Amendment Log

### Amendment — AC-5 corrected wrong file reference

Original text pointed to the wrong hook file; this amendment corrects the
path to hooks/run-project-checks.sh — a real behavioral miss caught late.

### Amendment — AC-9 fixed typo in identifier column

Typo-fix only: "AC-9" was written as "AC-9 " with a trailing space in the
table header; corrected for consistency, not a miss.
EOF

OUT="$TMP/ac9/digest.jsonl"
"$XR" --epic-dir "$EPIC_DIR" > "$OUT"
RC=$?
LC="$(grep -c . "$OUT")"
if [ "$RC" -eq 0 ] && [ "$LC" = 4 ]; then
  ok "AC-9 emits exactly 4 candidate records (2 unverified rows, 2 amendments — typo one included)"
else
  fail "AC-9 record count (rc=$RC lc=$LC)"
fi

UNVERIFIED_COUNT="$(jq -r 'select(.payload.row_kind=="unverified")' "$OUT" | jq -s 'length')"
AMENDMENT_COUNT="$(jq -r 'select(.payload.row_kind=="amendment")' "$OUT" | jq -s 'length')"
if [ "$UNVERIFIED_COUNT" = 2 ] && [ "$AMENDMENT_COUNT" = 2 ]; then
  ok "AC-9 row_kind split: 2 unverified + 2 amendment"
else
  fail "AC-9 row_kind split (unverified=$UNVERIFIED_COUNT amendment=$AMENDMENT_COUNT)"
fi

# every record: schema/source correct, ref carries the index.md path,
# identifier and snippet both non-empty.
ALL_SHAPE_OK=1
while IFS= read -r line; do
  [ -n "$line" ] || continue
  schema="$(printf '%s' "$line" | jq -r .schema)"
  source="$(printf '%s' "$line" | jq -r .source)"
  ref="$(printf '%s' "$line" | jq -r .ref)"
  ident="$(printf '%s' "$line" | jq -r .payload.identifier)"
  snippet="$(printf '%s' "$line" | jq -r .payload.snippet)"
  [ "$schema" = "digest/v1" ] || ALL_SHAPE_OK=0
  [ "$source" = "reckoning" ] || ALL_SHAPE_OK=0
  case "$ref" in
    reckoning:*index.md\#*) ;;
    *) ALL_SHAPE_OK=0 ;;
  esac
  [ -n "$ident" ] || ALL_SHAPE_OK=0
  [ -n "$snippet" ] || ALL_SHAPE_OK=0
done < "$OUT"
if [ "$ALL_SHAPE_OK" = 1 ]; then
  ok "AC-9 every record carries schema/source/path-ref + non-empty identifier + non-empty snippet"
else
  fail "AC-9 record shape (one or more records missing a required field)"
fi

# the typo-fix amendment (AC-9 identifier) must still be present — L0 never
# filters on miss-vs-non-miss meaning.
TYPO_PRESENT="$(jq -r 'select(.payload.identifier=="AC-9" and .payload.row_kind=="amendment") | .payload.identifier' "$OUT")"
if [ "$TYPO_PRESENT" = "AC-9" ]; then
  ok "AC-9 the non-miss typo-fix amendment is included, not filtered (L1's job)"
else
  fail "AC-9 typo-fix amendment missing (got '$TYPO_PRESENT')"
fi

# missing epic index: source absent, emits nothing, exit 0.
"$XR" --epic-dir "$TMP/ac9/nonexistent" > "$TMP/ac9/empty.jsonl"
RC=$?
LC_EMPTY="$(grep -c . "$TMP/ac9/empty.jsonl")"
if [ "$RC" -eq 0 ] && [ "$LC_EMPTY" = 0 ]; then
  ok "missing epic index: source absent, exit 0, no records"
else
  fail "missing epic index (rc=$RC lc=$LC_EMPTY)"
fi

# regression — a colon-style header cell ("[unverified: reason]", the shape
# the close-procedure table template ships) must not become a record; only
# the data row is emitted. The header row's first cell is the literal "AC".
HDR_DIR="$TMP/hdr/epic"
mkdir -p "$HDR_DIR"
cat > "$HDR_DIR/index.md" <<'EOF'
---
slug: demo
status: active
---

## Evidence Reckoning

| AC | Covered by (test ref) | [unverified: reason] | live-bearing? | waiver | Issue |
|----|----|----|----|----|----|
| AC-4 | none | [unverified: no test asserts this] | no | — | — |
EOF

OUT_HDR="$TMP/hdr/digest.jsonl"
"$XR" --epic-dir "$HDR_DIR" > "$OUT_HDR"
RC=$?
LC_HDR="$(grep -c . "$OUT_HDR")"
HDR_IDENT="$(jq -r '.payload.identifier' "$OUT_HDR" 2>/dev/null)"
if [ "$RC" -eq 0 ] && [ "$LC_HDR" = 1 ] && [ "$HDR_IDENT" = "AC-4" ]; then
  ok "colon-style header row is skipped; only the AC-4 data row is emitted"
else
  fail "colon-style header regression (rc=$RC lc=$LC_HDR ident=$HDR_IDENT)"
fi

# ============================================================
# AC-10 — fire-log pattern digest + incremental re-run
# ============================================================

LDIR="$TMP/ac10/ledger"
mkdir -p "$LDIR"
cat > "$LDIR/fire-log.jsonl" <<'EOF'
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:01.000Z","check":"check-x","repo":"/repo","stage":"pre-commit"}
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:02.000Z","check":"check-x","repo":"/repo","stage":"pre-commit"}
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:03.000Z","check":"check-y","repo":"/repo","stage":"pre-push"}
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:04.000Z","check":"check-x","repo":"/repo","stage":"pre-commit"}
EOF

OUT1="$TMP/ac10/digest1.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$XF" > "$OUT1"
RC=$?
LC1="$(grep -c . "$OUT1")"
COUNT_X="$(jq -r 'select(.payload.check=="check-x") | .payload.count' "$OUT1")"
COUNT_Y="$(jq -r 'select(.payload.check=="check-y") | .payload.count' "$OUT1")"
FIRST_X="$(jq -r 'select(.payload.check=="check-x") | .payload.first_ts' "$OUT1")"
LAST_X="$(jq -r 'select(.payload.check=="check-x") | .payload.last_ts' "$OUT1")"
if [ "$RC" -eq 0 ] && [ "$LC1" = 2 ] && [ "$COUNT_X" = 3 ] && [ "$COUNT_Y" = 1 ] \
   && [ "$FIRST_X" = "2026-07-02T10:00:01.000Z" ] && [ "$LAST_X" = "2026-07-02T10:00:04.000Z" ]; then
  ok "AC-10 first run: 2 aggregates, check-x count=3 (correct first/last ts), check-y count=1"
else
  fail "AC-10 first run (rc=$RC lc=$LC1 count_x=$COUNT_X count_y=$COUNT_Y first_x=$FIRST_X last_x=$LAST_X)"
fi

REF_X="$(jq -r 'select(.payload.check=="check-x") | .ref' "$OUT1")"
case "$REF_X" in
  firelog:*fire-log.jsonl\#check-x) ok "AC-10 ref format firelog:<abs path>#<check>" ;;
  *) fail "AC-10 ref format (got '$REF_X')" ;;
esac

# rerun with no new events: zero records.
OUT2="$TMP/ac10/digest2.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$XF" > "$OUT2"
LC2="$(grep -c . "$OUT2")"
if [ "$LC2" = 0 ]; then
  ok "AC-10 rerun with no new events emits zero records"
else
  fail "AC-10 no-op rerun (lc2=$LC2)"
fi

# append 2 more events (1 check-x, 1 check-y), rerun: only the NEW tail is
# aggregated (byte-cursor tail-only, same contract as transcripts).
cat >> "$LDIR/fire-log.jsonl" <<'EOF'
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:05.000Z","check":"check-y","repo":"/repo","stage":"pre-push"}
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:06.000Z","check":"check-x","repo":"/repo","stage":"pre-commit"}
EOF
OUT3="$TMP/ac10/digest3.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$XF" > "$OUT3"
LC3="$(grep -c . "$OUT3")"
COUNT_X3="$(jq -r 'select(.payload.check=="check-x") | .payload.count' "$OUT3")"
COUNT_Y3="$(jq -r 'select(.payload.check=="check-y") | .payload.count' "$OUT3")"
if [ "$LC3" = 2 ] && [ "$COUNT_X3" = 1 ] && [ "$COUNT_Y3" = 1 ]; then
  ok "AC-10 incremental re-run aggregates ONLY the new tail (1 new check-x, 1 new check-y)"
else
  fail "AC-10 incremental re-run (lc3=$LC3 count_x3=$COUNT_X3 count_y3=$COUNT_Y3)"
fi

CURSOR_AFTER="$(jq -r '.firelog | to_entries[0].value.cursor' "$LDIR/scan-state.json")"
FSIZE="$(wc -c < "$LDIR/fire-log.jsonl" | tr -d ' ')"
if [ "$CURSOR_AFTER" = "$FSIZE" ]; then
  ok "AC-10 cursor advanced to the new file size after the incremental re-run"
else
  fail "AC-10 cursor advancement (cursor=$CURSOR_AFTER fsize=$FSIZE)"
fi

# missing fire log: source absent, emits nothing, exit 0.
LDIR_EMPTY="$TMP/ac10-empty/ledger"
mkdir -p "$LDIR_EMPTY"
TOUCHSTONE_LEDGER_DIR="$LDIR_EMPTY" "$XF" > "$TMP/ac10/empty.jsonl"
RC=$?
LC_EMPTY="$(grep -c . "$TMP/ac10/empty.jsonl")"
if [ "$RC" -eq 0 ] && [ "$LC_EMPTY" = 0 ] && [ ! -e "$LDIR_EMPTY/scan-state.json" ]; then
  ok "missing fire log: source absent, exit 0, no records, no scan-state written"
else
  fail "missing fire log (rc=$RC lc=$LC_EMPTY)"
fi

# propose-cursors mode: scan-state untouched, proposal file written.
LDIR_PROPOSE="$TMP/ac10-propose/ledger"
mkdir -p "$LDIR_PROPOSE"
cp "$LDIR/fire-log.jsonl" "$LDIR_PROPOSE/fire-log.jsonl"
PROPOSE_F="$TMP/ac10-propose/proposed.json"
TOUCHSTONE_LEDGER_DIR="$LDIR_PROPOSE" "$XF" --propose-cursors "$PROPOSE_F" > "$TMP/ac10/propose-digest.jsonl"
LC_PROP="$(grep -c . "$TMP/ac10/propose-digest.jsonl")"
if [ "$LC_PROP" = 2 ] && [ ! -e "$LDIR_PROPOSE/scan-state.json" ] && [ -s "$PROPOSE_F" ]; then
  ok "propose-mode: digest emitted, scan-state.json untouched, proposal file written"
else
  fail "propose-mode (lc=$LC_PROP scan-state exists=$([ -e "$LDIR_PROPOSE/scan-state.json" ] && echo yes || echo no))"
fi

# --since is read-only: no scan-state.json is created.
LDIR_SINCE="$TMP/ac10-since/ledger"
mkdir -p "$LDIR_SINCE"
cp "$LDIR/fire-log.jsonl" "$LDIR_SINCE/fire-log.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR_SINCE" "$XF" --since "2026-07-02T10:00:04.000Z" > "$TMP/ac10/since-digest.jsonl"
RC=$?
LC_SINCE="$(grep -c . "$TMP/ac10/since-digest.jsonl")"
if [ "$RC" -eq 0 ] && [ ! -e "$LDIR_SINCE/scan-state.json" ] && [ "$LC_SINCE" -ge 1 ]; then
  ok "--since is read-only (no scan-state.json written) and filters events by ts before aggregating"
else
  fail "--since read-only mode (rc=$RC lc=$LC_SINCE scan-state exists=$([ -e "$LDIR_SINCE/scan-state.json" ] && echo yes || echo no))"
fi

# ============================================================
# cross-section scan-state isolation — extract-firelog.sh must only touch
# its own "firelog" section, leaving sibling sections ("git",
# "transcripts") byte-for-byte untouched.
# ============================================================

LDIR_ISO="$TMP/isolation/ledger"
mkdir -p "$LDIR_ISO"
cat > "$LDIR_ISO/fire-log.jsonl" <<'EOF'
{"schema":"fire-event/v1","ts":"2026-07-02T10:00:01.000Z","check":"check-x","repo":"/repo","stage":"pre-commit"}
EOF
SEED_STATE='{"git":{"/x":{"last_swept":"abc"}},"transcripts":{"/y":{"cursor":7}}}'
printf '%s\n' "$SEED_STATE" > "$LDIR_ISO/scan-state.json"

TOUCHSTONE_LEDGER_DIR="$LDIR_ISO" "$XF" > "$TMP/isolation/digest.jsonl"

GIT_BEFORE="$(printf '%s' "$SEED_STATE" | jq -c '.git')"
TRANSCRIPTS_BEFORE="$(printf '%s' "$SEED_STATE" | jq -c '.transcripts')"
GIT_AFTER="$(jq -c '.git' "$LDIR_ISO/scan-state.json")"
TRANSCRIPTS_AFTER="$(jq -c '.transcripts' "$LDIR_ISO/scan-state.json")"
FIRELOG_AFTER="$(jq -c '.firelog // empty' "$LDIR_ISO/scan-state.json")"
if [ "$GIT_BEFORE" = "$GIT_AFTER" ] && [ "$TRANSCRIPTS_BEFORE" = "$TRANSCRIPTS_AFTER" ] && [ -n "$FIRELOG_AFTER" ]; then
  ok "cross-section isolation: .git and .transcripts unchanged, .firelog now present"
else
  fail "cross-section isolation (git_before=$GIT_BEFORE git_after=$GIT_AFTER transcripts_before=$TRANSCRIPTS_BEFORE transcripts_after=$TRANSCRIPTS_AFTER firelog_after=$FIRELOG_AFTER)"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
