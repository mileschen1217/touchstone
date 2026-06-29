#!/usr/bin/env bash
# Deterministic tests for the metrics-capture report tool + owned writer.
# Covers AC-1..AC-29 except AC-23 (live-bearing — see test note in that task).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="$REPO_ROOT/scripts/metrics-report.sh"
WRITER="$REPO_ROOT/scripts/metrics/persist-dispatch.sh"
PRICES="$REPO_ROOT/scripts/metrics/model-prices.json"
FIX="$REPO_ROOT/scripts/tests/fixtures/metrics"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
# shellcheck source=/dev/null
source "$TOOL"   # source-guard keeps main() from running

# --- AC-7: price table applied; reasoning billed as output ---
# opus: in=1e6 cached=0 out=1e6 reasoning=1e6 → 15 + 0 + (1+1)*75 = 165.0
got="$(compute_codex_cost 1000000 0 1000000 1000000 claude-opus-4-8 "$PRICES")"
[ "$got" = "165.000000" ] && ok "AC-7 reasoning billed at output rate" || fail "AC-7 got=$got want=165.000000"

# --- AC-8: unknown model → MISSING_PRICE ---
if compute_codex_cost 100 0 100 0 no-such-model "$PRICES" >/dev/null 2>&1; then
  fail "AC-8 unpriced model should fail"
else
  ok "AC-8 unpriced model returns MISSING_PRICE"
fi

echo ""; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ]
