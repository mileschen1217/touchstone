#!/usr/bin/env bash
# Emits an over-budget cost AND exits nonzero: the DS-4 three-way tie
# (exhausted and errored in one attempt) must record budget_exhausted.
printf '{"total_cost_usd":1.0,"num_turns":1,"session_id":"mock-both-%s","result":"partial","usage":{"output_tokens_details":{"thinking_tokens":3}}}' "$$"
exit 1
