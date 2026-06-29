#!/usr/bin/env bash
# metrics-report.sh — on-demand OTel-aware token/cost/time report for a touchstone session.
# Reads collected artifacts only; dispatches no LLM.
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
# The FIRST and LAST transcript ENTRY must each carry a parseable
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
# the whole read. `unparseable` = JSON-parse failure OR parses-but-missing token fields.
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

# otel_normalize <otlp_file> → one flat event JSON per line (only claude_code.api_request records)
# Reads nested OTLP (resourceLogs[].scopeLogs[].logRecords[]); emits flat shape:
#   { query_source, session_id, agent_name, tokens, cost_usd, ts }
# ts = floor(timeUnixNano / 1e9) via string-slice (avoids IEEE-754 precision loss on 64-bit ns).
# intValue attributes in OTLP proto-JSON are encoded as strings; tonumber converts them.
otel_normalize() {
  local f="$1"
  jq -c '
    select(has("resourceLogs"))
    | .resourceLogs[].scopeLogs[].logRecords[]
    | select(.body.stringValue == "claude_code.api_request")
    | . as $rec
    | ([ $rec.attributes[] | {(.key): .value} ] | add // {}) as $attrs
    | { query_source: ($attrs["query_source"].stringValue // ""),
        session_id:   ($attrs["session.id"].stringValue // null),
        agent_name:   ($attrs["agent.name"].stringValue // null),
        tokens:       (($attrs["input_tokens"].intValue  // "0" | tonumber)
                     + ($attrs["output_tokens"].intValue // "0" | tonumber)),
        cost_usd:     ($attrs["cost_usd"].doubleValue // 0),
        ts:           ($rec.timeUnixNano[0:(($rec.timeUnixNano | length) - 9)] | tonumber) }
  ' "$f" 2>/dev/null
}

# otel_scoped_events <otel> <session_id> <scope_assert>
# → one scoped subagent event JSON per line; return 2 if file absent (typed no-data)
# Auto-detects nested OTLP (first line has .resourceLogs/.resourceMetrics) and normalizes;
# flat files pass through unchanged. Subagent predicate: query_source starts with "agent:".
otel_scoped_events() {
  local f="$1" sid="$2" assert="$3" is_otlp=0 first_line
  [ -r "$f" ] || return 2
  first_line="$(grep -m1 '.' "$f")"
  printf '%s' "$first_line" | jq -e 'has("resourceLogs") or has("resourceMetrics")' >/dev/null 2>&1 \
    && is_otlp=1
  if [ "$is_otlp" -eq 1 ]; then
    otel_normalize "$f"
  else
    cat "$f"
  fi | jq -c --arg sid "$sid" --arg assert "$assert" '
    select((.query_source // "") | startswith("agent:"))
    | if (has("session_id")) then
        ( if .session_id == $sid then . else empty end )
      else
        ( if ($assert | length) > 0 then . else (. + {"_unscoped": true}) end )
      end' 2>/dev/null
}

# attribute_event <ts> <windows_tsv> → run_id | UNATTRIBUTED | AMBIGUOUS (half-open [start,end))
# Uses awk for the comparison so FLOAT/ms epoch timestamps work (a real otelcol export
# may emit fractional seconds — integer-only `[ -ge ]` would error → spurious UNATTRIBUTED).
attribute_event() {
  local ts="$1" wins="$2" match="" count=0 rid s e
  # a non-numeric ts can never be attributed — awk would coerce "abc"/"1.2.3"→a number and
  # falsely match a window. Require a STRICT decimal (no multi-dot, no bare "."). Return
  # UNATTRIBUTED; otel_diagnostics marks such an event malformed. (M-new-2)
  [[ "$ts" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo UNATTRIBUTED; return; }
  while IFS=$'\t' read -r rid s e; do
    [ -z "$rid" ] && continue
    if awk -v t="$ts" -v a="$s" -v b="$e" 'BEGIN{ exit !(t>=a && t<b) }'; then
      match="$rid"; count=$((count+1))
    fi
  done <<< "$wins"
  if   [ "$count" -eq 0 ]; then echo UNATTRIBUTED
  elif [ "$count" -eq 1 ]; then echo "$match"
  else echo AMBIGUOUS; fi
}

# cc_subagent_cell <run_id> <events_json_lines> <windows_tsv> → {tokens,cost_usd} OR NOEVENTS (return 1)
# Counts MATCHED EVENTS, not token sum, for the NOEVENTS guard (a real zero-token event is
# still an event — "no OTel subagent events" means no events, not zero tokens.
# SKIPS events marked `_unscoped:true` — an unscoped event must never be silently attributed
# to a run even if its ts lands in a window; the rollup marks them unverified.
cc_subagent_cell() {
  local rid="$1" events="$2" wins="$3" line ts who matched=0
  local toks=0 cost="0"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    [ "$(echo "$line" | jq -r '._unscoped // false')" = true ] && continue
    ts="$(echo "$line" | jq -r '.ts')"
    who="$(attribute_event "$ts" "$wins")"
    if [ "$who" = "$rid" ]; then
      matched=$((matched+1))
      toks=$(( toks + $(echo "$line" | jq -r '.tokens // 0') ))
      cost="$(awk -v a="$cost" -v b="$(echo "$line" | jq -r '.cost_usd // 0')" 'BEGIN{printf "%.6f", a+b}')"
    fi
  done <<< "$events"
  [ "$matched" -eq 0 ] && { echo NOEVENTS; return 1; }
  jq -nc --argjson t "$toks" --argjson c "$cost" '{tokens:$t, cost_usd:$c}'
}

# build_windows <collection_dir> → TSV `run_id<TAB>start_epoch<TAB>end_epoch`, one per run
# whose meta carries parseable bounds. The single home of window construction (reused by
# build_per_run_rows AND otel_diagnostics). Assumes duplicate run_id already rejected by main.
build_windows() {
  local col="$1" m rid s e se ee
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    rid="$(jq -r '.run_id' "$m")"
    s="$(jq -r '.started_at // empty' "$m")"; e="$(jq -r '.ended_at // empty' "$m")"
    se="$(iso_to_epoch "$s" 2>/dev/null || echo "")"; ee="$(iso_to_epoch "$e" 2>/dev/null || echo "")"
    [ -n "$se" ] && [ -n "$ee" ] && printf '%s\t%s\t%s\n' "$rid" "$se" "$ee"
  done < <(resolve_runs "$col" 2>/dev/null)
}

# otel_diagnostics <collection> <otel> <sid> <assert> → per-event closed-list markers for the
# events that DON'T land in exactly one run window — so the per-run-reporting honesty requirement
# is met. Emits one JSON line per flagged event: malformed-ts, unattributed, or ambiguous.
otel_diagnostics() {
  local col="$1" otel="$2" sid="$3" assert="$4"
  [ -z "$otel" ] && return 0
  local events; events="$(otel_scoped_events "$otel" "$sid" "$assert")"; [ $? -eq 2 ] && return 0
  local wins; wins="$(build_windows "$col")"
  # pre-compute all markers via the single emitter — no literal in jq (DS-1)
  local m_scope m_ts m_unat m_amb
  m_scope="$(UNVERIFIED 'OTel events lack session scope')"
  m_ts="$(UNVERIFIED 'malformed OTel timestamp')"
  m_unat="$(UNVERIFIED 'unattributed OTel event')"
  m_amb="$(UNVERIFIED 'ambiguous OTel run attribution')"
  local line ts who
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    # Per-run treatment: an unscoped event is surfaced (not silently dropped) so the
    # reader can see WHICH events triggered the rollup's lack-session-scope verdict.
    if [ "$(echo "$line" | jq -r '._unscoped // false')" = true ]; then
      echo "$line" | jq -c --arg m "$m_scope" '{agent_name, ts, marker:$m}'; continue
    fi
    ts="$(echo "$line" | jq -r '.ts')"
    if ! [[ "$ts" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "$line" | jq -c --arg m "$m_ts" '{agent_name, ts, marker:$m}'; continue
    fi
    who="$(attribute_event "$ts" "$wins")"
    if [ "$who" = UNATTRIBUTED ]; then
      echo "$line" | jq -c --arg m "$m_unat" '{agent_name, ts, marker:$m}'
    elif [ "$who" = AMBIGUOUS ]; then
      echo "$line" | jq -c --arg m "$m_amb" '{agent_name, ts, marker:$m}'
    fi
  done <<< "$events"
}

UNVERIFIED() {
  # Single sentinel emitter (DS-1). Produces the closed-list sentinel string.
  # Closed list: 11 reasons; "malformed meta" accepts any field suffix.
  # Off-list reason → loud stderr error + return 1.
  local reason="$1" valid=0
  case "$reason" in
    "codex artifact absent")               valid=1 ;;
    "model not in price table")            valid=1 ;;
    "subagent usage requires OTel")        valid=1 ;;
    "no OTel subagent events for run")     valid=1 ;;
    "OTel events lack session scope")      valid=1 ;;
    "unattributed OTel event")             valid=1 ;;
    "ambiguous OTel run attribution")      valid=1 ;;
    "malformed transcript timestamp")      valid=1 ;;
    "malformed OTel timestamp")            valid=1 ;;
    "costs aggregate lacks session scope") valid=1 ;;
    "malformed meta "*)                    valid=1 ;;
  esac
  if [ "$valid" -eq 0 ]; then
    echo "UNVERIFIED: off-list reason '$reason' — not on closed sentinel list" >&2
    return 1
  fi
  echo "[unverified: $reason]"
}

# build_per_run_rows <collection> <prices> <otel> <session_id> <scope_assert>
# SINGLE pass (bash-3.2-safe, no associative array): windows + scoped events are built ONCE up
# front, so each run's row — codex cell, cost, wallclock, cc_subagent, dispatch_total — is fully
# assembled in one loop iteration. No row-stash between passes is needed.
build_per_run_rows() {
  local col="$1" prices="$2" otel="$3" sid="$4" assert="$5"
  local metas; metas="$(resolve_runs "$col")" || return 1   # propagate duplicate hard error
  local events="" otel_state="present"
  if [ -n "$otel" ]; then
    events="$(otel_scoped_events "$otel" "$sid" "$assert")"; [ $? -eq 2 ] && otel_state="absent"
  else
    otel_state="absent"
  fi
  # Build attribution windows once (DRY — otel_diagnostics reuses build_windows). A run with a
  # malformed/absent bounding timestamp contributes NO window: the tool cannot bound it, so OTel
  # events in its real range fall to UNATTRIBUTED rather than being mis-attributed — honest
  # degradation; the run's wallclock cell is already [unverified] and its cc_subagent → NOEVENTS.
  local wins; wins="$(build_windows "$col")"
  local m rid stage model codex codex_cost wc cc_sub total cpath cabs usage cell badf
  while IFS= read -r m; do
    [ -z "$m" ] && continue
    rid="$(jq -r '.run_id' "$m")"; stage="$(jq -r '.stage // ""' "$m")"; model="$(jq -r '.model // ""' "$m")"
    # codex cell + codex_cost
    cpath="$(jq -r '.codex_artifact_path // empty' "$m")"
    if [ -z "$cpath" ] || [ "$cpath" = null ]; then
      codex="$(UNVERIFIED 'codex artifact absent')"; codex_cost="$(UNVERIFIED 'codex artifact absent')"
    else
      cabs="$(dirname "$m")/$cpath"
      if usage="$(codex_usage "$cabs" 2>/dev/null)"; then
        codex="$usage"
        if codex_cost="$(compute_codex_cost "$(echo "$usage" | jq -r .in)" "$(echo "$usage" | jq -r .cached_in)" "$(echo "$usage" | jq -r .out)" "$(echo "$usage" | jq -r .reasoning)" "$model" "$prices" 2>/dev/null)"; then :; else codex_cost="$(UNVERIFIED 'model not in price table')"; fi
      else
        codex="$(UNVERIFIED 'codex artifact absent')"; codex_cost="$(UNVERIFIED 'codex artifact absent')"
      fi
    fi
    # wallclock from meta
    if wc="$(meta_wallclock "$m" 2>/dev/null)"; then :; else
      badf="$(meta_wallclock "$m" 2>&1 | sed 's/^MALFORMED://')"; wc="$(UNVERIFIED "malformed meta $badf")"
    fi
    # cc_subagent cell (windows already complete)
    if [ "$otel_state" = absent ]; then
      cc_sub="$(UNVERIFIED 'subagent usage requires OTel')"
    else
      if cell="$(cc_subagent_cell "$rid" "$events" "$wins" 2>/dev/null)"; then cc_sub="$cell"; else cc_sub="$(UNVERIFIED 'no OTel subagent events for run')"; fi
    fi
    # dispatch_total = codex_cost + cc_subagent.cost; [unverified] if EITHER leg is — propagate the
    # FAILING leg's OWN closed-list reason verbatim (codex leg preferred if both). NEVER off-list. (C1)
    if echo "$codex_cost" | grep -q '^\[unverified'; then
      total="$codex_cost"
    elif echo "$cc_sub" | grep -q '^\[unverified'; then
      total="$cc_sub"
    else
      total="$(awk -v a="$codex_cost" -v b="$(echo "$cc_sub" | jq -r '.cost_usd')" 'BEGIN{printf "%.6f", a+b}')"
    fi
    # emit the per-run row; cells that are real JSON parse back, sentinel strings stay strings
    jq -nc --arg rid "$rid" --arg stage "$stage" --arg model "$model" \
      --arg codex "$codex" --arg cc "$cc_sub" --arg wc "$wc" --arg cc_cost "$codex_cost" --arg total "$total" \
      '{run_id:$rid, stage:$stage, model:$model,
        codex:        ($codex | (fromjson? // .)),
        cc_subagent:  ($cc    | (fromjson? // .)),
        wallclock_s:  ($wc    | (fromjson? // .)),
        codex_cost_usd: $cc_cost,
        dispatch_total_cost_usd: $total }'
  done <<< "$metas"
}

# build_session_summary <transcript> <costs> <otel> <session_id> <scope_assert>
build_session_summary() {
  local tr="$1" costs="$2" otel="$3" sid="$4" assert="$5"
  local cc_main sw agg unparse by_agent
  cc_main="$(mainloop_usage "$tr" 2>/dev/null || echo '{"in":0,"out":0}')"
  if sw="$(session_wallclock "$tr" 2>/dev/null)"; then :; else sw="$(UNVERIFIED 'malformed transcript timestamp')"; fi
  # costs aggregate (single correct assignment)
  local agg_json
  if agg_json="$(costs_aggregate "$costs" "$sid")"; then
    agg="$(echo "$agg_json" | jq -r .usd)"; unparse="$(echo "$agg_json" | jq -r .unparseable_lines)"
  else
    agg="$(UNVERIFIED 'costs aggregate lacks session scope')"
    unparse="$(echo "$agg_json" | awk '{print $2; exit}')"; unparse="${unparse:-0}"
  fi
  # by-agent rollup. Track groundedness with an EXPLICIT boolean — do NOT sniff the first
  # char: a sentinel string ALSO starts with `[`, so a first-char test would
  # feed invalid JSON to --argjson and the whole summary would fail to emit. (round-2 Critical)
  # Split `local events`/assignment so $? captures the subshell, not `local` (always 0).
  local by_is_json=false
  if [ -z "$otel" ]; then
    by_agent="$(UNVERIFIED 'subagent usage requires OTel')"
  else
    local events rc m_ts_wall
    events="$(otel_scoped_events "$otel" "$sid" "$assert")"
    rc=$?
    if [ "$rc" -eq 2 ]; then
      by_agent="$(UNVERIFIED 'subagent usage requires OTel')"
    elif echo "$events" | jq -e 'select(._unscoped==true)' >/dev/null 2>&1; then
      by_agent="$(UNVERIFIED 'OTel events lack session scope')"
    else
      # wall_span_s per agent.name = max(ts) - min(ts); sentinel when any ts is non-numeric.
      # Derived from RAW scoped events
      # (the COMPLETE superset), INCLUDING events the per-run attribution drops.
      m_ts_wall="$(UNVERIFIED 'malformed OTel timestamp')"
      by_agent="$(echo "$events" | jq -s --arg mts "$m_ts_wall" '
        group_by(.agent_name) | map(
          ( [ .[] | .ts ] ) as $ts
          | { agent_name: .[0].agent_name,
              tokens: (map(.tokens // 0) | add),
              cost_usd: (map(.cost_usd // 0) | add),
              event_count: length,
              wall_span_s: ( if ($ts | map(type=="number") | all)
                             then (($ts|max) - ($ts|min))
                             else $mts end ) } )')"
      by_is_json=true
    fi
  fi
  local by_json
  if "$by_is_json"; then by_json="$by_agent"; else by_json="$(jq -nc --arg s "$by_agent" '$s')"; fi
  jq -nc --argjson cc "$cc_main" --arg agg "$agg" --arg sw "$sw" --argjson un "${unparse:-0}" \
    --argjson by "$by_json" \
    '{cc_main:$cc, costs_aggregate_usd:$agg, session_wallclock_s:$sw, by_agent:$by, unparseable_lines:$un}'
}

usage() { echo "usage: metrics-report.sh --session <id|path> --collection <dir> [--session-id <id>] [--otel <p>] [--otel-session-scope <s>] [--prices <p>] [--costs <p>]" >&2; }

main() {
  local session="" collection="" otel="" scope="" prices="" costs="" sid_override=""
  # every value-taking flag guards that an operand exists BEFORE reading $2, so
  # `metrics-report.sh --session` returns the usage code 2, not an `unbound variable`
  # abort under `set -u`. (M-new-1)
  while [ $# -gt 0 ]; do
    case "$1" in
      --session)             [ $# -ge 2 ] || { usage; return 2; }; session="$2"; shift 2;;
      --session-id)          [ $# -ge 2 ] || { usage; return 2; }; sid_override="$2"; shift 2;;
      --collection)          [ $# -ge 2 ] || { usage; return 2; }; collection="$2"; shift 2;;
      --otel)                [ $# -ge 2 ] || { usage; return 2; }; otel="$2"; shift 2;;
      --otel-session-scope)  [ $# -ge 2 ] || { usage; return 2; }; scope="$2"; shift 2;;
      --prices)              [ $# -ge 2 ] || { usage; return 2; }; prices="$2"; shift 2;;
      --costs)               [ $# -ge 2 ] || { usage; return 2; }; costs="$2"; shift 2;;
      *) usage; return 2;;
    esac
  done
  if [ -z "$collection" ] || [ ! -d "$collection" ]; then
    echo "error: --collection dir missing/empty" >&2; return 2
  fi
  if [ -z "$session" ] || [ ! -f "$session" ]; then
    echo "error: --session transcript not found" >&2; return 2
  fi
  [ -z "$prices" ] && prices="$(dirname "$0")/metrics/model-prices.json"
  [ -z "$costs" ] && costs="$HOME/.claude/metrics/costs.jsonl"
  # session id: explicit --session-id wins (it must match the OTel sink's real session UUID);
  # else fall back to the transcript filename stem (best-effort — see Risks).
  local sid
  if [ -n "$sid_override" ]; then sid="$sid_override"; else sid="$(basename "$session" | sed 's/\.[^.]*$//')"; fi
  # per-run rows (propagates duplicate run_id hard error → exit 1)
  local rows
  if ! rows="$(build_per_run_rows "$collection" "$prices" "$otel" "$sid" "$scope")"; then
    echo "error: duplicate run_id in collection" >&2; return 1
  fi
  echo "$rows"
  # per-run-reporting honesty: events that match zero / multiple windows (or carry a bad ts)
  # are surfaced with their distinct closed-list markers — never silently dropped.
  local diag
  diag="$(otel_diagnostics "$collection" "$otel" "$sid" "$scope")"
  if [ -n "$diag" ]; then echo "=== OTEL EVENT DIAGNOSTICS ==="; echo "$diag"; fi
  echo "=== SESSION SUMMARY ==="
  build_session_summary "$session" "$costs" "$otel" "$sid" "$scope"
  if [ -z "$otel" ]; then
    echo "WARNING: CC-subagent figures are [unverified] — no OTel sink supplied. See README § OTel setup." >&2
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
