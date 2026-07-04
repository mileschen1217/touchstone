#!/usr/bin/env bash
# stamp-end.sh — fill `ended_at` on the most recent OPEN run-manifest (the one
# stamp-run.sh started), so the metrics reporter can bound that run's window
# exactly instead of by the next-START heuristic. Called by a gate skill's
# terminal step. Same safety contract as the stamp hook: every failure path is
# a silent exit 0 — observability never blocks the workflow.
#
# Usage: stamp-end.sh [<run_id>]
#   With no arg: the newest manifest whose ended_at is null, scoped to
#   $CLAUDE_SESSION_ID / $CLAUDE_CODE_SESSION_ID when set.
set -u

command -v jq >/dev/null 2>&1 || exit 0
base="${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}"
runs_dir="$base/runs"
[ -d "$runs_dir" ] || exit 0
[ -L "$base" ] && exit 0
[ -L "$runs_dir" ] && exit 0

target=""
if [ -n "${1:-}" ]; then
  target="$runs_dir/$1.json"
  [ -f "$target" ] || exit 0
else
  sid="${CLAUDE_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-}}"
  best_ts=""
  for f in "$runs_dir"/*.json; do
    [ -f "$f" ] || continue
    row="$(jq -r --arg sid "$sid" \
      'select((.ended_at // null) == null)
       | select(($sid == "") or ((.session_id // "") == $sid))
       | .started_at // empty' "$f" 2>/dev/null)" || continue
    [ -n "$row" ] || continue
    if [ -z "$best_ts" ] || [ "$row" \> "$best_ts" ]; then
      best_ts="$row"; target="$f"
    fi
  done
  [ -n "$target" ] || exit 0
fi

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tmp="$(mktemp "${target}.tmp.XXXXXX" 2>/dev/null)" || exit 0
if jq --arg t "$now" '.ended_at = $t' "$target" > "$tmp" 2>/dev/null; then
  mv "$tmp" "$target" 2>/dev/null || rm -f "$tmp"
else
  rm -f "$tmp"
fi
exit 0
