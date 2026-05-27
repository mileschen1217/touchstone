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

# assert_case <name> <expected_exit> <repo_dir> [<expected_output>] [<match_mode>]
#   match_mode: "" (default) = substring (grep -qF); "exact" = full-output equality
assert_case() {
  local name="$1" want="$2" dir="$3" needle="${4:-}" mode="${5:-}"
  local out rc
  out="$( cd "$dir" && bash "$GUARD" 2>&1 )"; rc=$?
  local ok=1
  [ "$rc" -eq "$want" ] || ok=0
  if [ -n "$needle" ]; then
    if [ "$mode" = "exact" ]; then
      [ "$out" = "$needle" ] || ok=0
    else
      printf '%s' "$out" | grep -qF "$needle" || ok=0
    fi
  fi
  if [ "$ok" -eq 1 ]; then pass=$((pass+1)); echo "ok   - $name";
  else fail=$((fail+1)); echo "FAIL - $name (rc=$rc want=$want; out=<$out>)"; fi
  rm -rf "$dir"
}

# AC-1: a committed docs file referencing an untracked dated artifact is a leak,
# reported with exact file:line: token (the ref is on line 2 of leak.md)
t="$(new_repo)"; cp "$FIX/leak.md" "$t/docs/leak.md"; ( cd "$t" && git add docs/leak.md && git commit -qm x )
assert_case "AC-1 untracked dated ref flagged with file:line" 1 "$t" "docs/leak.md:2: .m-workflow/specs/2026-05-22-foo.md" "exact"

# AC-2: a <placeholder> reference is not a leak (clean tree => pass)
t="$(new_repo)"; cp "$FIX/placeholder.md" "$t/docs/p.md"; ( cd "$t" && git add docs/p.md && git commit -qm x )
assert_case "AC-2 placeholder not flagged" 0 "$t" "pass"

# AC-4: a bare-directory mention (no filename) is not a leak
t="$(new_repo)"; cp "$FIX/bare-dir.md" "$t/docs/b.md"; ( cd "$t" && git add docs/b.md && git commit -qm x )
assert_case "AC-4 bare directory not flagged" 0 "$t" "pass"

# AC-1 (dated-only precision): structural convention files (README.md, vision.md) are
# concrete + untracked but NOT dated => NOT flagged. Regression for the build-time
# false-positive that forced the dated-only narrowing.
t="$(new_repo)"; cp "$FIX/convention.md" "$t/skills/c.md"; ( cd "$t" && git add skills/c.md && git commit -qm x )
assert_case "convention files (non-dated) not flagged" 0 "$t" "pass"

# AC-3: an in-scope (dated) ref whose target is tracked (force-added) is NOT flagged
t="$(new_repo)"
( cd "$t" \
  && mkdir -p .m-workflow/specs && printf 'x\n' > .m-workflow/specs/2026-01-01-tracked.md \
  && git add -f .m-workflow/specs/2026-01-01-tracked.md \
  && printf 'See .m-workflow/specs/2026-01-01-tracked.md here.\n' > docs/r.md && git add docs/r.md \
  && git commit -qm x )
assert_case "AC-3 tracked dated in-scope ref not flagged" 0 "$t" "pass"

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
assert_case "AC-5 absent workspace_root falls back to .m-workflow" 1 "$t" "docs/leak.md:2: .m-workflow/specs/2026-05-22-foo.md" "exact"

# AC-5 configured: a NON-default workspace_root is honoured (leak under .myws/, not .m-workflow/)
t="$(new_repo)"; printf 'workspace_root: .myws\n' > "$t/.claude/m-workflow.yaml"
printf 'See .myws/specs/2026-05-22-foo.md here.\n' > "$t/docs/leak.md"
( cd "$t" && git add docs/leak.md .claude/m-workflow.yaml && git commit -qm x )
assert_case "AC-5 configured non-default workspace_root honoured" 1 "$t" "docs/leak.md:1: .myws/specs/2026-05-22-foo.md" "exact"

# AC-7 (execution): a leak-bearing file OUTSIDE docs/+skills/ is not scanned
t="$(new_repo)"; mkdir -p "$t/scripts"; cp "$FIX/leak.md" "$t/scripts/x.md"
( cd "$t" && git add scripts/x.md && git commit -qm x )
assert_case "AC-7 leak outside docs/skills not scanned" 0 "$t" "pass"

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

# AC-8: the 18 fixtures are de-leaked in the REAL repo — exactly 18 carry the rewritten
# provenance line, and zero .swarm dated refs remain under skills/ + docs/.
n_rewritten="$( grep -rl 'Spec authority: intention-first epic' \
  "$REPO_ROOT/skills/design-spec/tests/step0-fixtures/" \
  "$REPO_ROOT/skills/epic-driven-roadmap/tests/step0-fixtures/" 2>/dev/null | wc -l | tr -d ' ' )"
n_swarm="$( grep -rlE '\.swarm/specs/[0-9]{4}-[0-9]{2}-[0-9]{2}' \
  "$REPO_ROOT/skills/" "$REPO_ROOT/docs/" 2>/dev/null | wc -l | tr -d ' ' )"
if [ "$n_rewritten" -eq 18 ] && [ "$n_swarm" -eq 0 ]; then
  pass=$((pass+1)); echo "ok   - AC-8 18 fixtures de-leaked, 0 .swarm dated refs"
else
  fail=$((fail+1)); echo "FAIL - AC-8 (rewritten=$n_rewritten want 18; swarm=$n_swarm want 0)"
fi

# AC-9: SKILL.md wires the guard (greppable call-site) AND the guard passes on the real tree
if grep -qF "scripts/check-shipped-refs.sh" "$REPO_ROOT/skills/code-review/SKILL.md" \
   && ( cd "$REPO_ROOT" && bash "$GUARD" >/dev/null 2>&1 ); then
  pass=$((pass+1)); echo "ok   - AC-9 SKILL.md wired + guard clean on real tree"
else
  fail=$((fail+1)); echo "FAIL - AC-9 SKILL.md wiring or clean-tree run"
fi

echo "----"; echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
