#!/usr/bin/env bash
# stage-return.sh — fail-closed stage gate for anvil's dispatched stages.
# Reads the stage's native output in <task_dir> and prints exactly one line
# `status=DONE|NEEDS_HUMAN|BLOCKED`. The orchestrator proceeds ONLY from
# that line — never from raw stage text, never from liveness inference.
# Fail closed: ANY ambiguity or malformedness → status=BLOCKED, exit 0.
#
# Usage: stage-return.sh <entry-precondition|plan-review|final-review> <task_dir>
#
# Stage → native output mapping:
#   entry-precondition   precheck.rc (exit code) + precheck.out (stdout):
#                        rc 0 → DONE; else BLOCKED.
#   plan-review /        review.result.json (review-envelope/v1 floor: schema
#   final-review         literal + status enum + provider arrays — a stub JSON
#                        never gates DONE) + review.md with exactly one FULL-LINE
#                        sentinel
#                        `STAGE-REVIEW-SUMMARY: critical=N high=N degraded=true|false`:
#                        status failed → BLOCKED; degraded or partial →
#                        NEEDS_HUMAN; critical+high == 0 → DONE; else BLOCKED.
#                        (`degraded` is derived by the reviewer composite per
#                        cross-provider-reviewer/references/provenance.md
#                        Operation 3 and written into the sentinel — this
#                        gate trusts the sentinel.)
set -uo pipefail
stage="${1:-}"; td="${2:-}"
[ -n "$stage" ] && [ -d "$td" ] || { echo "usage: stage-return.sh <stage> <task_dir>" >&2; echo "status=BLOCKED"; exit 0; }

case "$stage" in
  entry-precondition)
    rc="$(cat "$td/precheck.rc" 2>/dev/null || echo 1)"
    if [ "$rc" = "0" ]; then
      echo "status=DONE"
    else
      echo "status=BLOCKED"
    fi ;;
  plan-review|final-review)
    rj="$td/review.result.json"; rm="$td/review.md"
    [ -f "$rj" ] || { echo "status=BLOCKED"; exit 0; }
    # envelope floor: a stub JSON must not gate DONE — require review-envelope/v1
    # shape (schema literal, status enum, both provider arrays present).
    jq -e '(.schema == "review-envelope/v1")
           and ((.status // "") | IN("ok","partial","failed"))
           and ((.providers_expected | type) == "array") and ((.providers_expected | length) > 0)
           and ((.providers_used | type) == "array")' "$rj" >/dev/null 2>&1 \
      || { echo "status=BLOCKED"; exit 0; }
    rstatus="$(jq -r '.status' "$rj" 2>/dev/null)"
    # sentinel: exactly ONE full-line match (an embedded/substring sentinel never gates)
    sentinel_count="$(grep -cE '^STAGE-REVIEW-SUMMARY: critical=[0-9]+ high=[0-9]+ degraded=(true|false)$' "$rm" 2>/dev/null || echo 0)"
    [ "$sentinel_count" = "1" ] || { echo "status=BLOCKED"; exit 0; }
    [ "$rstatus" = "failed" ] && { echo "status=BLOCKED"; exit 0; }
    sline="$(grep -E '^STAGE-REVIEW-SUMMARY: critical=[0-9]+ high=[0-9]+ degraded=(true|false)$' "$rm")"
    crit="$(echo "$sline" | grep -oE 'critical=[0-9]+' | cut -d= -f2)"
    high="$(echo "$sline" | grep -oE 'high=[0-9]+' | cut -d= -f2)"
    deg="$(echo "$sline" | grep -oE 'degraded=(true|false)' | cut -d= -f2)"
    if [ "$deg" = "true" ] || [ "$rstatus" = "partial" ]; then
      echo "status=NEEDS_HUMAN"
    elif [ "$(( crit + high ))" -eq 0 ]; then
      echo "status=DONE"
    else
      echo "status=BLOCKED"
    fi ;;
  *) echo "status=BLOCKED" ;;
esac
