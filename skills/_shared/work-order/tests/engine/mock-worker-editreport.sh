#!/usr/bin/env bash
# Simulates a worker legitimately writing its § Report (contract file edit).
printf 'ran the check; PASS\n' >> "$1"
printf '{"total_cost_usd":0.01,"num_turns":1,"session_id":"mock-editc-%s","result":"done","usage":{"output_tokens_details":{"thinking_tokens":5}}}' "$$"
