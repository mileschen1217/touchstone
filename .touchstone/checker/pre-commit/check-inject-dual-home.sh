#!/usr/bin/env bash
# check-inject-dual-home.sh — a _shared/inject/*.md fragment body must not be
# statically restated in a consumer (skill body, CONTEXT.md, docs/).
# Partial-restatement threshold: ≥2 sentinel lines (catches 2-of-5 restatements
# that evade a full-text dup-check). Consumers include CONTEXT.md and docs/.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
inject="$root/skills/_shared/inject"
[ -d "$inject" ] || exit 0
rc=0
# consumers = skill bodies + the glossary + docs (NOT the inject dir itself)
consumers="$(find "$root/skills" "$root/docs" -name '*.md' 2>/dev/null | grep -v '/_shared/inject/' ; [ -f "$root/CONTEXT.md" ] && echo "$root/CONTEXT.md")"
for frag in "$inject"/*.md; do
  [ -e "$frag" ] || continue
  # sentinels: distinctive long prose lines (>=50 chars, not headings/blank/fences)
  sentinels="$(grep -nE '.{50,}' "$frag" | grep -vE '^[0-9]+:(#|\s*$|```|\|)' | sed -E 's/^[0-9]+://' | head -8)"
  [ -n "$sentinels" ] || continue
  while IFS= read -r consumer; do
    [ -n "$consumer" ] || continue
    hits=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      grep -qF -- "$line" "$consumer" && hits=$((hits+1))
    done <<< "$sentinels"
    if [ "$hits" -ge 2 ]; then
      echo "[check-inject-dual-home] $(basename "$frag") restated ($hits sentinel lines) in $consumer — single-home it (reference, don't restate)"; rc=1
    fi
  done <<< "$consumers"
done
exit "$rc"
