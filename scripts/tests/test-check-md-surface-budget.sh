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

# --- per-file line lint (200 warn / 500 fail, no exemption) ---

# file >200 lines but <=500 → WARN line naming the file, still exit 0
seq 1 201 | sed 's/^/l/' > "$TMP/skills/demo/long.md"
printf '# synthetic fixture baseline\n999999\n' > "$TMP/base-big.txt"
out="$(MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/base-big.txt" bash "$CHK" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'WARN.*long\.md.*201'; } \
  && ok "201-line file → WARN + exit 0" || fail "warn-side rc=$rc out=$out"

# file >500 lines → FAIL naming the file, exit 1 even when total under baseline
seq 1 501 | sed 's/^/l/' > "$TMP/skills/demo/huge.md"
out="$(MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/base-big.txt" bash "$CHK" 2>&1)"; rc=$?
{ [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'FAIL.*huge\.md.*501'; } \
  && ok "501-line file → FAIL + exit 1" || fail "fail-side rc=$rc out=$out"
rm -f "$TMP/skills/demo/long.md" "$TMP/skills/demo/huge.md"

# boundary-exact: exactly 200 → no WARN; exactly 500 → WARN (it exceeds 200) but no FAIL
seq 1 200 | sed 's/^/l/' > "$TMP/skills/demo/at200.md"
seq 1 500 | sed 's/^/l/' > "$TMP/skills/demo/at500.md"
out="$(MD_BUDGET_ROOT="$TMP" MD_BUDGET_BASELINE="$TMP/base-big.txt" bash "$CHK" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] \
  && ! printf '%s' "$out" | grep -q 'at200\.md' \
  && printf '%s' "$out" | grep -q 'WARN.*at500\.md' \
  && ! printf '%s' "$out" | grep -q 'FAIL'; } \
  && ok "boundary: 200 clean, 500 warns but never fails" || fail "boundary rc=$rc out=$out"
rm -f "$TMP/skills/demo/at200.md" "$TMP/skills/demo/at500.md"

# live wiring: the real repo surface must be within its committed baseline
bash "$CHK" >/dev/null 2>&1 \
  && ok "real repo surface within committed baseline" || fail "real repo over budget"

echo "== test-check-md-surface-budget: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
