#!/usr/bin/env bash
# Tests for .touchstone/checker/pre-push/check-review-summary.sh
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

# jq required by the checker; skip schema-parse tests if absent
if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: jq not found — skipping schema-parse tests"
  echo "== test-check-review-summary: $pass ok, $fail fail (jq absent) =="
  exit 0
fi

# ── Helper: run the checker with TOUCHSTONE_CHECK_ROOT pointing at a temp repo ──
run_chk() {
  TOUCHSTONE_CHECK_ROOT="$1" bash "$CHK" 2>&1
  return $?
}

# ── (b) Absence passthrough: no review.result.json → exit 0 ──────────────────
R="$TMP/repo-absent"; mkdir -p "$R/.touchstone/research"
( cd "$R" && git init -q )
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(b) no review.result.json → 0 (passthrough)" || fail "(b) absent rc=$rc out=$out"

# ── (c) ch_tally_final critical=1 → BLOCK (exit non-zero) ────────────────────
R="$TMP/repo-crit"; mkdir -p "$R/.touchstone/research/fixture-review"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-review/review.result.json" <<'EOF'
{
  "schema": "review-envelope/v1",
  "status": "ok",
  "ch_tally_final": { "critical": 1, "high": 0, "medium": 0, "low": 0 }
}
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "critical=1"; } && ok "(c) critical=1 → nonzero + message" || fail "(c) critical=1 rc=$rc out=$out"

# ── (d) ch_tally_final high=1 → BLOCK ────────────────────────────────────────
R="$TMP/repo-high"; mkdir -p "$R/.touchstone/research/fixture-review"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-review/review.result.json" <<'EOF'
{
  "schema": "review-envelope/v1",
  "status": "ok",
  "ch_tally_final": { "critical": 0, "high": 1, "medium": 0, "low": 0 }
}
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "high=1"; } && ok "(d) high=1 → nonzero + message" || fail "(d) high=1 rc=$rc out=$out"

# ── (e) ch_tally_final critical=0, high=0 → exit 0 (clean) ──────────────────
R="$TMP/repo-clean"; mkdir -p "$R/.touchstone/research/fixture-review"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-review/review.result.json" <<'EOF'
{
  "schema": "review-envelope/v1",
  "status": "ok",
  "ch_tally_final": { "critical": 0, "high": 0, "medium": 2, "low": 1 }
}
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(e) C=0+H=0 → 0 (clean)" || fail "(e) clean rc=$rc out=$out"

# ── (f) findings[] array schema critical → BLOCK ─────────────────────────────
R="$TMP/repo-arr"; mkdir -p "$R/.touchstone/research/fixture-review"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-review/review.result.json" <<'EOF'
{
  "schema": "review-envelope/v1",
  "status": "ok",
  "findings": [
    { "severity": "Critical", "description": "bad thing" },
    { "severity": "Medium",   "description": "medium thing" }
  ]
}
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "critical=1"; } && ok "(f) findings[] Critical → nonzero" || fail "(f) findings[] rc=$rc out=$out"

# ── (g) review.result.json/v1 object schema high → BLOCK ─────────────────────
R="$TMP/repo-obj"; mkdir -p "$R/.touchstone/research/fixture-review"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-review/review.result.json" <<'EOF'
{
  "schema": "review.result.json/v1",
  "status": "completed",
  "findings": {
    "critical": [],
    "high": [
      { "location": "foo.sh:1", "description": "bad high finding" }
    ]
  }
}
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "high=1"; } && ok "(g) findings{} high → nonzero" || fail "(g) findings{} rc=$rc out=$out"

# ── (h) Most-recent file is picked (two files, different mtimes) ──────────────
R="$TMP/repo-mtime"; mkdir -p "$R/.touchstone/research/old" "$R/.touchstone/research/new"
( cd "$R" && git init -q )
# old file: critical=1 (should be ignored as not most-recent)
cat > "$R/.touchstone/research/old/review.result.json" <<'EOF'
{"schema":"review-envelope/v1","ch_tally_final":{"critical":1,"high":0}}
EOF
sleep 1
# new file: clean (critical=0, high=0)
cat > "$R/.touchstone/research/new/review.result.json" <<'EOF'
{"schema":"review-envelope/v1","ch_tally_final":{"critical":0,"high":0}}
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(h) most-recent clean file wins → 0" || fail "(h) mtime-pick rc=$rc out=$out"

# ── (i) Attempt 4: review.md sentinel critical=1 high=0 → BLOCK ──────────────
# JSON has no ch_tally_final and no findings → falls through to Attempt 4.
R="$TMP/repo-sent-crit"; mkdir -p "$R/.touchstone/research/fixture-sent"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-sent/review.result.json" <<'EOF'
{"schema":"review-sentinel/v1","status":"ok"}
EOF
cat > "$R/.touchstone/research/fixture-sent/review.md" <<'EOF'
## Batch Review

STAGE-REVIEW-SUMMARY: critical=1 high=0

Some findings here.
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "critical=1"; } && ok "(i) Attempt4 sentinel critical=1 → nonzero+message" || fail "(i) Attempt4 sentinel crit=1 rc=$rc out=$out"

# ── (j) Attempt 4: review.md sentinel critical=0 high=0 → exit 0 (clean) ─────
R="$TMP/repo-sent-clean"; mkdir -p "$R/.touchstone/research/fixture-sent-ok"
( cd "$R" && git init -q )
cat > "$R/.touchstone/research/fixture-sent-ok/review.result.json" <<'EOF'
{"schema":"review-sentinel/v1","status":"ok"}
EOF
cat > "$R/.touchstone/research/fixture-sent-ok/review.md" <<'EOF'
## Batch Review

STAGE-REVIEW-SUMMARY: critical=0 high=0

All clear.
EOF
out="$(run_chk "$R" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(j) Attempt4 sentinel critical=0 high=0 → 0 (clean)" || fail "(j) Attempt4 sentinel clean rc=$rc out=$out"

echo "== test-check-review-summary: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
