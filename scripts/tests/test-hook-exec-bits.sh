#!/usr/bin/env bash
# Regression: CC executes a plugin hook command directly (/bin/sh <path>), so every
# script hooks/hooks.json references MUST carry the exec bit IN GIT — the deployed
# plugin is a clone, so a 100644 mode ships a hook that dies "Permission denied" at
# fire time. Offline suites invoke handlers via `bash <path>` and stay green, which
# is exactly how this gap shipped (run-project-checks.sh, caught by the AC-13 live
# probe). The mode must be asserted from the git index, not the working tree.
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# SC2016: the ${CLAUDE_PLUGIN_ROOT} in the sed pattern is a literal, not an expansion.
# shellcheck disable=SC2015,SC2016
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }

refs="$(jq -r '.. | .command? // empty' "$REPO_ROOT/hooks/hooks.json" \
  | awk '{print $1}' | sed 's|^"||; s|"$||; s|^\${CLAUDE_PLUGIN_ROOT}/||' | sort -u)"

[ -n "$refs" ] && ok "hooks.json references at least one command" \
  || fail "no commands parsed from hooks.json (parser broken?)"

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  if [ ! -f "$REPO_ROOT/$rel" ]; then
    fail "$rel referenced by hooks.json but missing from tree"
    continue
  fi
  mode="$(cd "$REPO_ROOT" && git ls-files -s "$rel" | awk '{print $1}')"
  [ "$mode" = "100755" ] && ok "$rel is 100755 in git" \
    || fail "$rel git mode is '${mode:-untracked}', must be 100755 (git update-index --chmod=+x $rel)"
done <<< "$refs"

echo "== test-hook-exec-bits: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
