#!/usr/bin/env bash
# check-review-summary.sh — pre-push guard: block if the most-recent batch review
# result (review.result.json under .touchstone/research/) carries Critical or High findings.
#
# Guard semantics (absence → passthrough):
#   No review.result.json found → exit 0.  This guard does NOT mandate that every push
#   be preceded by a batch review — only that an existing review's unresolved C/H findings
#   are not silently bypassed.
#
# Schema support (tries in order; falls back to exit 0 if counts cannot be determined):
#   1. review-envelope/v1 with ch_tally_final → .ch_tally_final.{critical,high}
#   2. review-envelope/v1 with findings[]     → count by .severity == "Critical"/"High"
#   3. review.result.json/v1 with findings{}  → .findings.{critical,high} | length
#   4. review.md STAGE-REVIEW-SUMMARY sentinel co-located with the review.result.json
set -uo pipefail

root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0

search_dir="$root/.touchstone/research"
[ -d "$search_dir" ] || exit 0

# Find the most-recently modified review.result.json (mtime sort, cross-platform)
rj=""
best_ts=0
while IFS= read -r f; do
  ts="$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)"
  if [ "$ts" -gt "$best_ts" ] 2>/dev/null; then
    best_ts="$ts"; rj="$f"
  fi
done < <(find "$search_dir" -name "review.result.json" -type f 2>/dev/null)

[ -n "$rj" ] && [ -f "$rj" ] || exit 0

# jq required for schema parsing; absent → passthrough (infra-safe, never a false block)
command -v jq >/dev/null 2>&1 || exit 0

crit=""; high=""

# Attempt 1: ch_tally_final (review-envelope/v1 final-tally form)
if jq -e '.ch_tally_final' "$rj" >/dev/null 2>&1; then
  crit="$(jq -r '.ch_tally_final.critical // 0' "$rj" 2>/dev/null || true)"
  high="$(jq -r '.ch_tally_final.high // 0' "$rj" 2>/dev/null || true)"
fi

# Attempt 2: findings[] array (review-envelope/v1 findings-array form)
if [ -z "$crit" ] && jq -e '(.findings | type) == "array"' "$rj" >/dev/null 2>&1; then
  crit="$(jq '[.findings[] | select(.severity == "Critical" or .severity == "critical")] | length' "$rj" 2>/dev/null || true)"
  high="$(jq '[.findings[] | select(.severity == "High" or .severity == "high")] | length' "$rj" 2>/dev/null || true)"
fi

# Attempt 3: findings{} object (review.result.json/v1 form)
if [ -z "$crit" ] && jq -e '(.findings | type) == "object"' "$rj" >/dev/null 2>&1; then
  crit="$(jq '(.findings.critical // []) | length' "$rj" 2>/dev/null || true)"
  high="$(jq '(.findings.high // []) | length' "$rj" 2>/dev/null || true)"
fi

# Attempt 4: STAGE-REVIEW-SUMMARY sentinel in co-located review.md
if [ -z "$crit" ]; then
  rm_file="$(dirname "$rj")/review.md"
  if [ -f "$rm_file" ]; then
    sline="$(grep -oE 'STAGE-REVIEW-SUMMARY: critical=[0-9]+ high=[0-9]+' "$rm_file" | head -1 || true)"
    if [ -n "$sline" ]; then
      crit="$(printf '%s' "$sline" | grep -oE 'critical=[0-9]+' | cut -d= -f2)"
      high="$(printf '%s' "$sline" | grep -oE 'high=[0-9]+' | cut -d= -f2)"
    fi
  fi
fi

# Cannot determine counts → passthrough (prefer not to false-block)
{ [ -n "$crit" ] && [ -n "$high" ]; } || exit 0

# Block if Critical or High findings are present
if [ "$((crit + high))" -gt 0 ]; then
  echo "[check-review-summary] BLOCK: most-recent batch review has Critical=$crit High=$high unresolved finding(s)"
  echo "  source: $rj"
  echo "  Fix or explicitly acknowledge the findings before pushing."
  exit 1
fi

exit 0
