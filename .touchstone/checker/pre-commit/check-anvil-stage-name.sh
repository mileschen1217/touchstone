#!/usr/bin/env bash
# check-anvil-stage-name.sh — every stage passed to normalize-stage-return.sh in the
# anvil skill body must be a stage declared in check-stage-return.py's STAGES set. A
# stage-name mismatch = a stage-return the validator rejects → a silently-dead gate
# (the dead-hook failure class this checker family exists to prevent).
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
anvil="$root/skills/anvil/SKILL.md"
val="$root/scripts/check-stage-return.py"
{ [ -f "$anvil" ] && [ -f "$val" ]; } || exit 0
declared="$(grep -E '^STAGES' "$val" | grep -oE '"[a-z-]+"' | tr -d '"')"
used="$(grep -oE 'normalize-stage-return\.sh [a-z-]+' "$anvil" | awk '{print $2}' | sort -u)"
rc=0
while IFS= read -r u; do
  [ -n "$u" ] || continue
  if ! printf '%s\n' "$declared" | grep -qx "$u"; then
    echo "[check-anvil-stage-name] anvil uses stage '$u' not declared in check-stage-return.py STAGES"
    rc=1
  fi
done <<< "$used"
exit "$rc"
