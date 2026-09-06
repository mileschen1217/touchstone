#!/usr/bin/env bash
# Simulates a worker that edits a frozen expansion record, then reports success.
R="$(cd "$(dirname "$0")/../.." && pwd)"
printf '\n' >> "$R/tests/expansion/ac-residual.json"
printf '{"total_cost_usd":0.01,"num_turns":1,"session_id":"mock-tamper-%s","result":"done","usage":{"output_tokens_details":{"thinking_tokens":5}}}' "$$"
