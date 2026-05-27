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

# AC-2: a <placeholder> reference is not a leak (clean tree => pass)
t="$(new_repo)"; cp "$FIX/placeholder.md" "$t/docs/p.md"; ( cd "$t" && git add docs/p.md && git commit -qm x )
assert_case "AC-2 placeholder not flagged" 0 "$t" "pass"

# AC-4: a bare-directory mention (no filename) is not a leak
t="$(new_repo)"; cp "$FIX/bare-dir.md" "$t/docs/b.md"; ( cd "$t" && git add docs/b.md && git commit -qm x )
assert_case "AC-4 bare directory not flagged" 0 "$t" "pass"

# AC-3: an in-scope ref whose target is tracked (force-added) is NOT flagged
t="$(new_repo)"
( cd "$t" \
  && mkdir -p .m-workflow/keep && printf 'x\n' > .m-workflow/keep/tracked.md \
  && git add -f .m-workflow/keep/tracked.md \
  && printf 'See .m-workflow/keep/tracked.md here.\n' > docs/r.md && git add docs/r.md \
  && git commit -qm x )
assert_case "AC-3 tracked in-scope ref not flagged" 0 "$t" "pass"

# AC-11: an UNTRACKED draft under docs/ is not scanned (scan = git ls-files -- docs skills)
t="$(new_repo)"
cp "$FIX/leak.md" "$t/docs/draft.md"   # contains a real leak token, but NOT git-added
( cd "$t" && printf '# clean shipped doc\n' > docs/shipped.md && git add docs/shipped.md && git commit -qm x )
assert_case "AC-11 untracked draft not scanned" 0 "$t" "pass"

# AC-6 clean: a repo with no leak exits 0 + "pass"
t="$(new_repo)"; ( cd "$t" && printf '# clean\n' > docs/c.md && git add docs/c.md && git commit -qm x )
assert_case "AC-6 clean tree exits 0 pass" 0 "$t" "pass"

# AC-6 operational error: not inside a git work tree => exit 2
t="$(mktemp -d)"   # NO git init
assert_case "AC-6 non-git dir exits 2" 2 "$t" "ERROR"

# AC-5 fallback: no workspace_root key => default .m-workflow still flags the leak
t="$(new_repo)"; printf '# no ws key\n' > "$t/.claude/m-workflow.yaml"
cp "$FIX/leak.md" "$t/docs/leak.md"; ( cd "$t" && git add docs/leak.md .claude/m-workflow.yaml && git commit -qm x )
assert_case "AC-5 absent workspace_root falls back to .m-workflow" 1 "$t" "docs/leak.md"

# AC-10: the guard header states the best-effort / grounded / placeholder-convention contract
if grep -qiF "best-effort floor" "$GUARD" && grep -qiF "certainly a leak" "$GUARD" \
   && grep -qiF "false-negatives are expected" "$GUARD" && grep -qiF "grounded-claims" "$GUARD"; then
  pass=$((pass+1)); echo "ok   - AC-10 header self-description"
else
  fail=$((fail+1)); echo "FAIL - AC-10 header self-description"
fi

# AC-7: the guard's own fixtures live under scripts/tests/ (outside docs/+skills/ scan scope)
if [ -d "$FIX" ] && case "$FIX" in */scripts/tests/shipped-ref-fixtures) true;; *) false;; esac; then
  pass=$((pass+1)); echo "ok   - AC-7 fixtures outside scan scope"
else
  fail=$((fail+1)); echo "FAIL - AC-7 fixtures outside scan scope"
fi

echo "----"; echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
