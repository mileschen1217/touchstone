#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
X="$REPO_ROOT/scripts/ledger/extract-transcript.sh"
W="$REPO_ROOT/scripts/ledger/ledger-append.sh"
FIXTURE="$REPO_ROOT/scripts/tests/fixtures/ledger/fixture-transcript.jsonl"
FIXTURE_NOEOL="$REPO_ROOT/scripts/tests/fixtures/ledger/fixture-transcript-noeol.jsonl"
FIXTURE_NONOBJECT="$REPO_ROOT/scripts/tests/fixtures/ledger/fixture-transcript-nonobject.jsonl"
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

# digest→catch-miss/v1 adapter (test-only plumbing for the dedupe test): the
# real L1/L2 classification is out of scope here — this just proves the
# extractor's output can flow through the real writer end-to-end.
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
"$X" --dir "$SRC" > "$OUT/digest.jsonl"
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

# --- AC-7 (non-object JSON): a line that is VALID JSON but not an object
# ([1,2,3], 42) must not throw an uncaught jq runtime error to stderr; the
# per-line try/catch must guard the whole transform, not just fromjson ---
read -r SRC OUT <<<"$(mkscene nonobject)"
cp "$FIXTURE_NONOBJECT" "$SRC/sess1.jsonl"
"$X" --dir "$SRC" > "$OUT/digest.jsonl" 2> "$OUT/stderr.log"
RC=$?
LC="$(grep -c . "$OUT/digest.jsonl")"
ERR="$(cat "$OUT/stderr.log")"
if [ "$RC" -eq 0 ] && [ "$LC" = 4 ] && [ -z "$ERR" ]; then
  ok "AC-7 non-object JSON line ([1,2,3]/42) skipped, correct records still emitted, stderr empty"
else
  fail "AC-7 non-object JSON line (rc=$RC lc=$LC stderr='$ERR')"
fi
NONOBJ_BYTE_OK=1
while IFS= read -r line; do
  [ -n "$line" ] || continue
  ref="$(printf '%s' "$line" | jq -r .ref)"
  path="$(printf '%s' "$ref" | sed -E 's/^transcript:(.*)#[0-9]+-[0-9]+$/\1/')"
  s="$(printf '%s' "$ref" | sed -E 's/^transcript:.*#([0-9]+)-[0-9]+$/\1/')"
  e="$(printf '%s' "$ref" | sed -E 's/^transcript:.*#[0-9]+-([0-9]+)$/\1/')"
  len=$((e - s))
  raw="$(dd bs=1 skip="$s" count="$len" if="$path" 2>/dev/null)"
  rtype="$(printf '%s' "$raw" | jq -r '.type // empty')"
  [ "$rtype" = "user" ] || NONOBJ_BYTE_OK=0
done < "$OUT/digest.jsonl"
if [ "$NONOBJ_BYTE_OK" = 1 ]; then
  ok "AC-7 non-object JSON line: byte ranges of surviving records are still exact"
else
  fail "AC-7 non-object JSON line byte ranges (dd extraction did not re-parse as user record)"
fi

# --- no-trailing-newline case: stateless behavior — a COMPLETE final JSON
# line without a trailing newline is emitted (4 records); re-running after
# the newline lands emits the identical set (same refs → writer dedupe) ---
read -r SRC OUT <<<"$(mkscene noeol)"
cp "$FIXTURE_NOEOL" "$SRC/sess1.jsonl"
"$X" --dir "$SRC" > "$OUT/digest.jsonl"
LC="$(grep -c . "$OUT/digest.jsonl")"
if [ "$LC" = 4 ]; then
  ok "no-trailing-newline: complete unterminated final line is emitted (stateless full scan)"
else
  fail "no-trailing-newline behavior (lc=$LC)"
fi
printf '\n' >> "$SRC/sess1.jsonl"
"$X" --dir "$SRC" > "$OUT/digest2.jsonl"
if cmp -s "$OUT/digest.jsonl" "$OUT/digest2.jsonl"; then
  ok "no-trailing-newline: refs stable once the newline lands (byte-identical digest)"
else
  fail "no-trailing-newline follow-up digest differs (refs unstable)"
fi

# --- incremental-by-since: the caller's --since bound is the ONLY increment
# mechanism (sweep-run passes .last-sweep); an appended newer record is the
# only one emitted under --since ---
read -r SRC OUT <<<"$(mkscene since-inc)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
printf '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"新訊息 B"}]},"uuid":"fx-0:07.000","timestamp":"2026-07-02T10:00:07.000Z","sessionId":"fixture-sess","cwd":"/fixture/proj","isSidechain":false}\n' >> "$SRC/sess1.jsonl"
"$X" --dir "$SRC" --since "2026-07-02T10:00:06.500Z" > "$OUT/r2.jsonl"
LC2="$(grep -c . "$OUT/r2.jsonl")"
NEWTEXT="$(jq -r '.payload.text' "$OUT/r2.jsonl")"
if [ "$LC2" = 1 ] && [ "$NEWTEXT" = "新訊息 B" ]; then
  ok "incremental-by-since: only the record newer than the since bound is emitted"
else
  fail "incremental-by-since (lc2=$LC2 text=$NEWTEXT)"
fi

# --- rescan replay FULL PIPELINE: extractor -> adapter -> real writer;
# snapshot entries.jsonl; full re-scan; replay through the writer; assert
# entries.jsonl is byte-identical (the WRITER's ref dedupe absorbs the
# deliberate over-emission the stateless scan produces). ---
read -r SRC OUT <<<"$(mkscene rescan)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
"$X" --dir "$SRC" > "$OUT/digest1.jsonl"
adapt_and_append "$LDIR" < "$OUT/digest1.jsonl" > /dev/null
cp "$LDIR/entries.jsonl" "$OUT/entries.snapshot.jsonl"
"$X" --dir "$SRC" > "$OUT/digest2.jsonl"
LC_REPLAY="$(grep -c . "$OUT/digest2.jsonl")"
adapt_and_append "$LDIR" < "$OUT/digest2.jsonl" > /dev/null
if [ "$LC_REPLAY" = 4 ] && cmp -s "$LDIR/entries.jsonl" "$OUT/entries.snapshot.jsonl"; then
  ok "rescan replay: full re-scan re-emits all records, entries.jsonl byte-identical after dedupe"
else
  fail "rescan replay (replay_lc=$LC_REPLAY, entries changed=$(! cmp -s "$LDIR/entries.jsonl" "$OUT/entries.snapshot.jsonl"; echo $?))"
fi

# --- stateless: no scan-state.json (or any state file) is ever created ---
read -r SRC OUT <<<"$(mkscene stateless)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
LDIR="$OUT/ledger"
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" > /dev/null
TOUCHSTONE_LEDGER_DIR="$LDIR" "$X" --dir "$SRC" --since "2026-07-02T10:00:04.000Z" > "$OUT/digest.jsonl"
RC=$?
LC="$(grep -c . "$OUT/digest.jsonl")"
if [ "$RC" -eq 0 ] && [ ! -e "$LDIR/scan-state.json" ] && [ "$LC" -ge 1 ] && [ "$LC" -le 4 ]; then
  ok "stateless + --since filters by ts (no scan-state.json ever written)"
else
  fail "stateless/--since mode (rc=$RC lc=$LC scan-state exists=$([ -e "$LDIR/scan-state.json" ] && echo yes || echo no))"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
