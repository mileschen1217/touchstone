#!/usr/bin/env bash
# check-version-bump.sh — pre-push: if the diff origin/main..HEAD touches any
# shipped-surface prefix (from .touchstone/shipped-surface.txt), plugin.json version
# MUST differ from origin/main's. origin/main unresolvable → exit 0 + warning
# (infra-safe, never a false block).
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
ss="$root/.touchstone/shipped-surface.txt"; [ -f "$ss" ] || exit 0
pj="$root/.claude-plugin/plugin.json"; [ -f "$pj" ] || exit 0

if ! changed="$(git -C "$root" diff --name-only origin/main..HEAD 2>/dev/null)"; then
  echo "[check-version-bump] WARNING: origin/main unresolvable (no origin / never fetched) — skipping (infra-safe)"; exit 0
fi
# read prefixes (skip # comments / blanks). Prefixes are literal path fragments, matched
# with FIXED-STRING semantics (grep -F + a manual leading-anchor), NOT as regexes — a
# prefix like `.claude-plugin/` must not have its `.` treated as any-char.
touches=0
while IFS= read -r prefix; do
  case "$prefix" in ''|\#*) continue ;; esac
  while IFS= read -r path; do
    case "$path" in "$prefix"*) touches=1; break 2 ;; esac   # glob-anchored literal prefix
  done <<< "$changed"
done < "$ss"
[ "$touches" -eq 0 ] && exit 0

# Compare the COMMITTED (HEAD) version against origin/main — NOT the working tree. A
# working-tree read would false-pass a version bump that is staged/edited but not yet
# committed (HEAD would still carry origin's version at push time).
cur="$(git -C "$root" show HEAD:.claude-plugin/plugin.json 2>/dev/null | grep -o '"version": *"[^"]*"' | head -1)"
[ -n "$cur" ] || exit 0    # HEAD has no plugin.json yet (fresh project) → nothing to compare
base="$(git -C "$root" show origin/main:.claude-plugin/plugin.json 2>/dev/null | grep -o '"version": *"[^"]*"' | head -1)"
if [ -n "$base" ] && [ "$cur" = "$base" ]; then
  echo "[check-version-bump] shipped surface changed but plugin.json version unchanged ($cur) — bump plugin.json + marketplace.json"; exit 1
fi
exit 0
