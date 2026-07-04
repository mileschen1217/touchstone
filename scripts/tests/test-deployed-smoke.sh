#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# SC2016: printf patterns embed literal ${CLAUDE_PLUGIN_ROOT} (no expansion wanted).
# shellcheck disable=SC2015,SC2016
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SMOKE="$REPO_ROOT/scripts/deployed-smoke.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

FAKE_VER="0.99.0"
FAKE_CACHE_ROOT="$TMP/cache"
FAKE_CACHE="$FAKE_CACHE_ROOT/$FAKE_VER"

# Minimal fake repo root: 2 skills, plugin.json, one CLAUDE_PLUGIN_ROOT ref
FAKE_REPO="$TMP/repo"
setup_fake_repo() {
  mkdir -p "$FAKE_REPO/.claude-plugin"
  printf '{"version":"%s"}\n' "$FAKE_VER" > "$FAKE_REPO/.claude-plugin/plugin.json"
  mkdir -p "$FAKE_REPO/skills/anvil"
  # one CLAUDE_PLUGIN_ROOT path reference (scripts/spec-extract.sh)
  printf '# Anvil\nbash "${CLAUDE_PLUGIN_ROOT}/scripts/spec-extract.sh"\n' \
    > "$FAKE_REPO/skills/anvil/SKILL.md"
}

# Minimal fake cache: matches the fake repo exactly (2 skills, the referenced file)
make_clean_cache() {
  rm -rf "$FAKE_CACHE"
  mkdir -p "$FAKE_CACHE/hooks"
  mkdir -p "$FAKE_CACHE/scripts"
  mkdir -p "$FAKE_CACHE/skills/anvil"
  mkdir -p "$FAKE_CACHE/skills/keystone"
  printf '# Anvil\n' > "$FAKE_CACHE/skills/anvil/SKILL.md"
  printf '# Keystone\n' > "$FAKE_CACHE/skills/keystone/SKILL.md"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$FAKE_CACHE/scripts/spec-extract.sh"
  chmod +x "$FAKE_CACHE/scripts/spec-extract.sh"
}

run_smoke() {
  # use --version to avoid reading the real plugin.json; point at fake repo and cache
  SMOKE_REPO_ROOT="$FAKE_REPO" CACHE_ROOT="$FAKE_CACHE_ROOT" \
    bash "$SMOKE" --version "$FAKE_VER" 2>&1
}

setup_fake_repo

# --- PASS: clean cache all 4 checks pass ---
make_clean_cache
out="$(run_smoke)"; rc=$?
[ "$rc" -eq 0 ] \
  && ok "(pass) clean cache exits 0" \
  || fail "(pass) clean cache exited $rc; output: $out"
echo "$out" | grep -q "PASS=4" \
  && ok "(pass) all 4 checks pass" \
  || fail "(pass) expected PASS=4 FAIL=0; got: $out"

# --- FAIL: version not deployed ---
out="$(SMOKE_REPO_ROOT="$FAKE_REPO" CACHE_ROOT="$FAKE_CACHE_ROOT" \
  bash "$SMOKE" --version "0.0.0-notexist" 2>&1)"; rc=$?
[ "$rc" -ne 0 ] \
  && ok "(missing-ver) exits non-zero when version not deployed" \
  || fail "(missing-ver) should exit non-zero"
echo "$out" | grep -q "not deployed" \
  && ok "(missing-ver) output says 'not deployed'" \
  || fail "(missing-ver) no 'not deployed' message: $out"

# --- FAIL: check 1 — missing hooks/ ---
make_clean_cache
rm -rf "$FAKE_CACHE/hooks"
out="$(run_smoke)"; rc=$?
[ "$rc" -ne 0 ] \
  && ok "(no-hooks) exits non-zero when hooks/ missing" \
  || fail "(no-hooks) should exit non-zero but got rc=0: $out"
echo "$out" | grep -q "FAIL (1-key-files)" \
  && ok "(no-hooks) check 1 reported as FAIL" \
  || fail "(no-hooks) check 1 not reported FAIL: $out"

# --- FAIL: check 2 — missing exec bit ---
make_clean_cache
chmod -x "$FAKE_CACHE/scripts/spec-extract.sh"
out="$(run_smoke)"; rc=$?
[ "$rc" -ne 0 ] \
  && ok "(no-exec) exits non-zero when script lacks exec bit" \
  || fail "(no-exec) should exit non-zero: $out"
echo "$out" | grep -q "FAIL (2-exec-bits)" \
  && ok "(no-exec) check 2 reported as FAIL" \
  || fail "(no-exec) check 2 not reported FAIL: $out"

# --- PASS: check 2 — no-shebang source-only lib without exec bit is exempt ---
make_clean_cache
printf '# shellcheck shell=bash\nfoo() { :; }\n' > "$FAKE_CACHE/scripts/proposal-lib.sh"
chmod -x "$FAKE_CACHE/scripts/proposal-lib.sh"
out="$(run_smoke)"; rc=$?
[ "$rc" -eq 0 ] \
  && ok "(lib-exempt) exits 0 when only a no-shebang lib lacks exec bit" \
  || fail "(lib-exempt) should exit 0: $out"
echo "$out" | grep -q "PASS (2-exec-bits)" \
  && ok "(lib-exempt) check 2 reported as PASS" \
  || fail "(lib-exempt) check 2 not reported PASS: $out"

# --- PASS: check 3 — bare-path lint clean ---
make_clean_cache
out="$(run_smoke)"
echo "$out" | grep -q "PASS (3-bare-path-lint)" \
  && ok "(bare-clean) check 3 PASS when no bare paths" \
  || fail "(bare-clean) check 3 unexpected result: $out"

# --- FAIL: check 3 — bare path in cache skill ---
make_clean_cache
printf '# Bad\nbash scripts/capture.sh\n' > "$FAKE_CACHE/skills/anvil/SKILL.md"
out="$(run_smoke)"; rc=$?
[ "$rc" -ne 0 ] \
  && ok "(bare-path) exits non-zero when bare path in cache skill" \
  || fail "(bare-path) should exit non-zero: $out"
echo "$out" | grep -q "FAIL (3-bare-path-lint)" \
  && ok "(bare-path) check 3 reported as FAIL" \
  || fail "(bare-path) check 3 not reported FAIL: $out"

# --- FAIL: check 4 — CLAUDE_PLUGIN_ROOT ref missing from cache ---
make_clean_cache
rm "$FAKE_CACHE/scripts/spec-extract.sh"
out="$(run_smoke)"; rc=$?
[ "$rc" -ne 0 ] \
  && ok "(missing-ref) exits non-zero when referenced path absent" \
  || fail "(missing-ref) should exit non-zero: $out"
echo "$out" | grep -q "FAIL (4-plugin-root-refs)" \
  && ok "(missing-ref) check 4 reported as FAIL" \
  || fail "(missing-ref) check 4 not reported FAIL: $out"

echo ""
echo "PASS=$pass FAIL=$fail"
[ "$fail" -eq 0 ]
