#!/usr/bin/env bash
# Fixture-driven tests for check-shipped-refs.sh. Each case builds a throwaway
# git repo (the guard judges git tracked-state, so it must run in a real repo),
# populates docs/ or skills/, runs the guard with cwd at the temp repo, asserts
# exit code + reported output.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GUARD="$REPO_ROOT/scripts/check-shipped-refs.sh"
FIX="$REPO_ROOT/scripts/tests/shipped-ref-fixtures"
pass=0 fail=0

# new_repo: prints the path to a fresh temp git repo with docs/ + skills/ dirs
new_repo() {
  local d; d="$(mktemp -d)"
  ( cd "$d" && git init -q && git config user.email t@t && git config user.name t \
      && mkdir -p docs skills .claude && printf 'workspace_root: .m-workflow\n' > .claude/m-workflow.yaml )
  printf '%s' "$d"
}

# assert_case <name> <expected_exit> <repo_dir> [<expected_substring_in_output>]
assert_case() {
  local name="$1" want="$2" dir="$3" needle="${4:-}"
  local out rc
  out="$( cd "$dir" && bash "$GUARD" 2>&1 )"; rc=$?
  local ok=1
  [ "$rc" -eq "$want" ] || ok=0
  [ -z "$needle" ] || { printf '%s' "$out" | grep -qF "$needle" || ok=0; }
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); echo "ok   - $name";
  else fail=$((fail+1)); echo "FAIL - $name (rc=$rc want=$want; out=<$out>)"; fi
  rm -rf "$dir"
}

# AC-1: a committed docs file referencing an untracked concrete workspace_root file is a leak
t="$(new_repo)"; cp "$FIX/leak.md" "$t/docs/leak.md"; ( cd "$t" && git add docs/leak.md && git commit -qm x )
assert_case "AC-1 untracked concrete ref flagged" 1 "$t" "docs/leak.md"

echo "----"; echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
