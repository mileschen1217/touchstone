#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
W="$REPO_ROOT/scripts/ledger/ledger-append.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mkl() { L="$TMP/$1"; mkdir -p "$L"; echo "$L"; }

# entry <what> <kind> <ref> [source]
entry() {
  local w="$1" k="$2" r="$3" src="${4:-label}"
  jq -nc --arg w "$w" --arg k "$k" --arg r "$r" --arg src "$src" \
    '{schema:"catch-miss/v1", id:("e-"+$w), dedupe_key:"", ts:"2026-07-02T00:00:00Z",
      caught_by:"human", should_have:"design-review", gap_class:"missing-AC",
      what:$w, evidence:[{kind:$k, ref:$r}], source:$src}'
}

# bad_entry <jq-override-filter> — applies the filter to a well-formed base
# entry (via stdin, NOT -n/--null-input, so the base object is actually used)
bad_entry() {
  jq -c "$1" <<'BASE'
{"schema":"catch-miss/v1","id":"e1","dedupe_key":"","ts":"2026-07-02T00:00:00Z",
 "caught_by":"human","should_have":"design-review","gap_class":"missing-AC",
 "what":"m1","evidence":[{"kind":"git","ref":"git:x"}],"source":"label"}
BASE
}

assert_rejected() { # <label> <json>
  local label="$1" json="$2"
  local L; L="$(mkl "rej-$RANDOM")"
  local err
  err="$(printf '%s\n' "$json" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W" 2>&1 1>/dev/null)"
  local rc=$?
  if [ "$rc" -ne 0 ] && [ ! -s "$L/entries.jsonl" ] && [ -n "$err" ]; then
    ok "$label"
  else
    fail "$label (rc=$rc err='$err')"
  fi
}

assert_accepted() { # <label> <json>
  local label="$1" json="$2"
  local L; L="$(mkl "acc-$RANDOM")"
  printf '%s\n' "$json" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W" >/dev/null 2>/dev/null
  local rc=$?
  if [ "$rc" -eq 0 ] && [ -s "$L/entries.jsonl" ]; then
    ok "$label"
  else
    fail "$label (rc=$rc)"
  fi
}

# --- AC-1: valid entry round-trip ---
L="$(mkl ac1)"
printf '%s\n' "$(entry m1 git git:abc)" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
RC=$?
LINE="$(cat "$L/entries.jsonl" 2>/dev/null)"
if [ "$RC" -eq 0 ] \
  && [ "$(printf '%s' "$LINE" | jq -r .what)" = m1 ] \
  && [ "$(printf '%s' "$LINE" | jq -r .schema)" = "catch-miss/v1" ] \
  && [ "$(printf '%s' "$LINE" | jq -r '(.id!="") and (.ts!="") and (.dedupe_key!="")')" = "true" ] \
  && [ "$(printf '%s' "$LINE" | jq -r '.evidence | length')" -ge 1 ]; then
  ok "AC-1 valid entry round-trip"
else
  fail "AC-1 valid entry round-trip (rc=$RC line=$LINE)"
fi

# --- AC-2: dedupe no-op, source unmodified ---
L="$(mkl ac2)"
printf '%s\n' "$(entry m1 git git:sharedsha sweep:git)" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
printf '%s\n' "$(entry m1-reworded git git:sharedsha label)" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
RC=$?
LC="$(grep -c . "$L/entries.jsonl")"
SRC="$(jq -r .source "$L/entries.jsonl")"
if [ "$RC" -eq 0 ] && [ "$LC" = 1 ] && [ "$SRC" = "sweep:git" ]; then
  ok "AC-2 dedupe no-op, source unmodified"
else
  fail "AC-2 dedupe no-op (rc=$RC lc=$LC src=$SRC)"
fi

# --- AC-3 (second half): fresh git repo without gitignore line self-heals on first append ---
R="$TMP/ac3repo"; mkdir -p "$R"; ( cd "$R" && git init -q )
L="$R/.touchstone/ledger"
printf '%s\n' "$(entry m1 git git:ac3sha)" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
RC=$?
if [ "$RC" -eq 0 ] && ( cd "$R" && git check-ignore -q .touchstone/ledger/entries.jsonl ); then
  ok "AC-3 gitignore self-heal on first append"
else
  fail "AC-3 gitignore self-heal (rc=$RC)"
fi

# --- AC-18: schema-invalid entries rejected ---
assert_rejected "AC-18 missing what rejected"        "$(bad_entry 'del(.what)')"
assert_rejected "AC-18 gap_class=bogus rejected"      "$(bad_entry '.gap_class="bogus"')"
assert_rejected "AC-18 source=bogus rejected"         "$(bad_entry '.source="bogus"')"
assert_rejected "AC-18 empty evidence rejected"       "$(bad_entry '.evidence=[]')"
assert_rejected "AC-18 caught_by=nonsense-locus rejected" "$(bad_entry '.caught_by="nonsense-locus"')"
assert_accepted "AC-18 accepts checker:<name> prefix" "$(bad_entry '.caught_by="checker:check-foo.sh"')"

# --- AC-19: concurrent appends are line-atomic ---
L="$(mkl ac19)"
( printf '%s\n' "$(entry cm1 git git:c1)" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W" ) &
P1=$!
( printf '%s\n' "$(entry cm2 git git:c2)" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W" ) &
P2=$!
wait "$P1"; wait "$P2"
LC="$(grep -c . "$L/entries.jsonl" 2>/dev/null)"
VALID=1
while IFS= read -r line; do
  printf '%s' "$line" | jq -e . >/dev/null 2>&1 || VALID=0
done < "$L/entries.jsonl"
if [ "$LC" = 2 ] && [ "$VALID" = 1 ]; then
  ok "AC-19 concurrent appends line-atomic"
else
  fail "AC-19 concurrent appends (lc=$LC valid=$VALID)"
fi

# --- AC-19: stale-lock recovery ---
L="$(mkl ac19-stale)"
mkdir "$L/.lock"
echo 999999 > "$L/.lock/pid"
START="$(date +%s)"
printf '%s\n' "$(entry cm3 git git:c3)" | TOUCHSTONE_LEDGER_DIR="$L" TOUCHSTONE_LEDGER_LOCK_TIMEOUT=1 bash "$W"
RC=$?
END="$(date +%s)"
ELAPSED=$((END - START))
if [ "$RC" -eq 0 ] && [ -s "$L/entries.jsonl" ] && [ "$ELAPSED" -ge 1 ]; then
  ok "AC-19 stale-lock recovery after timeout"
else
  fail "AC-19 stale-lock recovery (rc=$RC elapsed=$ELAPSED)"
fi

# --- AC-24: symlinked ledger dir refused ---
TARGET="$TMP/ac24-target"; mkdir -p "$TARGET"
SYM="$TMP/ac24-symlink"; ln -s "$TARGET" "$SYM"
printf '%s\n' "$(entry sm git git:sm1)" | TOUCHSTONE_LEDGER_DIR="$SYM" bash "$W" >/dev/null 2>/tmp/ac24err.$$
RC=$?
if [ "$RC" -ne 0 ] && [ ! -s "$TARGET/entries.jsonl" ]; then
  ok "AC-24 symlinked ledger dir refused"
else
  fail "AC-24 symlinked ledger dir (rc=$RC)"
fi
rm -f "/tmp/ac24err.$$"

# --- AC-24: symlinked ledger PARENT refused ---
PARENT_TARGET="$TMP/ac24-parent-target"; mkdir -p "$PARENT_TARGET"
PARENT_LINK="$TMP/ac24-parent-link"; ln -s "$PARENT_TARGET" "$PARENT_LINK"
L2="$PARENT_LINK/ledger"
printf '%s\n' "$(entry sm2 git git:sm2)" | TOUCHSTONE_LEDGER_DIR="$L2" bash "$W" >/dev/null 2>/dev/null
RC2=$?
if [ "$RC2" -ne 0 ] && [ ! -e "$PARENT_TARGET/ledger" ]; then
  ok "AC-24 symlinked ledger parent refused"
else
  fail "AC-24 symlinked ledger parent (rc=$RC2)"
fi

# --- transcript-range overlap dedupe ---
L="$(mkl trov)"
printf '%s\n' "$(entry t1 transcript "transcript:/p#100-200")" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
printf '%s\n' "$(entry t2 transcript "transcript:/p#150-300")" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
LC="$(grep -c . "$L/entries.jsonl")"
if [ "$LC" = 1 ]; then
  ok "transcript-range overlap dedupe (intersecting ranges)"
else
  fail "transcript-range overlap dedupe (lc=$LC)"
fi

# --- bare-ref transcript never overlaps (both land) ---
L="$(mkl barenov)"
printf '%s\n' "$(entry b1 transcript "transcript:/p")" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
printf '%s\n' "$(entry b2 transcript "transcript:/p#10-20")" | TOUCHSTONE_LEDGER_DIR="$L" bash "$W"
LC="$(grep -c . "$L/entries.jsonl")"
if [ "$LC" = 2 ]; then
  ok "bare-ref transcript non-overlap (both land)"
else
  fail "bare-ref transcript non-overlap (lc=$LC)"
fi

# --- --label mode fills schema/id/ts/dedupe_key, forces source=label ---
L="$(mkl label1)"
LBL='{"what":"human caught it","caught_by":"human","should_have":"code-review:per-commit","gap_class":"false-green","evidence":[{"kind":"git","ref":"git:labelsha"}]}'
TOUCHSTONE_LEDGER_DIR="$L" bash "$W" --label "$LBL"
RC=$?
LINE="$(cat "$L/entries.jsonl" 2>/dev/null)"
if [ "$RC" -eq 0 ] \
  && [ "$(printf '%s' "$LINE" | jq -r .source)" = "label" ] \
  && [ "$(printf '%s' "$LINE" | jq -r '(.id!="") and (.ts!="") and (.dedupe_key!="") and (.schema=="catch-miss/v1")')" = "true" ]; then
  ok "--label mode fills schema/id/ts/dedupe_key, forces source=label"
else
  fail "--label mode (rc=$RC line=$LINE)"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
