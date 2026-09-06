#!/usr/bin/env bash
# Attempt 1 (one output file open): report cost >= budget -> budget_exhausted.
# Attempt 2: cheap completion; the fixed check_command `false` makes it FAIL.
d="$(dirname "$1")"
n=$(ls "$d"/attempt-*.output.json 2>/dev/null | wc -l | tr -d ' ')
if [ "$n" -le 1 ]; then cost=1.0; else cost=0.01; fi
printf '{"total_cost_usd":%s,"num_turns":2,"session_id":"mock-seq-%s","result":"mock work","usage":{"output_tokens_details":{"thinking_tokens":7}}}' "$cost" "$n"
