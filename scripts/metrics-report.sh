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

# resolve_runs <collection_dir> → meta paths, one per line; duplicate run_id → hard error (return 1)
# bash-3.2-safe: no associative array — duplicate detection via sort|uniq -d. (portability)
resolve_runs() {
  local dir="$1" m rid dup
  shopt -s nullglob
  local metas=("$dir"/*.meta.json)
  shopt -u nullglob
  # find a duplicated run_id, if any
  dup="$(for m in "${metas[@]}"; do jq -r '.run_id // empty' "$m" 2>/dev/null; done | sort | uniq -d | head -1)"
  if [ -n "$dup" ]; then
    # name ALL paths sharing the duplicated run_id (handles 3+ duplicates, not just the first two)
    local paths=""
    for m in "${metas[@]}"; do
      rid="$(jq -r '.run_id // empty' "$m" 2>/dev/null)"
      [ "$rid" = "$dup" ] && paths="$paths $m"
    done
    echo "DUPLICATE run_id=$dup:$paths" >&2
    return 1
  fi
  for m in "${metas[@]}"; do echo "$m"; done
}

# meta_field <meta> <field> → value OR prints MALFORMED + return 1
meta_field() {
  local v; v="$(jq -er --arg k "$2" '.[$k] // empty' "$1" 2>/dev/null)" || { echo MALFORMED; return 1; }
  [ -z "$v" ] && { echo MALFORMED; return 1; }
  echo "$v"
}

# meta_wallclock <meta> → integer seconds OR prints MALFORMED:<field> + return 1
meta_wallclock() {
  local m="$1" s e si ei
  s="$(jq -r '.started_at // empty' "$m" 2>/dev/null)"
  e="$(jq -r '.ended_at // empty' "$m" 2>/dev/null)"
  si="$(iso_to_epoch "$s")" || { echo "MALFORMED:started_at"; return 1; }
  ei="$(iso_to_epoch "$e")" || { echo "MALFORMED:ended_at"; return 1; }
  echo $(( ei - si ))
}

# iso_to_epoch <iso8601> → epoch seconds OR return 1 (BSD/GNU date tolerant)
iso_to_epoch() {
  local t="$1"; [ -z "$t" ] && return 1
  date -u -d "$t" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$t" +%s 2>/dev/null
}

# mainloop_usage <transcript> → {in,out} over assistant entries with isSidechain false/absent
mainloop_usage() {
  jq -s '[ .[] | select(.type=="assistant") | select((.isSidechain // false) == false) | .message.usage // {} ]
    | { in:  (map(.input_tokens // 0)  | add // 0),
        out: (map(.output_tokens // 0) | add // 0) }' "$1"
}

# session_wallclock <transcript> → integer seconds OR prints MALFORMED + return 1
# AC-21 is literal: the FIRST and LAST transcript ENTRY must each carry a parseable
# `timestamp`. A boundary entry lacking/malforming it → MALFORMED (honest degradation:
# the tool will not claim a span it cannot bound). iso_to_epoch rejects "ABSENT"/"nope".
session_wallclock() {
  local f="$1" rawfirst rawlast fe le
  rawfirst="$(jq -r '.timestamp // "ABSENT"' "$f" 2>/dev/null | head -1)"
  rawlast="$(jq -r '.timestamp // "ABSENT"' "$f" 2>/dev/null | tail -1)"
  fe="$(iso_to_epoch "$rawfirst")" || { echo MALFORMED; return 1; }
  le="$(iso_to_epoch "$rawlast")" || { echo MALFORMED; return 1; }
  echo $(( le - fe ))
}

# costs_aggregate <costs_path> <session_id>
# → {usd,unparseable_lines} (single-scope) OR prints NOSCOPE <unparseable> + stderr note + return 1
# Reads line-by-line with `jq -R | fromjson?` so a single malformed line never aborts
# the whole read (H2). `unparseable` = JSON-parse failure OR parses-but-missing token fields.
costs_aggregate() {
  local f="$1" sid="$2"
  [ -r "$f" ] || { echo "NOSCOPE 0"; echo "costs.jsonl unreadable — aggregate omitted" >&2; return 1; }
  # unparseable count: each non-blank line that fails fromjson, OR parses but lacks both token fields
  local unparse
  unparse="$(awk 'NF' "$f" | jq -R '(fromjson? // null) as $o
      | if $o == null then 1
        elif ($o|type)=="object" and ($o|has("input_tokens")) and ($o|has("output_tokens")) then empty
        else 1 end' 2>/dev/null | jq -s 'length')"
  # classify scope over PARSEABLE token-bearing rows only
  local cls
  cls="$(jq -R 'fromjson? // empty | select((.input_tokens? != null) and (.output_tokens? != null))' "$f" 2>/dev/null \
    | jq -s '
        ( [ .[] | has("session_id") ] ) as $flags
        | if (length==0) then "NOSCOPE"
          elif ($flags|all) then "SINGLE"
          elif ($flags|any) then "MIXED"
          else "NOSCOPE" end')"
  cls="$(echo "$cls" | tr -d '"')"
  case "$cls" in
    SINGLE)
      local usd; usd="$(jq -R --arg sid "$sid" 'fromjson? // empty
        | select((.input_tokens? != null) and (.output_tokens? != null)) | select(.session_id==$sid) | (.cost_usd // 0)' "$f" \
        | jq -s 'add // 0')"
      jq -nc --argjson usd "$usd" --argjson u "$unparse" '{usd:$usd, unparseable_lines:$u}' ;;
    MIXED)
      echo "NOSCOPE $unparse"; echo "costs.jsonl mixed schema (session_id on some rows, absent on others) — aggregate omitted" >&2; return 1 ;;
    *)
      echo "NOSCOPE $unparse"; echo "costs.jsonl has no session scope — aggregate omitted" >&2; return 1 ;;
  esac
}

main() {
  echo "metrics-report: not yet implemented" >&2
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
