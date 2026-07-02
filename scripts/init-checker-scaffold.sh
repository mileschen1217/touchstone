#!/usr/bin/env bash
# init-checker-scaffold.sh <project-dir> — idempotently bootstrap the checker
# scaffold + .gitignore carve, converging any partial state to canonical.
set -uo pipefail
proj="${1:-$PWD}"; gi="$proj/.gitignore"

# 1. dirs + .gitkeep
for stage in pre-commit pre-push; do
  mkdir -p "$proj/.touchstone/checker/$stage"
  : > "$proj/.touchstone/checker/$stage/.gitkeep"   # dir exists (mkdir -p above); let a write error surface
done

# 2. .gitignore carve — canonical order: `.touchstone/*` then the two re-includes.
[ -f "$gi" ] || : > "$gi"
# Remove any existing carve lines (we re-append them in the correct place/order).
tmp="$(mktemp)"; grep -vxF '!.touchstone/checker/' "$gi" | grep -vxF '!.touchstone/checker/**' > "$tmp" || true
mv "$tmp" "$gi"
# Ensure the parent ignore exists exactly once.
if [ "$(grep -cxF '.touchstone/*' "$gi")" -eq 0 ]; then
  printf '.touchstone/*\n' >> "$gi"
fi
# Append the two carve lines AFTER the parent (they were stripped above, so append is correct order).
printf '!.touchstone/checker/\n!.touchstone/checker/**\n' >> "$gi"
