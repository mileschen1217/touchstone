#!/usr/bin/env bash
# check-md-surface-budget.sh — net-byte ratchet over the executable md surface
# (skills/**/*.md + agents/**/*.md). FAILs when the total exceeds the committed
# baseline (scripts/md-surface-baseline.txt). Additions are funded by deletions:
# raising the baseline is legitimate ONLY in the same PR as the growth it funds,
# with the reason appended as a comment line in the baseline file.
#
# Env overrides (tests only): MD_BUDGET_ROOT, MD_BUDGET_BASELINE.
# Exit: 0 within budget | 1 over budget | 2 operational error.
set -uo pipefail

ROOT="${MD_BUDGET_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
BASELINE_FILE="${MD_BUDGET_BASELINE:-$ROOT/scripts/md-surface-baseline.txt}"

{ [ -d "$ROOT/skills" ] && [ -d "$ROOT/agents" ]; } \
  || { echo "ERROR: skills/ or agents/ missing under $ROOT" >&2; exit 2; }
[ -f "$BASELINE_FILE" ] \
  || { echo "ERROR: baseline file missing: $BASELINE_FILE" >&2; exit 2; }

baseline="$(grep -v '^#' "$BASELINE_FILE" | grep -E '^[0-9]+$' | head -1)"
[ -n "$baseline" ] \
  || { echo "ERROR: no numeric baseline line in $BASELINE_FILE" >&2; exit 2; }

total="$(find "$ROOT/skills" "$ROOT/agents" -type f -name '*.md' -print0 \
  | xargs -0 cat | wc -c | tr -d '[:space:]')"
printf '%s' "$total" | grep -qE '^[0-9]+$' \
  || { echo "ERROR: byte-count pipeline produced non-numeric total: '$total'" >&2; exit 2; }

if [ "$total" -gt "$baseline" ]; then
  echo "FAIL: md surface $total bytes > baseline $baseline (+$((total - baseline)))."
  echo "      Fund the addition with deletions, or raise the baseline in THIS PR"
  echo "      with a reason comment in ${BASELINE_FILE#"$ROOT"/}."
  exit 1
fi
echo "OK: md surface $total bytes <= baseline $baseline ($((baseline - total)) headroom)"
exit 0
