#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/scripts/check-md-surface-budget.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/skills/demo" "$TMP/agents"
printf 'alpha\n' > "$TMP/skills/demo/SKILL.md"        # 6 bytes
printf 'beta\n'  > "$TMP/agents/demo.md"              # 5 bytes
printf 'not counted\n' > "$TMP/skills/demo/run.sh"    # non-md: out of scope
printf '# synthetic fixture baseline\n11\n' > "$TMP/base.txt"

# exactly at baseline (11 bytes, non-md excluded) → exit 0
MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/base.txt" bash "$CHK" >/dev/null 2>&1 \
  && ok "at-baseline passes; non-md excluded" || fail "at-baseline should pass"

# synthetic growth → ratchet bites: exit 1 with FAIL line
printf 'growth\n' >> "$TMP/skills/demo/SKILL.md"
out="$(MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/base.txt" bash "$CHK" 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^FAIL'; } \
  && ok "synthetic growth FAILs (rc=1)" || fail "growth rc=$rc out=$out"

# deletion funds the addition back under baseline → exit 0
printf 'ab\n' > "$TMP/skills/demo/SKILL.md"
MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/base.txt" bash "$CHK" >/dev/null 2>&1 \
  && ok "deletion-funded surface passes again" || fail "post-deletion should pass"

# missing baseline file → operational error rc=2 (fail-closed, not silent pass)
rc=0; MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/nope.txt" bash "$CHK" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok "missing baseline → rc=2" || fail "missing baseline rc=$rc"

# baseline file with no numeric line → operational error rc=2
printf '# comment only\n' > "$TMP/empty.txt"
rc=0; MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/empty.txt" bash "$CHK" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && ok "non-numeric baseline → rc=2" || fail "non-numeric baseline rc=$rc"

# live wiring: the real repo surface must be within its committed baseline
bash "$CHK" >/dev/null 2>&1 \
  && ok "real repo surface within committed baseline" || fail "real repo over budget"

echo "== test-check-md-surface-budget: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
