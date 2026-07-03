#!/usr/bin/env bash
# phase-record.sh suite: row append + [unverified] verbatim + open-entry count.
# Spec join: AC-21 (offline shape; the real-session row is live-bearing and
# stays [unverified: needs live session] until phase ship).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PR="$REPO_ROOT/scripts/metrics/phase-record.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[ -x "$PR" ] && ok "exec bit: phase-record.sh" || fail "exec bit"

# fixture ledger with 3 open entries — deliberately DISTINCT from the 2 canned
# metrics rows so the open-entry column cannot collide with the runs column
L="$TMP/ledger"; mkdir -p "$L"
for i in 1 2 3; do
  jq -nc --arg id "e$i" '{schema:"catch-miss/v1", id:$id, ts:"2026-07-01T00:00:00Z",
    caught_by:"human", should_have:"design-review", gap_class:"missing-AC", what:$id,
    evidence:[{kind:"x",ref:("t:"+$id)}], source:"label"}' >> "$L/entries.jsonl"
done

# canned metrics-report: 2 rows — one fully numeric, one [unverified] cc cell
FAKE="$TMP/fake-report.sh"
cat > "$FAKE" <<'EOS'
#!/usr/bin/env bash
echo '{"run_id":"r1","skill":"design-review","codex":{"model":"m","in":100,"cached_in":0,"out":50,"reasoning":0},"cc_subagent":{"tokens":30,"cost_usd":0.01},"wallclock_s":60,"codex_cost_usd":"0.020000","dispatch_total_cost_usd":"0.030000"}'
echo '{"run_id":"r2","skill":"anvil","codex":{"model":"m","in":10,"cached_in":0,"out":5,"reasoning":0},"cc_subagent":"[unverified: subagent usage requires OTel]","wallclock_s":40,"codex_cost_usd":"0.001000","dispatch_total_cost_usd":"[unverified: subagent usage requires OTel]"}'
EOS
chmod 755 "$FAKE"

E="$TMP/epics"
OUT="$(CLAUDE_SESSION_ID=sess-1 TOUCHSTONE_METRICS_REPORT="$FAKE" \
  TOUCHSTONE_LEDGER_DIR="$L" TOUCHSTONE_EPICS_DIR="$E" \
  bash "$PR" demo phase-2)"
rc=$?
[ "$rc" -eq 0 ] && ok "AC-21 exits 0" || fail "AC-21 rc=$rc"
DP="$E/demo/data-points.md"
[ -f "$DP" ] && ok "AC-21 data-points.md created" || fail "AC-21 file"
head -1 "$DP" | grep -q 'data-points' && ok "AC-21 header written" || fail "AC-21 header"
ROW="$(tail -1 "$DP")"
echo "$ROW" | grep -q '| phase-2 |' && ok "AC-21 phase label in row" || fail "AC-21 label"
echo "$ROW" | grep -q '| 3 | sess-1 |' && ok "AC-21 open-entry count + session" || fail "AC-21 count: $ROW"
echo "$ROW" | grep -qF '[unverified: subagent usage requires OTel]' \
  && ok "AC-21 [unverified] cell verbatim" || fail "AC-21 verbatim: $ROW"
echo "$ROW" | grep -q '| 100 |' && ok "AC-21 wallclock summed (60+40)" || fail "AC-21 wallclock: $ROW"
[ "$OUT" = "$ROW" ] && ok "AC-21 row echoed" || fail "AC-21 echo"

# second run appends (never rewrites)
N1="$(grep -c . "$DP")"
CLAUDE_SESSION_ID=sess-1 TOUCHSTONE_METRICS_REPORT="$FAKE" TOUCHSTONE_LEDGER_DIR="$L" \
  TOUCHSTONE_EPICS_DIR="$E" bash "$PR" demo phase-2b >/dev/null
N2="$(grep -c . "$DP")"
[ "$N2" -eq $((N1 + 1)) ] && ok "append-only (one new row)" || fail "append: $N1 -> $N2"

# zero rows → honest [unverified] cells, exit 0
Z="$TMP/zero.sh"; printf '#!/usr/bin/env bash\nexit 0\n' > "$Z"; chmod 755 "$Z"
OUT="$(CLAUDE_SESSION_ID=sess-1 TOUCHSTONE_METRICS_REPORT="$Z" TOUCHSTONE_LEDGER_DIR="$L" \
  TOUCHSTONE_EPICS_DIR="$E" bash "$PR" demo phase-0)"
rc=$?
[ "$rc" -eq 0 ] && echo "$OUT" | grep -qF '[unverified: no gate runs recorded' \
  && ok "zero runs → [unverified] cells, exit 0" || fail "zero runs: rc=$rc '$OUT'"

# regression: open-entries query failure must degrade honestly, not silently
# read as 0. A malformed entries.jsonl line makes report.sh open-entries
# exit non-zero (verified directly below) — phase-record must still append a
# row (exit 0), with the open-entries cell carrying [unverified: ...].
BAD="$TMP/bad-ledger"; mkdir -p "$BAD"
echo 'not valid json {{{' > "$BAD/entries.jsonl"
TOUCHSTONE_LEDGER_DIR="$BAD" bash "$REPO_ROOT/scripts/proposal/report.sh" open-entries >/dev/null 2>&1 \
  && fail "regression precondition: report.sh open-entries must fail on malformed entries.jsonl" \
  || ok "regression precondition: report.sh open-entries fails on malformed entries.jsonl"
OUT="$(CLAUDE_SESSION_ID=sess-2 TOUCHSTONE_METRICS_REPORT="$FAKE" TOUCHSTONE_LEDGER_DIR="$BAD" \
  TOUCHSTONE_EPICS_DIR="$E" bash "$PR" demo phase-bad)"
rc=$?
[ "$rc" -eq 0 ] && ok "regression: row still appended (exit 0) on open-entries failure" || fail "regression: rc=$rc"
echo "$OUT" | grep -qF '[unverified: open-entries query failed]' \
  && ok "regression: open-entries cell honestly [unverified], not 0" || fail "regression: cell not unverified: $OUT"
echo "$OUT" | grep -q '| 0 |' \
  && fail "regression: open-entries cell silently read as 0" || ok "regression: no silent 0"

# no session id → non-zero
TOUCHSTONE_METRICS_REPORT="$FAKE" TOUCHSTONE_EPICS_DIR="$E" TOUCHSTONE_LEDGER_DIR="$L" \
  env -u CLAUDE_SESSION_ID -u CLAUDE_CODE_SESSION_ID bash "$PR" demo p >/dev/null 2>&1 \
  && fail "missing session id must refuse" || ok "missing session id refused"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
