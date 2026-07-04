#!/usr/bin/env bash
# check-anvil-stage-name.sh — every stage passed to stage-return.sh in the anvil
# skill body must be a stage the gate script's case arms declare. A stage-name
# mismatch = a stage-return the gate rejects → a silently-dead gate (the
# dead-hook failure class this checker family exists to prevent).
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
anvil="$root/skills/anvil/SKILL.md"
gate="$root/scripts/stage-return.sh"
{ [ -f "$anvil" ] && [ -f "$gate" ]; } || exit 0
# declared stages = the gate's case-arm labels (split multi-pattern arms on |)
declared="$(sed -n 's/^[[:space:]]*\([a-z|-]*\))[[:space:]]*$/\1/p; s/^[[:space:]]*\([a-z|-]*\))[[:space:]].*$/\1/p' "$gate" | tr '|' '\n' | grep -v '^\**$' | sort -u)"
used="$(grep -oE 'stage-return\.sh"? [a-z-]+' "$anvil" | awk '{print $2}' | sort -u)"
rc=0
while IFS= read -r u; do
  [ -n "$u" ] || continue
  if ! printf '%s\n' "$declared" | grep -qx "$u"; then
    echo "[check-anvil-stage-name] anvil uses stage '$u' not declared in scripts/stage-return.sh case arms"
    rc=1
  fi
done <<< "$used"
exit "$rc"
