#!/usr/bin/env bash
# Aggregate test runner. Invokes every scripts/tests/*.sh EXCEPT itself.
set -uo pipefail
cd "$(dirname "$0")"
rc=0
for t in *.sh; do
  [ "$t" = "run-all.sh" ] && continue          # self-exclusion: no recursion
  echo "== $t =="
  bash "$t" || rc=1                              # propagate any sub-check failure
done
exit "$rc"
