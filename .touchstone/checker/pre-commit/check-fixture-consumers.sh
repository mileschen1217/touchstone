#!/usr/bin/env bash
# check-fixture-consumers.sh — pre-commit: every first-level directory under a
# fixtures/ tree is named by at least one test or checker script; every
# checker's --self-test flag is invoked from run-smoke.sh.
#
# Fixtures trees: .touchstone/checker/fixtures/ and scripts/tests-smoke/fixtures/.
# A first-level fixtures/<name>/ dir is "consumed" iff:
#   (a) some *.sh under scripts/, .touchstone/checker/, or skills/ contains the
#       literal substring "fixtures/<name>" on a line that is not a comment, OR
#   (b) a check-<name>.sh exists under .touchstone/checker/{pre-commit,pre-push,
#       standalone}/ or anywhere under skills/** — the smoke rail loop
#       (scripts/tests-smoke/run-smoke.sh) consumes exactly those by
#       construction.
# Rule (a) is anchored on "fixtures/<name>": a bare "<name>/" matches any
# same-named directory anywhere and read green on fixtures nothing runs.
# Deeper directories are consumed together with their first-level parent (the
# rail loop / manual scripts walk them as one tree, never name a grandchild).
# Loose files directly under scripts/tests-smoke/fixtures/ (no directory) are
# consumed iff run-smoke.sh names their basename literally.
#
# Self-test clause: for every *.sh under the three checker stage dirs or
# skills/** whose body contains the literal string "--self-test", run-smoke.sh
# must invoke it. Decided mechanically, without parsing bash: accept when
# run-smoke.sh contains the checker's own basename, OR when it contains BOTH a
# `find` and the checker's own loop root together with the literal
# "--self-test". The loop being mirrored is run-smoke.sh's generic self-test
# loop, verbatim:
#
#   for d in "$repo_root/.touchstone/checker/pre-commit" "$repo_root/.touchstone/checker/pre-push" "$repo_root/.touchstone/checker/standalone"; do
#     [ -d "$d" ] || continue
#     while IFS= read -r f; do
#       grep -q -- '--self-test' "$f" || continue
#       expect_exit "self-test $(basename "$f" .sh)" zero bash "$f" --self-test
#     done < <(find "$d" -maxdepth 1 -name '*.sh' | sort)
#   done
#
# so the loop root is the full stage-directory path (".touchstone/checker/
# pre-commit" and siblings), or "skills" for the sibling loop over skills/**.
# Requiring the full path plus a `find` is the tightening over the previous
# bare category word, which any incidental mention of "pre-commit" satisfied.
#
# INV-1 self-check: this checker decides only presence / basename / literal
# substring match — no semantic judgement of what a fixture or self-test does.
#
# Output on failure: one line per unconsumed path (or uncovered self-test),
# prefixed [check-fixture-consumers], exit 1. Clean → exit 0.
set -uo pipefail

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

fail=0
run_smoke="$root/scripts/tests-smoke/run-smoke.sh"

# sh_corpus: every *.sh under the three trees rule (a) searches.
sh_corpus() {
  find "$root/scripts" "$root/.touchstone/checker" "$root/skills" -type f -name '*.sh' 2>/dev/null
}

# literal_hit <pattern> -- true iff any file in the (a)-corpus contains pattern
# on a line that is not a comment (a fixture named only in prose is not consumed)
# The match is a bash `case` over the stripped body, not a second grep: under
# `set -o pipefail` a `grep -q` that exits on the first hit SIGPIPEs the upstream
# grep, and the pipeline then reports 141 for a match that did happen.
literal_hit() {
  local pat="$1" f body
  while IFS= read -r f; do
    body="$(grep -v '^[[:space:]]*#' "$f" 2>/dev/null)"
    case "$body" in *"$pat"*) return 0 ;; esac
  done < <(sh_corpus)
  return 1
}

# find_check_script <name> -- absolute path on stdout, or nothing
find_check_script() {
  local name="$1" d p
  for d in pre-commit pre-push standalone; do
    p="$root/.touchstone/checker/$d/check-$name.sh"
    [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  p="$(find "$root/skills" -type f -name "check-$name.sh" 2>/dev/null | head -1)"
  [ -n "$p" ] && printf '%s\n' "$p"
}

check_tree() {
  local tree="$1" d name hit
  [ -d "$tree" ] || return 0
  for d in "$tree"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    hit="$(find_check_script "$name")"
    if [ -n "$hit" ]; then
      continue   # rule (b)
    fi
    if literal_hit "fixtures/$name"; then
      continue    # rule (a)
    fi
    echo "[check-fixture-consumers] $d: no consumer (no check-$name.sh under checker stage dirs or skills/**, no literal fixtures/$name reference outside a comment)"
    fail=1
  done
  # loose files directly under this tree (no subdirectory)
  local f base
  for f in "$tree"/*; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    if [ -f "$run_smoke" ] && grep -qF -- "$base" "$run_smoke"; then
      continue
    fi
    echo "[check-fixture-consumers] $f: no consumer (basename not named in run-smoke.sh)"
    fail=1
  done
}

check_tree "$root/.touchstone/checker/fixtures"
check_tree "$root/scripts/tests-smoke/fixtures"

# self-test clause
self_test_checkers=""
while IFS= read -r ck; do
  [ -n "$ck" ] || continue
  grep -qF -- '--self-test' "$ck" 2>/dev/null && self_test_checkers="$self_test_checkers$ck
"
done < <(find "$root/.touchstone/checker/pre-commit" "$root/.touchstone/checker/pre-push" \
  "$root/.touchstone/checker/standalone" "$root/skills" -type f -name '*.sh' 2>/dev/null)

if [ -n "$self_test_checkers" ]; then
  if [ ! -f "$run_smoke" ] || ! grep -qF -- '--self-test' "$run_smoke"; then
    echo "[check-fixture-consumers] $run_smoke: no --self-test invocation at all, but at least one checker declares --self-test"
    fail=1
  else
    while IFS= read -r ck; do
      [ -n "$ck" ] || continue
      base="$(basename "$ck")"
      case "$ck" in
        */.touchstone/checker/pre-commit/*) loop_root=".touchstone/checker/pre-commit" ;;
        */.touchstone/checker/pre-push/*)   loop_root=".touchstone/checker/pre-push" ;;
        */.touchstone/checker/standalone/*) loop_root=".touchstone/checker/standalone" ;;
        */skills/*)                          loop_root="skills" ;;
        *)                                   loop_root="" ;;
      esac
      if grep -qF -- "$base" "$run_smoke"; then continue; fi
      if [ -n "$loop_root" ] && grep -qF -- "$loop_root" "$run_smoke" \
         && grep -qF -- 'find' "$run_smoke"; then continue; fi
      echo "[check-fixture-consumers] $ck: --self-test not invoked from run-smoke.sh (basename absent, and no \`find\` over loop root '$loop_root')"
      fail=1
    done <<< "$self_test_checkers"
  fi
fi

exit "$fail"
