#!/usr/bin/env bash
# check-fixture-consumers.sh — pre-commit: every first-level directory under a
# fixtures/ tree is named by at least one test or checker script; every
# checker's --self-test flag is invoked from run-smoke.sh.
#
# Fixtures trees: .touchstone/checker/fixtures/ and scripts/tests-smoke/fixtures/.
# A first-level fixtures/<name>/ dir is "consumed" iff:
#   (a) some *.sh under scripts/, .touchstone/checker/, or skills/ contains the
#       literal substring "fixtures/<name>" or "<name>/", OR
#   (b) a check-<name>.sh exists under .touchstone/checker/{pre-commit,pre-push,
#       standalone}/ or anywhere under skills/** — the smoke rail loop
#       (scripts/tests-smoke/run-smoke.sh) consumes exactly those by
#       construction.
# Deeper directories are consumed together with their first-level parent (the
# rail loop / manual scripts walk them as one tree, never name a grandchild).
# Loose files directly under scripts/tests-smoke/fixtures/ (no directory) are
# consumed iff run-smoke.sh names their basename literally.
#
# Self-test clause: for every checker file (under the three checker stage dirs,
# or skills/**) whose body contains the literal string "--self-test",
# run-smoke.sh must invoke it. Decided mechanically, without parsing bash:
# accept when run-smoke.sh contains the literal string "--self-test" AND
# EITHER the checker's own basename appears in run-smoke.sh, OR the checker's
# stage category ("pre-commit" / "pre-push" / "standalone" / "skills" —
# whichever tree it lives under) appears in run-smoke.sh. This mirrors
# run-smoke.sh's own generic self-test loop, which iterates exactly those four
# category directories via `find <category-dir> -name 'check-*.sh'` and never
# names an individual checker file — so category-name presence is the correct
# mechanical proxy for "a generic self-test loop covers it".
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
literal_hit() {
  local pat="$1" f
  while IFS= read -r f; do
    grep -qF -- "$pat" "$f" 2>/dev/null && return 0
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
    if literal_hit "fixtures/$name" || literal_hit "$name/"; then
      continue    # rule (a)
    fi
    echo "[check-fixture-consumers] $d: no consumer (no check-$name.sh under checker stage dirs or skills/**, no literal fixtures/$name or $name/ reference)"
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
  "$root/.touchstone/checker/standalone" "$root/skills" -type f -name 'check-*.sh' 2>/dev/null)

if [ -n "$self_test_checkers" ]; then
  if [ ! -f "$run_smoke" ] || ! grep -qF -- '--self-test' "$run_smoke"; then
    echo "[check-fixture-consumers] $run_smoke: no --self-test invocation at all, but at least one checker declares --self-test"
    fail=1
  else
    while IFS= read -r ck; do
      [ -n "$ck" ] || continue
      base="$(basename "$ck")"
      case "$ck" in
        */.touchstone/checker/pre-commit/*) cat=pre-commit ;;
        */.touchstone/checker/pre-push/*)   cat=pre-push ;;
        */.touchstone/checker/standalone/*) cat=standalone ;;
        */skills/*)                          cat=skills ;;
        *)                                    cat="" ;;
      esac
      if grep -qF -- "$base" "$run_smoke"; then continue; fi
      if [ -n "$cat" ] && grep -qF -- "$cat" "$run_smoke"; then continue; fi
      echo "[check-fixture-consumers] $ck: --self-test not invoked from run-smoke.sh (basename and stage category '$cat' both absent)"
      fail=1
    done <<< "$self_test_checkers"
  fi
fi

exit "$fail"
