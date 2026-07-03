#!/usr/bin/env bash
# Sweep raw-bundle retention + freshness stamp. Spec join: AC-24.
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SW="$REPO_ROOT/scripts/ledger/sweep-run.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
L="$TMP/repo/.touchstone/ledger"; mkdir -p "$L"; git -C "$TMP/repo" init -q

# hand-build a staged run: a valid catch-miss line in .staging.jsonl + a
# candidates log + a cursor proposal file (finalize consumes these).
jq -nc '{schema:"catch-miss/v1", what:"w", caught_by:"human", should_have:"design-review",
  gap_class:"missing-AC", evidence:[{kind:"x", ref:"git:abc1234"}], source:"sweep:git"}' \
  > "$L/.staging.jsonl"
echo '{"schema":"candidate/v1","ref":"git:abc1234","is_miss":true,"caught_by":"human","should_have":"design-review","gap_class":"missing-AC"}' \
  > "$L/.candidates-log.jsonl"
echo '{"cursor":"abc1234"}' > "$L/.propose-git.json"
: > "$L/.sweep-incomplete"

TOUCHSTONE_LEDGER_DIR="$L" bash "$SW" finalize >/dev/null 2>&1 \
  && ok "successful finalize exits 0" || fail "finalize rc"
RUN_DIR="$(find "$L/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
[ -n "$RUN_DIR" ] && ok "runs/<ts>/ created" || fail "runs dir missing"
[ -s "$RUN_DIR/staging.jsonl" ]        && ok "staging.jsonl retained"      || fail "staging.jsonl"
[ -s "$RUN_DIR/candidates-log.jsonl" ] && ok "candidates log retained"     || fail "candidates log"
[ -s "$RUN_DIR/summary.json" ]         && ok "summary written"             || fail "summary"
[ "$(jq -r '.appended' "$RUN_DIR/summary.json")" = 1 ] \
  && ok "summary counts appended entries" || fail "summary.appended"
jq -e '.cursor_movements.git' "$RUN_DIR/summary.json" >/dev/null \
  && ok "summary carries cursor movements" || fail "summary.cursors"
find "$RUN_DIR" -name 'chunk-*' | grep -q . && fail "L1 chunks leaked into bundle" || ok "L1 input chunks excluded"
[ -s "$L/.last-finalize" ] && ok ".last-finalize stamped" || fail "stamp missing"
STAMP1="$(cat "$L/.last-finalize")"

# failed finalize (invalid staging): nothing new archived, stamp unchanged
sleep 1
echo '{"schema":"bogus"}' > "$L/.staging.jsonl"
TOUCHSTONE_LEDGER_DIR="$L" bash "$SW" finalize >/dev/null 2>&1 \
  && fail "invalid staging must fail finalize" || ok "failed finalize exits non-zero"
N_RUNS="$(find "$L/runs" -mindepth 1 -maxdepth 1 -type d | grep -c .)"
[ "$N_RUNS" -eq 1 ] && ok "failed finalize archives nothing new" || fail "runs count=$N_RUNS"
[ "$(cat "$L/.last-finalize")" = "$STAMP1" ] && ok "failed finalize leaves stamp unchanged" || fail "stamp changed"

# report prints the runs/ size line
OUT="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$SW" report)"
echo "$OUT" | grep -q '^runs/: ' && ok "report prints runs/ size" || fail "report runs/ line: $OUT"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
