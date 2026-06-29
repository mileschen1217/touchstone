#!/usr/bin/env bash
# metrics-report.sh — on-demand OTel-aware token/cost/time report for a touchstone session.
# Reads collected artifacts only; dispatches no LLM (AC-5).
set -uo pipefail
# NB: bash 3.2 target — NO associative arrays anywhere (see Global Constraints).

# price_lookup <model> <prices_json> → "in cached out" OR prints MISSING + return 1
price_lookup() {
  local model="$1" prices="$2"
  local row; row="$(jq -e --arg m "$model" '.[$m] // empty' "$prices" 2>/dev/null)" || { echo MISSING; return 1; }
  [ -z "$row" ] && { echo MISSING; return 1; }
  echo "$row" | jq -r '"\(.input_per_mtok) \(.cached_input_per_mtok) \(.output_per_mtok)"'
}

# compute_codex_cost <in> <cached_in> <out> <reasoning> <model> <prices_json>
# → USD float (reasoning billed at output rate) OR prints MISSING_PRICE + return 1
compute_codex_cost() {
  local in="$1" cached="$2" out="$3" reason="$4" model="$5" prices="$6"
  local rates; rates="$(price_lookup "$model" "$prices")" || { echo MISSING_PRICE; return 1; }
  local ir cr orr; read -r ir cr orr <<<"$rates"
  awk -v i="$in" -v c="$cached" -v o="$out" -v r="$reason" -v ir="$ir" -v cr="$cr" -v orr="$orr" \
    'BEGIN{ printf "%.6f", (i*ir + c*cr + (o+r)*orr)/1000000 }'
}

# codex_usage <codex_path> → {in,cached_in,out,reasoning} OR prints MISSING + return 1
codex_usage() {
  local f="$1"
  [ -r "$f" ] || { echo MISSING; return 1; }
  jq -s '[ .[] | select(.type=="turn.completed") | .usage ]
    | { in:        (map(.input_tokens // 0)            | add // 0),
        cached_in: (map(.cached_input_tokens // 0)     | add // 0),
        out:       (map(.output_tokens // 0)           | add // 0),
        reasoning: (map(.reasoning_output_tokens // 0) | add // 0) }' "$f"
}

main() {
  echo "metrics-report: not yet implemented" >&2
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
