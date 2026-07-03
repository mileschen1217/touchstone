#!/usr/bin/env bash
# retired-terms registry checker: block a commit when any term registered in
# .touchstone/retired-terms.txt still occurs in tracked files outside the
# allowlist (docs/adr/ historical records, the ledger family, the registry
# itself). Registry absent/comment-only => pass.
set -u
top="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$top" || exit 0
reg=".touchstone/retired-terms.txt"
[ -f "$reg" ] || exit 0
rc=0
while IFS= read -r term; do
  case "$term" in ''|\#*) continue ;; esac
  hits="$(git grep -n -F "$term" -- \
    ':!docs/adr' ':!.touchstone' ':!*.jsonl' 2>/dev/null | head -5)"
  if [ -n "$hits" ]; then
    echo "retired term '$term' still present (registered in $reg):"
    echo "$hits"
    rc=1
  fi
done < "$reg"
exit "$rc"
