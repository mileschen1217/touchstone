#!/usr/bin/env bash
# test-check-witness-lines.sh — red/green harness for check-witness-lines.sh (P2 AC-14).
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
checker="$here/../check-witness-lines.sh"
fix="$here/witness-fixtures"
rc=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; rc=1; }

# GREEN cases → exit 0
for g in green-read-run green-read-only; do
  if bash "$checker" "$fix/$g.txt" >/dev/null 2>&1; then pass "$g accepted"; else fail "$g should pass"; fi
done

# RED cases → exit 1
for r in red-none red-run-no-read red-malformed-read; do
  if bash "$checker" "$fix/$r.txt" >/dev/null 2>&1; then fail "$r should be rejected"; else pass "$r rejected"; fi
done

# operational error → exit 2
bash "$checker" "$fix/does-not-exist.txt" >/dev/null 2>&1; [ $? -eq 2 ] && pass "missing file → exit 2" || fail "missing file should exit 2"

exit "$rc"
