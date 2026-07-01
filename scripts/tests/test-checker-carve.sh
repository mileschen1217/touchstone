#!/usr/bin/env bash
# Verifies the .gitignore carve makes a nested check trackable, and shipped-surface.txt is single-homed.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
cd "$REPO_ROOT"

# carve: a nested check under checker/ is NOT ignored (trackable)
probe=".touchstone/checker/pre-commit/check-probe.sh"
touch "$probe"
if git check-ignore -q "$probe"; then fail "carve: nested check should be trackable"; else ok "carve: nested check trackable"; fi
rm -f "$probe"

# .gitkeep present in both stages
[ -f .touchstone/checker/pre-commit/.gitkeep ] && ok "pre-commit .gitkeep" || fail "pre-commit .gitkeep missing"
[ -f .touchstone/checker/pre-push/.gitkeep ] && ok "pre-push .gitkeep" || fail "pre-push .gitkeep missing"

# shipped-surface.txt exists + lists the known shipped prefixes
ss=".touchstone/shipped-surface.txt"
[ -f "$ss" ] && ok "shipped-surface.txt exists" || fail "shipped-surface.txt missing"
for p in skills/ agents/ commands/ .claude-plugin/ hooks/; do
  grep -qx "$p" "$ss" && ok "shipped-surface lists $p" || fail "shipped-surface missing $p"
done
echo "== test-checker-carve: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
