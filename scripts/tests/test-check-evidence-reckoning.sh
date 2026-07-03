#!/usr/bin/env bash
# Tests for scripts/check-evidence-reckoning.sh
# Fixtures use synthetic slugs (demo/fixture) — no real epic slugs.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/scripts/check-evidence-reckoning.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# (a) script exists and is executable
[ -f "$CHK" ] && ok "(a) script exists" || fail "(a) script not found: $CHK"
[ -x "$CHK" ] && ok "(a) script is executable" || fail "(a) script not executable (check git index mode)"

# ── Synthetic spec fixture (AC-1, AC-2, AC-3 in index table) ─────────────────
SPEC="$TMP/demo-spec.md"
cat > "$SPEC" <<'SPEC_EOF'
---
status: accepted
---
## Acceptance Criteria

| AC | Description |
|----|-------------|
| AC-1 | First AC |
| AC-2 | Second AC |
| AC-3 | Third AC |

### AC-1
When: foo
Then: bar

### AC-2
When: baz
Then: qux

### AC-3
When: a
Then: b
SPEC_EOF

# ── Helper: build a minimal epic index with a given Evidence Reckoning block ──
make_index() {
  local path="$1" reckoning_block="$2"
  cat > "$path" <<EOF
---
slug: demo
status: done
started: 2026-01-01
landed: 2026-06-01
---
## Phases
| # | Phase | Status | Landed |
|---|-------|--------|--------|
| 1 | Build | done   | 2026-06-01 |

## Retrospective
- Worked well.

$reckoning_block
EOF
}

TABLE_HEADER='## Evidence Reckoning

| AC | Covered by | [unverified: reason] | live-bearing? | waiver | Issue |
|----|------------|----------------------|---------------|--------|-------|'

# ── (b) Happy path: all ACs reckoned, non-live with coverage → exit 0 ─────────
IDX="$TMP/demo-happy/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | test scripts/tests/foo.sh:42 |  | no |  |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q "pass"; } && ok "(b) happy path → 0 + pass" || fail "(b) happy path rc=$rc out=$out"

# ── (c) R1: non-live-bearing row with no covered-by/unverified/waiver → BLOCK ─
IDX="$TMP/demo-r1/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | test scripts/tests/foo.sh:42 |  | no |  |  |
| AC-2 |  |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "AC-2"; } && ok "(c) R1 no-covered-by → nonzero+AC-2" || fail "(c) R1 rc=$rc out=$out"

# ── (d) R3: live-bearing row with empty Covered-by → BLOCK ───────────────────
IDX="$TMP/demo-r3a/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 |  |  | yes |  |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "AC-1"; } && ok "(d) R3 live-bearing no-cov → nonzero+AC-1" || fail "(d) R3 rc=$rc out=$out"

# ── (e) R3: live-bearing row with [unverified] → BLOCK ───────────────────────
IDX="$TMP/demo-r3b/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | live artifact .touchstone/epics/demo/evidence/e.md @ abc123 via otelcol | [unverified: not run] | yes |  |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "AC-1"; } && ok "(e) R3 live-bearing [unverified] → nonzero+AC-1" || fail "(e) R3b rc=$rc out=$out"

# ── (f) R4: [unverified] row with empty Issue → BLOCK ────────────────────────
IDX="$TMP/demo-r4/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | test scripts/tests/foo.sh:42 | [unverified: ran out of time] | no |  |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "AC-1"; } && ok "(f) R4 [unverified]+empty-Issue → nonzero+AC-1" || fail "(f) R4 rc=$rc out=$out"

# ── (g) R5: AC in spec not in reckoning table → BLOCK ────────────────────────
IDX="$TMP/demo-r5/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | test scripts/tests/foo.sh:42 |  | no |  |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |"
# AC-3 is in the spec but missing from the reckoning table
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "AC-3"; } && ok "(g) R5 un-reckoned AC → nonzero+AC-3" || fail "(g) R5 rc=$rc out=$out"

# ── (h) Missing Evidence Reckoning section entirely → BLOCK ──────────────────
IDX="$TMP/demo-noreck/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" ""
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "BLOCK"; } && ok "(h) no reckoning section → BLOCK" || fail "(h) no-reck rc=$rc out=$out"

# ── (j) R2: live-bearing row with doc-grep Covered-by → BLOCK ────────────────
IDX="$TMP/demo-r2/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | doc-grep only |  | yes |  |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "R2\|static.proxy\|static proxy\|live-bearing row Covered-by\|doc-grep"; } && ok "(j) R2 live-bearing doc-grep cov → nonzero+R2-msg" || fail "(j) R2 rc=$rc out=$out"

# ── (i) R4 with waiver set but Issue empty → BLOCK ───────────────────────────
IDX="$TMP/demo-r4wav/index.md"; mkdir -p "$(dirname "$IDX")"
make_index "$IDX" "$TABLE_HEADER
| AC-1 | test scripts/tests/foo.sh:42 |  | no | deferred-phase2 |  |
| AC-2 | test scripts/tests/bar.sh:10 |  | no |  |  |
| AC-3 | test scripts/tests/baz.sh:5  |  | no |  |  |"
out="$(bash "$CHK" "$IDX" "$SPEC" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q "AC-1"; } && ok "(i) R4 waiver+empty-Issue → nonzero+AC-1" || fail "(i) R4-waiver rc=$rc out=$out"

echo "== test-check-evidence-reckoning: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
