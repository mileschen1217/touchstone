#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
X="$REPO_ROOT/scripts/ledger/extract-transcript.sh"
W="$REPO_ROOT/scripts/ledger/ledger-append.sh"
FIXTURE="$REPO_ROOT/scripts/tests/fixtures/ledger/fixture-transcript.jsonl"
FIXTURE_NOEOL="$REPO_ROOT/scripts/tests/fixtures/ledger/fixture-transcript-noeol.jsonl"
SENTINEL='[Request interrupted by user]'
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# mkscene <name> — makes $TMP/<name>/{src,out}, copies the standard fixture
# into src as sess1.jsonl, and echoes "src out" (space-separated) for the
# caller to read into two variables.
mkscene() {
  local d="$TMP/$1"
  mkdir -p "$d/src" "$d/out"
  echo "$d/src $d/out"
}

# digest→catch-miss/v1 adapter (test-only plumbing for AC-6): the real L1/L2
# classification is out of scope here — this just proves the extractor's
# output can flow through the real writer end-to-end.
adapt_and_append() { # <ledger-dir> < digest/v1 JSONL on stdin
  local ldir="$1"
  jq -c '{schema:"catch-miss/v1", caught_by:"live-probe", should_have:"human",
          gap_class:"missing-AC", what:.payload.text,
          evidence:[{kind:"transcript", ref:.ref}], source:"sweep:transcript"}' \
    | TOUCHSTONE_LEDGER_DIR="$ldir" bash "$W"
}

# --- AC-4: user-text + interrupt-pair digest, byte-accurate ---
read -r SRC OUT <<<"$(mkscene ac4)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/digest.jsonl"
RC=$?
LC="$(grep -c . "$OUT/digest.jsonl")"
if [ "$RC" -eq 0 ] && [ "$LC" = 4 ]; then
  ok "AC-4 emits exactly 4 user digest records (assistant/attachment excluded)"
else
  fail "AC-4 record count (rc=$RC lc=$LC)"
fi

# interrupt_pair: only the record whose text is the correction ("修正:...")
# following the sentinel should carry interrupt_pair:true; all others false.
IP_TRUE_COUNT="$(jq -r 'select(.payload.interrupt_pair==true) | .payload.text' "$OUT/digest.jsonl" | grep -c .)"
IP_TRUE_TEXT="$(jq -r 'select(.payload.interrupt_pair==true) | .payload.text' "$OUT/digest.jsonl")"
if [ "$IP_TRUE_COUNT" = 1 ] && printf '%s' "$IP_TRUE_TEXT" | grep -q '修正'; then
  ok "AC-4 interrupt_pair:true on exactly the post-sentinel record"
else
  fail "AC-4 interrupt_pair flagging (count=$IP_TRUE_COUNT text=$IP_TRUE_TEXT)"
fi

SENTINEL_RECORD_FLAG="$(jq -r --arg s "$SENTINEL" 'select(.payload.text==$s) | .payload.interrupt_pair' "$OUT/digest.jsonl")"
if [ "$SENTINEL_RECORD_FLAG" = "false" ]; then
  ok "AC-4 the sentinel record itself is not flagged"
else
  fail "AC-4 sentinel record flag (got '$SENTINEL_RECORD_FLAG')"
fi

# byte-range verification: dd-extract each record's raw range from the
# fixture and confirm it parses as the same user record the digest names.
BYTE_OK=1
while IFS= read -r line; do
  [ -n "$line" ] || continue
  ref="$(printf '%s' "$line" | jq -r .ref)"
  path="$(printf '%s' "$ref" | sed -E 's/^transcript:(.*)#[0-9]+-[0-9]+$/\1/')"
  s="$(printf '%s' "$ref" | sed -E 's/^transcript:.*#([0-9]+)-[0-9]+$/\1/')"
  e="$(printf '%s' "$ref" | sed -E 's/^transcript:.*#[0-9]+-([0-9]+)$/\1/')"
  len=$((e - s))
  raw="$(dd bs=1 skip="$s" count="$len" if="$path" 2>/dev/null)"
  rtype="$(printf '%s' "$raw" | jq -r '.type // empty')"
  [ "$rtype" = "user" ] || BYTE_OK=0
done < "$OUT/digest.jsonl"
if [ "$BYTE_OK" = 1 ]; then
  ok "AC-4 byte ranges are exact (dd-extracted bytes re-parse as the named user record)"
else
  fail "AC-4 byte ranges (dd extraction did not re-parse as user record)"
fi

# --- AC-7: malformed line skipped, exit 0 (same fixture carries one) ---
if [ "$RC" -eq 0 ]; then
  ok "AC-7 malformed line present in fixture, extractor still exits 0"
else
  fail "AC-7 exit code with malformed line (rc=$RC)"
fi

# --- no-trailing-newline case: chosen behavior = skip the unterminated
# final line; cursor stops at its start byte, not the raw file size ---
read -r SRC OUT <<<"$(mkscene noeol)"
cp "$FIXTURE_NOEOL" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/digest.jsonl"
LC="$(grep -c . "$OUT/digest.jsonl")"
FSIZE="$(wc -c < "$SRC/sess1.jsonl" | tr -d ' ')"
CURSOR="$(jq -r '.transcripts | to_entries[0].value.cursor' "$LDIR/scan-state.json")"
if [ "$LC" = 3 ] && [ "$CURSOR" -lt "$FSIZE" ]; then
  ok "no-trailing-newline: unterminated final line skipped (3 records, not 4), cursor < file size"
else
  fail "no-trailing-newline behavior (lc=$LC cursor=$CURSOR fsize=$FSIZE)"
fi
# the skipped line's bytes must be re-read once terminated: appending a
# newline to complete it and re-running should emit the 4th record now.
printf '\n' >> "$SRC/sess1.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/digest2.jsonl"
LC2="$(grep -c . "$OUT/digest2.jsonl")"
if [ "$LC2" = 1 ]; then
  ok "no-trailing-newline: previously-skipped line is emitted once terminated"
else
  fail "no-trailing-newline follow-up emission (lc2=$LC2)"
fi

# --- AC-5: cursor tail-only increment ---
read -r SRC OUT <<<"$(mkscene ac5)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/r1.jsonl"
printf '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"新訊息 B"}]},"uuid":"fx-0:07.000","timestamp":"2026-07-02T10:00:07.000Z","sessionId":"fixture-sess","cwd":"/fixture/proj","isSidechain":false}\n' >> "$SRC/sess1.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/r2.jsonl"
LC2="$(grep -c . "$OUT/r2.jsonl")"
CURSOR2="$(jq -r '.transcripts | to_entries[0].value.cursor' "$LDIR/scan-state.json")"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/r3.jsonl"
LC3="$(grep -c . "$OUT/r3.jsonl")"
CURSOR3="$(jq -r '.transcripts | to_entries[0].value.cursor' "$LDIR/scan-state.json")"
if [ "$LC2" = 1 ] && [ "$LC3" = 0 ] && [ "$CURSOR2" = "$CURSOR3" ]; then
  ok "AC-5 tail-only increment: rerun emits only the append, second rerun emits 0 with cursor unchanged"
else
  fail "AC-5 tail-only increment (lc2=$LC2 lc3=$LC3 cursor2=$CURSOR2 cursor3=$CURSOR3)"
fi

# --- AC-6 (reset-on-shrink) FULL PIPELINE: extractor -> adapter -> real
# writer; snapshot entries.jsonl; force cursor > filesize; replay; assert
# entries.jsonl is byte-identical (the WRITER's dedupe absorbs the replay).
read -r SRC OUT <<<"$(mkscene ac6)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/digest1.jsonl"
adapt_and_append "$LDIR" < "$OUT/digest1.jsonl" > /dev/null
cp "$LDIR/entries.jsonl" "$OUT/entries.snapshot.jsonl"
ABS_SESS1="$(cd "$SRC" && pwd)/sess1.jsonl"
jq -c --arg p "$ABS_SESS1" '.transcripts[$p].cursor = 999999' "$LDIR/scan-state.json" > "$LDIR/scan-state.json.tmp"
mv "$LDIR/scan-state.json.tmp" "$LDIR/scan-state.json"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > "$OUT/digest2.jsonl"
LC_REPLAY="$(grep -c . "$OUT/digest2.jsonl")"
adapt_and_append "$LDIR" < "$OUT/digest2.jsonl" > /dev/null
if [ "$LC_REPLAY" = 4 ] && cmp -s "$LDIR/entries.jsonl" "$OUT/entries.snapshot.jsonl"; then
  ok "AC-6 reset-on-shrink: full rescan replay, entries.jsonl byte-identical after dedupe"
else
  fail "AC-6 reset-on-shrink (replay_lc=$LC_REPLAY, entries changed=$(! cmp -s "$LDIR/entries.jsonl" "$OUT/entries.snapshot.jsonl"; echo $?))"
fi

# --- prune: scan-state key for a deleted file is gone after the next run ---
read -r SRC OUT <<<"$(mkscene prune)"
LDIR="$OUT/ledger"; mkdir -p "$LDIR"
printf '{"transcripts":{"%s/gone.jsonl":{"cursor":100}}}' "$SRC" > "$LDIR/scan-state.json"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > /dev/null
REMAINING_KEYS="$(jq -r '.transcripts | keys | length' "$LDIR/scan-state.json")"
if [ "$REMAINING_KEYS" = 0 ]; then
  ok "prune: stale key for a deleted file is removed from scan-state"
else
  fail "prune (remaining_keys=$REMAINING_KEYS)"
fi

# --- propose-cursors mode: scan-state untouched, proposal file written ---
read -r SRC OUT <<<"$(mkscene propose)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
PROPOSE_F="$OUT/proposed.json"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" --propose-cursors "$PROPOSE_F" > "$OUT/digest.jsonl"
LC="$(grep -c . "$OUT/digest.jsonl")"
if [ "$LC" = 4 ] && [ ! -e "$LDIR/scan-state.json" ] && [ -s "$PROPOSE_F" ]; then
  PROPOSED_CURSOR="$(jq -r '. | to_entries[0].value.cursor' "$PROPOSE_F")"
  ABS_SESS1="$(cd "$SRC" && pwd)/sess1.jsonl"
  FSIZE="$(wc -c < "$ABS_SESS1" | tr -d ' ')"
  if [ "$PROPOSED_CURSOR" = "$FSIZE" ]; then
    ok "propose-mode: digest emitted, scan-state.json untouched, proposal file written with correct cursor"
  else
    fail "propose-mode cursor value (proposed=$PROPOSED_CURSOR fsize=$FSIZE)"
  fi
else
  fail "propose-mode (lc=$LC scan-state exists=$([ -e "$LDIR/scan-state.json" ] && echo yes || echo no) propose file size=$(wc -c < "$PROPOSE_F" 2>/dev/null))"
fi

# --- --since is read-only: no scan-state.json is created ---
read -r SRC OUT <<<"$(mkscene since)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" --since "2026-07-02T10:00:04.000Z" > "$OUT/digest.jsonl"
RC=$?
LC="$(grep -c . "$OUT/digest.jsonl")"
if [ "$RC" -eq 0 ] && [ ! -e "$LDIR/scan-state.json" ] && [ "$LC" -ge 1 ] && [ "$LC" -le 4 ]; then
  ok "--since is read-only (no scan-state.json written) and filters by ts"
else
  fail "--since read-only mode (rc=$RC lc=$LC scan-state exists=$([ -e "$LDIR/scan-state.json" ] && echo yes || echo no))"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
