#!/usr/bin/env bash
# check-adr-number-unique.sh — no two DISTINCT ADRs share an NNNN- numeric prefix. A
# draft/published mirror (same NNNN AND same slug) is NOT a collision; only the same
# number across DIFFERENT slugs is. Dedupe by number+slug, then flag a number with >1 slug.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
dupes="$(find "$root" -path '*/adr/*' -name '[0-9][0-9][0-9][0-9]-*.md' 2>/dev/null \
  | sed -E 's|.*/([0-9]{4}-[^/]+)\.md$|\1|' | sort -u \
  | sed -E 's|^([0-9]{4})-.*|\1|' | sort | uniq -d)"
[ -z "$dupes" ] && exit 0
echo "[check-adr-number-unique] ADR number(s) used by >1 distinct slug: $dupes"; exit 1
