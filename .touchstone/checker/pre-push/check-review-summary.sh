#!/usr/bin/env bash
# check-review-summary.sh — pre-push guard: block if the newest review.yaml under
# .touchstone/epics/ carries Critical or High findings (counts.C + counts.H > 0).
#
# Absence → passthrough: no review.yaml, no PyYAML, or unreadable counts → exit 0.
# The guard does not mandate a review before every push — only that an existing
# review's unresolved C/H are not silently bypassed.
# Self-test: check-review-summary.sh --self-test
set -uo pipefail
if [ "${1:-}" = "--self-test" ]; then
  t="$(mktemp -d)"; mkdir -p "$t/.touchstone/epics/e/review-1"
  printf 'gate: deliverable-review\ncounts: {C: 0, H: 1, M: 0, L: 0}\n' > "$t/.touchstone/epics/e/review-1/review.yaml"
  TOUCHSTONE_CHECK_ROOT="$t" "$0" && { echo "self-test FAIL: C+H>0 passed"; exit 1; }
  printf 'gate: deliverable-review\ncounts: {C: 0, H: 0, M: 2, L: 0}\n' > "$t/.touchstone/epics/e/review-1/review.yaml"
  TOUCHSTONE_CHECK_ROOT="$t" "$0" || { echo "self-test FAIL: C+H=0 blocked"; exit 1; }
  rm -rf "$t"; echo "self-test OK"; exit 0
fi
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
search_dir="$root/.touchstone/epics"
[ -d "$search_dir" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
python3 -c 'import yaml' 2>/dev/null || exit 0

rf=""; best_ts=0
while IFS= read -r f; do
  ts="$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)"
  if [ "$ts" -gt "$best_ts" ] 2>/dev/null; then best_ts="$ts"; rf="$f"; fi
done < <(find "$search_dir" -name "review.yaml" -type f 2>/dev/null)
[ -n "$rf" ] || exit 0

ch="$(python3 - "$rf" <<'PY'
import sys, yaml
try:
    r = yaml.safe_load(open(sys.argv[1], encoding='utf-8')) or {}
    c = r.get('counts') or {}
    print(int(c.get('C', 0)) + int(c.get('H', 0)))
except Exception:
    print('')
PY
)"
[ -n "$ch" ] || exit 0
if [ "$ch" -gt 0 ]; then
  echo "[check-review-summary] BLOCK: newest review.yaml has Critical+High = $ch unresolved finding(s)"
  echo "  source: $rf"
  echo "  Fix or explicitly waive the findings before pushing."
  exit 1
fi
exit 0
