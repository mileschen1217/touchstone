#!/usr/bin/env bash
sleep 0.4
printf '{"total_cost_usd":0.01,"num_turns":1,"session_id":"mock-slow-%s","result":"done","usage":{"output_tokens_details":{"thinking_tokens":5}}}' "$$"
