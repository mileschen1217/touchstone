#!/usr/bin/env bash
# check-orphan-check.sh — a check-*.sh placed DIRECTLY under .touchstone/checker/
# (not under a pre-commit/ or pre-push/ stage subdir) is an orphan: the hook only
# globs checker/<stage>/, so the script silently never runs. Defense-in-depth twin
# of the test-suite structure meta-check; catching this at commit time prevents silent
# dead gates from entering the committed tree.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
cdir="$root/.touchstone/checker"; [ -d "$cdir" ] || exit 0
rc=0
for f in "$cdir"/check-*.sh; do          # directly under checker/, NOT a stage subdir
  [ -e "$f" ] || continue
  echo "[check-orphan-check] $f is not under a pre-commit/ or pre-push/ stage dir — it will never run (orphan)"; rc=1
done
exit "$rc"
