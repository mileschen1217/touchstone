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
# 2. challenge stamp required iff requirement-bearing: frontmatter carries
#    `challenged-by: <challenger-id> / <date> / <commit>` (the sole attestation).
reqs="$(bash "$here/spec-extract.sh" reqs "$spec")" || { echo "BLOCK: spec-extract failed (fail closed)"; exit 1; }
if [ -n "$reqs" ]; then
  stamp="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^challenged-by:/{print}' "$spec")"
  [ -n "$stamp" ] || { echo "BLOCK: challenged-by stamp missing for requirement-bearing spec"; exit 1; }
fi
# 3. live-bearing structural check (requirement-bearing specs only). A contained
#    requirement-free spec legitimately carries no Verification Strategy (design-spec:
#    "VS attaches to full specs only"), so gating it on VS here would over-reach.
#    Echo UNCONDITIONALLY within the branch so advisory candidates emitted on exit 0
#    are not swallowed by a capture-on-failure pattern.
if [ -n "$reqs" ]; then
  lb_out="$(bash "$here/check-live-bearing.sh" "$spec" 2>&1)"; lb_rc=$?
  [ -n "$lb_out" ] && echo "$lb_out"
  if [ "$lb_rc" -ne 0 ]; then
    echo "BLOCK: live-bearing structural check failed"; exit 1
  fi
fi
echo "PRE-CHECK OK → dispatch"; exit 0
