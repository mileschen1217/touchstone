#!/usr/bin/env bash
# Map a dispatched stage's native output to a stage-return/v1 artifact, then
# echo the validator's normalized status. Fail closed → BLOCKED on any ambiguity.
set -uo pipefail
stage="${1:-}"; td="${2:-}"
here="$(cd "$(dirname "$0")" && pwd)"
[ -n "$stage" ] && [ -d "$td" ] || { echo "usage: normalize-stage-return.sh <stage> <task_dir>" >&2; echo "status=BLOCKED"; exit 0; }
out="$td/$stage.stage-return.json"

emit(){ printf '%s' "$1" > "$out"; python3 "$here/check-stage-return.py" "$out"; }

case "$stage" in
  entry-precondition)
    rc="$(cat "$td/precheck.rc" 2>/dev/null || echo 1)"
    if [ "$rc" = "0" ]; then
      emit '{"schema":"stage-return/v1","stage":"entry-precondition","status":"DONE","artifacts":["precheck.out"]}'
    else
      reason="$(tr -d '\n' < "$td/precheck.out" 2>/dev/null | sed 's/"/\\"/g')"; [ -n "$reason" ] || reason="entry precondition failed"
      emit "{\"schema\":\"stage-return/v1\",\"stage\":\"entry-precondition\",\"status\":\"BLOCKED\",\"reason\":\"$reason\"}"
    fi ;;
  plan-review|final-review)
    rj="$td/review.result.json"; rm="$td/review.md"
    sline="$(grep -oE 'STAGE-REVIEW-SUMMARY: critical=[0-9]+ high=[0-9]+ degraded=(true|false)' "$rm" 2>/dev/null | tail -1)"
    rstatus="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("status",""))' "$rj" 2>/dev/null || echo "")"
    if [ -z "$sline" ]; then
      emit "{\"schema\":\"stage-return/v1\",\"stage\":\"$stage\",\"status\":\"BLOCKED\",\"reason\":\"missing or malformed STAGE-REVIEW-SUMMARY sentinel\"}"
    elif [ "$rstatus" = "failed" ]; then
      emit "{\"schema\":\"stage-return/v1\",\"stage\":\"$stage\",\"status\":\"BLOCKED\",\"reason\":\"review status failed\"}"
    else
      crit="$(echo "$sline" | grep -oE 'critical=[0-9]+' | cut -d= -f2)"
      high="$(echo "$sline" | grep -oE 'high=[0-9]+' | cut -d= -f2)"
      deg="$(echo "$sline" | grep -oE 'degraded=(true|false)' | cut -d= -f2)"
      if [ "$deg" = "true" ] || [ "$rstatus" = "partial" ]; then
        emit "{\"schema\":\"stage-return/v1\",\"stage\":\"$stage\",\"status\":\"NEEDS_HUMAN\",\"reason\":\"degraded/partial provenance — needs human ack\"}"
      elif [ "$(( crit + high ))" -eq 0 ]; then
        emit "{\"schema\":\"stage-return/v1\",\"stage\":\"$stage\",\"status\":\"DONE\",\"artifacts\":[\"review.md\"]}"
      else
        emit "{\"schema\":\"stage-return/v1\",\"stage\":\"$stage\",\"status\":\"BLOCKED\",\"reason\":\"C+H=$(( crit + high )) findings\"}"
      fi
    fi ;;
  *) echo "status=BLOCKED" ;;
esac
