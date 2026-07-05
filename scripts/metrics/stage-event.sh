#!/usr/bin/env bash
# stage-event.sh — append one stage-boundary event to the machine-local
# observability stream ($TOUCHSTONE_METRICS_DIR/events.jsonl), so a reader can
# see anvil's sub-stage timeline (which stage a long window was spent in)
# without parsing prose. Same safety contract as the stamp hook: every failure
# path is a silent exit 0 — observability never blocks the workflow.
#
# Usage: stage-event.sh <stage-name> <start|end>
set -u

command -v jq >/dev/null 2>&1 || exit 0
stage="${1:-}"; boundary="${2:-}"
[ -n "$stage" ] || exit 0
case "$boundary" in start|end) ;; *) exit 0 ;; esac

base="${TOUCHSTONE_METRICS_DIR:-$HOME/.touchstone-metrics}"
[ -L "$base" ] && exit 0
mkdir -p "$base" 2>/dev/null || exit 0
out="$base/events.jsonl"
[ -L "$out" ] && exit 0

sid="${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
jq -nc \
  --arg schema "stage-event/v1" \
  --arg stage "$stage" \
  --arg boundary "$boundary" \
  --arg sid "$sid" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{schema:$schema, stage:$stage, boundary:$boundary,
    session_id:(if $sid == "" then null else $sid end), ts:$ts}' \
  >> "$out" 2>/dev/null || exit 0
exit 0
