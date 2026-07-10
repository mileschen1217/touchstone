#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
# Tests for .touchstone/checker/pre-push/check-review-summary.sh
# Single count schema: the co-located review.md STAGE-REVIEW-SUMMARY sentinel.
# Fixtures use synthetic slugs and mktemp — no real epic state touched.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/.touchstone/checker/pre-push/check-review-summary.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# (a) script exists and is executable
[ -f "$CHK" ] && ok "(a) script exists" || fail "(a) script not found: $CHK"
[ -x "$CHK" ] && ok "(a) script is executable" || fail "(a) script not executable (check git index mode)"

# ── Helper: run the checker with TOUCHSTONE_CHECK_ROOT pointing at a temp repo ──
run_chk() {
  TOUCHSTONE_CHECK_ROOT="$1" bash "$CHK" 2>&1
  return $?
}

# write_review <dir> <sentinel-line-or-empty>
write_review() {
  local d="$1" sline="$2"
  mkdir -p "$d"
  printf '{"schema":"review-envelope/v1","status":"ok"}\n' > "$d/review.result.json"
  { echo "## Batch Review"; echo; [ -n "$sline" ] && echo "$sline"; echo; echo "body"; } > "$d/review.md"
}

# ── (b) Absence passthrough: no review.result.json → exit 0 ──────────────────
R="$TMP/repo-absent"; mkdir -p "$R/.touchstone/research"
( cd "$R" && git init -q )
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(b) no review.result.json → 0 (passthrough)" || fail "(b) absent rc=$rc out=$out"

# ── (c) sentinel critical=1 → BLOCK (exit non-zero) ──────────────────────────
R="$TMP/repo-crit"; ( mkdir -p "$R" && cd "$R" && git init -q )
write_review "$R/.touchstone/research/fixture-review" "STAGE-REVIEW-SUMMARY: critical=1 high=0"
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "critical=1"; } && ok "(c) critical=1 → nonzero + message" || fail "(c) critical=1 rc=$rc out=$out"

# ── (d) sentinel high=1 → BLOCK ───────────────────────────────────────────────
R="$TMP/repo-high"; ( mkdir -p "$R" && cd "$R" && git init -q )
write_review "$R/.touchstone/research/fixture-review" "STAGE-REVIEW-SUMMARY: critical=0 high=1"
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "high=1"; } && ok "(d) high=1 → nonzero + message" || fail "(d) high=1 rc=$rc out=$out"

# ── (e) sentinel critical=0 high=0 → exit 0 (clean) ──────────────────────────
R="$TMP/repo-clean"; ( mkdir -p "$R" && cd "$R" && git init -q )
write_review "$R/.touchstone/research/fixture-review" "STAGE-REVIEW-SUMMARY: critical=0 high=0"
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(e) C=0+H=0 → 0 (clean)" || fail "(e) clean rc=$rc out=$out"

# ── (f) counts undeterminable (no review.md sentinel) → passthrough ──────────
R="$TMP/repo-nosent"; ( mkdir -p "$R" && cd "$R" && git init -q )
write_review "$R/.touchstone/research/fixture-review" ""
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(f) no sentinel → 0 (passthrough, never false-block)" || fail "(f) no-sentinel rc=$rc out=$out"

# ── (g) legacy count-bearing JSON (ch_tally_final) alone no longer blocks ─────
# Retired generations: counts now come ONLY from the review.md sentinel.
R="$TMP/repo-legacy"; mkdir -p "$R/.touchstone/research/fixture-review"
( cd "$R" && git init -q )
printf '{"schema":"review-envelope/v1","status":"ok","ch_tally_final":{"critical":9,"high":9}}\n' \
  > "$R/.touchstone/research/fixture-review/review.result.json"
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(g) legacy ch_tally_final ignored → 0 (single-schema convergence)" || fail "(g) legacy rc=$rc out=$out"

# ── (h) Most-recent file is picked (two files, different mtimes) ──────────────
R="$TMP/repo-mtime"; ( mkdir -p "$R" && cd "$R" && git init -q )
write_review "$R/.touchstone/research/old" "STAGE-REVIEW-SUMMARY: critical=1 high=0"
sleep 1
write_review "$R/.touchstone/research/new" "STAGE-REVIEW-SUMMARY: critical=0 high=0"
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(h) most-recent clean file wins → 0" || fail "(h) mtime-pick rc=$rc out=$out"

echo "== test-check-review-summary: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
