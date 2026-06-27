#!/usr/bin/env bash
# Deterministic design-review pre-check: structural floor + (requirement-bearing
# only) challenge-result. BLOCK (exit 1) on any failure; PROCEED (exit 0) clean.
set -uo pipefail
spec="${1:-}"; [ -f "$spec" ] || { echo "usage: design-review-precheck.sh <spec>" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"

# ONLY draft is ungated; accepted-candidate (crucible pre-accept) IS gated, accepted re-reviews are gated too.
status="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^status:/{print tolower($2)}' "$spec")"
[ "$status" = "draft" ] && { echo "PRE-CHECK skipped: draft"; exit 0; }

# 1. structural floor
if ! out="$(bash "$here/check-spec-floor.sh" "$spec" 2>&1)"; then
  echo "BLOCK: structural pre-check failed"; echo "$out"; exit 1
fi
# 2. challenge-result required iff requirement-bearing
reqs="$(bash "$here/spec-extract.sh" reqs "$spec")" || { echo "BLOCK: spec-extract failed (fail closed)"; exit 1; }
if [ -n "$reqs" ]; then
  cr="${spec%.md}.challenge.json"
  [ -f "$cr" ] || { echo "BLOCK: challenge-result missing for requirement-bearing spec"; exit 1; }
  if ! out="$(python3 "$here/check-challenge-result.py" "$spec" "$cr" 2>&1)"; then
    echo "BLOCK: challenge-result pre-check failed"; echo "$out"; exit 1
  fi
fi
echo "PRE-CHECK OK → dispatch"; exit 0
