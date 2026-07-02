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
ver() { git -C "$root" show "$1" 2>/dev/null | grep -o '"version": *"[^"]*"' | head -1; }
pj_cur="$(ver HEAD:.claude-plugin/plugin.json)"
[ -n "$pj_cur" ] || exit 0    # HEAD has no plugin.json yet (fresh project) → nothing to compare
pj_base="$(ver origin/main:.claude-plugin/plugin.json)"
# marketplace.json ships in lockstep with plugin.json (the version-keyed deploy cache
# reads both). Enforce it too — but only when marketplace.json actually exists at HEAD
# AND origin (a consumer project without one must not be false-blocked → infra-safe).
mp_cur="$(ver HEAD:.claude-plugin/marketplace.json)"
mp_base="$(ver origin/main:.claude-plugin/marketplace.json)"

if [ -n "$pj_base" ] && [ "$pj_cur" = "$pj_base" ]; then
  echo "[check-version-bump] shipped surface changed but plugin.json version unchanged ($pj_cur) — bump plugin.json + marketplace.json in lockstep"; exit 1
fi
if [ -n "$mp_cur" ] && [ -n "$mp_base" ] && [ "$mp_cur" = "$mp_base" ]; then
  echo "[check-version-bump] shipped surface changed but marketplace.json version unchanged ($mp_cur) — bump plugin.json + marketplace.json in lockstep"; exit 1
fi
if [ -n "$mp_cur" ] && [ "$pj_cur" != "$mp_cur" ]; then
  echo "[check-version-bump] plugin.json ($pj_cur) and marketplace.json ($mp_cur) versions diverge — keep them in lockstep"; exit 1
fi
exit 0
