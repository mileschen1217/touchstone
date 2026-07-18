#!/usr/bin/env bash
# check-prose-budget.sh — R1 ratchet: shipped prose (skills/**/*.md, agents/**/*.md,
# CONTEXT.md) <= TOTAL budget lines AND every file <= FILE budget lines.
# STANDALONE during the v2 sweep (v1 surface still present would fail it);
# promote to pre-commit/ when batch B3 lands. Overrides for fixtures/tests:
# TOUCHSTONE_CHECK_ROOT, PROSE_TOTAL_BUDGET, PROSE_FILE_BUDGET.
# Self-test: check-prose-budget.sh --self-test (runs the green and red fixtures).
set -uo pipefail
if [ "${1:-}" = "--self-test" ]; then
  d="$(cd "$(dirname "$0")/.." && pwd)/fixtures/prose-budget"
  TOUCHSTONE_CHECK_ROOT="$d/green" PROSE_FILE_BUDGET=5 PROSE_TOTAL_BUDGET=10 "$0" \
    || { echo "self-test FAIL: green fixture flagged"; exit 1; }
  TOUCHSTONE_CHECK_ROOT="$d/red" PROSE_FILE_BUDGET=5 PROSE_TOTAL_BUDGET=10 "$0" \
    && { echo "self-test FAIL: red fixture passed"; exit 1; }
  echo "self-test OK"; exit 0
fi
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
total_budget="${PROSE_TOTAL_BUDGET:-3000}"
file_budget="${PROSE_FILE_BUDGET:-200}"
rc=0; total=0
while IFS= read -r f; do
  n=$(wc -l < "$f")
  total=$((total + n))
  if [ "$n" -gt "$file_budget" ]; then
    echo "[check-prose-budget] $f: $n lines (> $file_budget)"; rc=1
  fi
done < <(find "$root/skills" "$root/agents" -name '*.md' -not -path '*/tests/*' 2>/dev/null; \
         [ -f "$root/CONTEXT.md" ] && echo "$root/CONTEXT.md")
if [ "$total" -gt "$total_budget" ]; then
  echo "[check-prose-budget] total shipped prose: $total lines (> $total_budget)"; rc=1
fi
exit "$rc"
