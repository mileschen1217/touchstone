#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/.touchstone/checker/pre-commit/check-bare-plugin-paths.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Helper: create a minimal fake repo with skills/ dir (checker scans skills/)
new_repo() {
  local d; d="$(mktemp -d "$TMP/repo-XXXXXX")"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t \
      && mkdir -p skills/demo )
  printf '%s' "$d"
}

# --- (a) checker exists and is executable ---
[ -f "$CHK" ] && ok "(a) checker file exists" || fail "(a) checker file missing: $CHK"
[ -x "$CHK" ] && ok "(a) checker is executable" || fail "(a) checker is not executable"

# --- (b) current live tree exits 0 ---
out="$(TOUCHSTONE_CHECK_ROOT="$REPO_ROOT" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(b) live tree exits 0" || fail "(b) live tree nonzero (rc=$rc); output: $out"

# --- (c) detection: bash scripts/foo.sh (bare path) is flagged ---
R="$(new_repo)"
cat > "$R/skills/demo/SKILL.md" <<'EOF'
# Demo skill
Run the helper:
bash scripts/capture.sh
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "(c) bare 'bash scripts/' flagged (nonzero)" \
  || fail "(c) bare 'bash scripts/' not flagged (rc=$rc)"
printf '%s' "$out" | grep -q 'SKILL.md' && ok "(c) output names the file" \
  || fail "(c) output missing filename; out=$out"

# --- (c2) detection: Read backtick bare path is flagged ---
R2="$(new_repo)"
cat > "$R2/skills/demo/SKILL.md" <<'EOF'
# Demo skill
Read `skills/_shared/config-resolver.md`
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R2" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && ok "(c2) bare 'Read \`skills/...\`' flagged" \
  || fail "(c2) bare Read not flagged (rc=$rc)"

# --- (d) exemption: same-line <!-- bare-path-ok --> suppresses the finding ---
R3="$(new_repo)"
cat > "$R3/skills/demo/SKILL.md" <<'EOF'
# Demo skill
bash scripts/capture.sh <!-- bare-path-ok -->
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R3" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(d) same-line exemption → exit 0" \
  || fail "(d) same-line exemption not respected (rc=$rc); out=$out"

# --- (d2) exemption: preceding-line <!-- bare-path-ok --> suppresses the finding ---
R4="$(new_repo)"
cat > "$R4/skills/demo/SKILL.md" <<'EOF'
# Demo skill
<!-- bare-path-ok -->
bash scripts/capture.sh
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R4" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(d2) preceding-line exemption → exit 0" \
  || fail "(d2) preceding-line exemption not respected (rc=$rc); out=$out"

# --- (e) prose attribution is NOT flagged ---
R5="$(new_repo)"
cat > "$R5/skills/demo/SKILL.md" <<'EOF'
# Demo skill
Per `skills/_shared/inject/bridge-content-gate.md`, the rule is...
See `scripts/check-shipped-refs.sh` for the implementation.
Defined in `skills/fixture/SKILL.md`.
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R5" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(e) prose attribution → exit 0 (no false positive)" \
  || fail "(e) prose flagged as bare path (false positive); rc=$rc out=$out"

# --- (e2) prefixed paths are NOT flagged ---
R6="$(new_repo)"
cat > "$R6/skills/demo/SKILL.md" <<'EOF'
# Demo skill
bash "${CLAUDE_PLUGIN_ROOT}/scripts/capture.sh"
Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R6" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(e2) CLAUDE_PLUGIN_ROOT-prefixed paths → exit 0" \
  || fail "(e2) prefixed path flagged as bare (false positive); rc=$rc out=$out"

# --- (f) word-boundary: dry-run scripts/foo.sh is NOT flagged (false-positive guard) ---
R7="$(new_repo)"
cat > "$R7/skills/demo/SKILL.md" <<'EOF'
# Demo skill
dry-run scripts/foo.sh
re-run skills/bar.sh
EOF
out="$(TOUCHSTONE_CHECK_ROOT="$R7" bash "$CHK" 2>&1)"; rc=$?
[ "$rc" -eq 0 ] && ok "(f) dry-run/re-run prefix → exit 0 (no false positive)" \
  || fail "(f) dry-run/re-run falsely flagged (rc=$rc); out=$out"

echo "== test-check-bare-plugin-paths: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
