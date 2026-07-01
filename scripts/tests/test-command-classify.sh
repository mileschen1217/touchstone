#!/usr/bin/env bash
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIX="$REPO_ROOT/scripts/tests/fixtures/checker/command-forms.txt"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
# shellcheck source=/dev/null
source "$REPO_ROOT/hooks/run-project-checks.sh"   # source-guard keeps main() dormant

# AC-14/15/16/17: every fixture form classifies to its expected bucket
while IFS=$'\t' read -r want cmd; do
  case "$want" in ''|\#*) continue ;; esac
  got="$(classify_command "$cmd")"
  [ "$got" = "$want" ] && ok "classify [$cmd] → $got" || fail "classify [$cmd] want=$want got=$got"
done < "$FIX"

# AC-18 meta: fixture carries the audited-against header
grep -qE '^# audited-against: .+ [0-9]{4}-[0-9]{2}-[0-9]{2}$' "$FIX" \
  && ok "AC-18 fixture audited-against header present" || fail "AC-18 header missing"

echo "== test-command-classify: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
