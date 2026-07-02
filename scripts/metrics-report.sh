#!/usr/bin/env bash
# metrics-report.sh — on-demand token/cost/wall-clock report for the auto-run gate skills
# (design-spec / design-review / anvil). Reads DURABLE logs only; dispatches no LLM.
#
# Sources: run-manifests (hook-stamped, ${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs)
# define per-run windows (each ends at the next run's START; the last run at report-time `now`);
# CC-subagent cost <- OTel (keyed by session.id); Codex cost <- ~/.codex/sessions rollouts (keyed by
# cwd + window + originator=codex_exec); main-loop <- the session transcript. Any ungrounded cell is
# a closed-list unverified marker (see UNVERIFIED) — never a fabricated number or a silent zero.
#
# SCOPE LIMIT: Codex attribution is cwd+window-keyed → reliable only with <=1 active session per
# literal cwd at a time. Separate git worktrees (distinct cwd) are fine; two concurrent sessions in
# the SAME directory path are out of scope (CC/OTel figures, keyed by session.id, are unaffected).
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

# codex_rollout_usage <rollout_file> → {model,in,cached_in,out,reasoning} OR prints MISSING + return 1
# Reads a Codex durable session log (~/.codex/sessions/**/rollout-*.jsonl). Unlike a raw
# `codex exec --json` stream (turn.completed events, SUMMED), a rollout carries cumulative
# `token_count` events — the LAST one is the session total, so we take last (not sum). Model
# comes from the `turn_context` event.
codex_rollout_usage() {
  local f="$1" out
  [ -r "$f" ] || { echo MISSING; return 1; }
  out="$(jq -cs '
    (map(select(.type=="turn_context") | .model) | map(select(. != null)) | last) as $model
    | (map(select(.type=="event_msg" and .payload.type=="token_count")
           | .payload.info.total_token_usage) | map(select(. != null)) | last) as $u
    | if $u == null then "MISSING"
      else { model:     ($model // ""),
             in:        ($u.input_tokens // 0),
             cached_in: ($u.cached_input_tokens // 0),
             out:       ($u.output_tokens // 0),
             reasoning: ($u.reasoning_output_tokens // 0) }
      end' "$f" 2>/dev/null)"
  if [ -z "$out" ] || [ "$out" = '"MISSING"' ] || [ "$out" = null ]; then echo MISSING; return 1; fi
  echo "$out"
}

# codex_rollouts_in_window <cwd> <start_epoch> <end_epoch> → rollout paths, one per line
# Selects Codex rollouts attributable to a run: session_meta.cwd matches, originator=codex_exec
# (programmatic dispatch, not interactive), and session start timestamp in the half-open window.
# SCOPE LIMIT: cwd-keyed — reliable only with <=1 active session per literal cwd at a time.
# CODEX_SESSIONS_DIR overrides the scan root (default ~/.codex/sessions) for tests.
codex_rollouts_in_window() {
  local cwd="$1" start="$2" end="$3"
  local root="${CODEX_SESSIONS_DIR:-$HOME/.codex/sessions}"
  [ -d "$root" ] || return 0
  local f meta rcwd rorig rts rep
  while IFS= read -r f; do
    meta="$(head -1 "$f" 2>/dev/null)"
    rcwd="$(printf '%s' "$meta" | jq -r 'select(.type=="session_meta") | .payload.cwd // empty' 2>/dev/null)"
    [ "$rcwd" = "$cwd" ] || continue
    rorig="$(printf '%s' "$meta" | jq -r '.payload.originator // empty' 2>/dev/null)"
    [ "$rorig" = "codex_exec" ] || continue
    rts="$(printf '%s' "$meta" | jq -r '.payload.timestamp // empty' 2>/dev/null)"
    # rollout timestamps carry millis (…:13.565Z); iso_to_epoch's BSD path wants no fraction.
    rts="$(printf '%s' "$rts" | sed 's/\.[0-9]*Z$/Z/')"
    rep="$(iso_to_epoch "$rts" 2>/dev/null)" || continue
    awk -v t="$rep" -v a="$start" -v b="$end" 'BEGIN{ exit !(t>=a && t<b) }' && echo "$f"
  done < <(find "$root" -type f -name 'rollout-*.jsonl' 2>/dev/null)
}

# codex_window_aggregate <cwd> <start_epoch> <end_epoch> <prices> → "<usage_json>\t<cost>"
# Sums Codex usage over ALL rollouts attributable to a run's window (0-all if none — a grounded
# zero: V1 established every `codex exec` writes a rollout, so no rollout in-window means no codex
# ran, NOT missing data — valid only within the 1-cwd-1-session scope limit). cost = summed USD;
# if ANY rollout's model is absent from the price table, the whole cost propagates that ONE
# closed-list sentinel (a total missing a leg is never half-claimed). Uses `< <(...)` so the loop
# accumulates in THIS shell (a pipe would subshell the sums away).
codex_window_aggregate() {
  local cwd="$1" start="$2" end="$3" prices="$4"
  local root="${CODEX_SESSIONS_DIR:-$HOME/.codex/sessions}"
  local zero; zero="$(jq -nc '{in:0,cached_in:0,out:0,reasoning:0}')"
  # Absent/unreadable scan root ≠ "scanned, found none". We cannot claim a grounded zero when the
  # durable source itself is missing — that would fabricate zero over ungrounded state. (Codex H1)
  if [ ! -d "$root" ] || [ ! -r "$root" ] || [ ! -x "$root" ]; then
    printf '%s\t%s\n' "$zero" "$(UNVERIFIED 'codex artifact absent')"; return 0
  fi
  local in=0 cached=0 out=0 reason=0 cost=0 unv="" f u m c
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # A rollout matched the window (a codex exec DID run here) but is unreadable/malformed → we
    # cannot drop it silently (that understates the total). Poison the whole leg. (Codex H2)
    if ! u="$(codex_rollout_usage "$f" 2>/dev/null)"; then unv="$(UNVERIFIED 'malformed meta codex-rollout')"; continue; fi
    in=$((     in     + $(echo "$u" | jq -r '.in // 0') ))
    cached=$(( cached + $(echo "$u" | jq -r '.cached_in // 0') ))
    out=$((    out    + $(echo "$u" | jq -r '.out // 0') ))
    reason=$(( reason + $(echo "$u" | jq -r '.reasoning // 0') ))
    m="$(echo "$u" | jq -r '.model // ""')"
    if c="$(compute_codex_cost "$(echo "$u"|jq -r .in)" "$(echo "$u"|jq -r .cached_in)" "$(echo "$u"|jq -r .out)" "$(echo "$u"|jq -r .reasoning)" "$m" "$prices" 2>/dev/null)"; then
      cost="$(awk -v a="$cost" -v b="$c" 'BEGIN{printf "%.6f", a+b}')"
    else
      unv="$(UNVERIFIED 'model not in price table')"
    fi
  done < <(codex_rollouts_in_window "$cwd" "$start" "$end")
  local usage
  usage="$(jq -nc --argjson i "$in" --argjson c "$cached" --argjson o "$out" --argjson r "$reason" \
    '{in:$i, cached_in:$c, out:$o, reasoning:$r}')"
  if [ -n "$unv" ]; then printf '%s\t%s\n' "$usage" "$unv"; else printf '%s\t%s\n' "$usage" "$cost"; fi
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

# build_windows_v2 <session_id> <now_epoch> → TSV `run_id<TAB>start<TAB>end<TAB>cwd<TAB>skill`
# v2 run-manifest window model. Reads ${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs/*.json
# (run-manifest/v1: run_id, skill, session_id, cwd, started_at — NO ended_at). Sorted by started_at,
# each run's END = the NEXT run's START (the sequential main loop guarantees the prior gate finished
# before the user typed the next), and the LAST run's END = <now_epoch> (the report-invocation time —
# the one open run has no successor). No idle-gap threshold: a slow Codex review can never truncate a
# run mid-flight. Only session-matching manifests are windowed.
build_windows_v2() {
  local sid="$1" now="$2"
  local dir="${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs"
  [ -d "$dir" ] || return 0
  local sorted m sa rid cwd skill ep
  sorted="$(
    shopt -s nullglob
    for m in "$dir"/*.json; do
      jq -r --arg sid "$sid" \
        'select((.session_id // "") == $sid or ($sid == ""))
         | [ (.started_at // ""), (.run_id // ""), (.cwd // ""), (.skill // "") ] | @tsv' \
        "$m" 2>/dev/null
    done | while IFS=$'\t' read -r sa rid cwd skill; do
      [ -n "$rid" ] || continue
      ep="$(iso_to_epoch "$sa" 2>/dev/null)" || continue
      printf '%s\t%s\t%s\t%s\n' "$ep" "$rid" "$cwd" "$skill"
    done | sort -n
  )"
  [ -n "$sorted" ] || return 0
  local -a lines=()
  while IFS= read -r ln; do [ -n "$ln" ] && lines+=("$ln"); done <<< "$sorted"
  local n=${#lines[@]} i j endep nep rest
  for (( i=0; i<n; i++ )); do
    IFS=$'\t' read -r ep rid cwd skill <<< "${lines[$i]}"
    # END = the next STRICTLY-GREATER start (not merely the next line). Two gates stamped in the same
    # whole second thus get overlapping [T, next_distinct) windows → events attribute AMBIGUOUS and are
    # surfaced as [unverified], never silently handed to the second run via a zero-length first. (Codex M1)
    endep="$now"
    for (( j=i+1; j<n; j++ )); do
      IFS=$'\t' read -r nep rest <<< "${lines[$j]}"
      if [ "$nep" -gt "$ep" ]; then endep="$nep"; break; fi
    done
    printf '%s\t%s\t%s\t%s\t%s\n' "$rid" "$ep" "$endep" "$cwd" "$skill"
  done
}

# otel_diagnostics <otel> <sid> <assert> <now_epoch> → per-event closed-list markers for the
# events that DON'T land in exactly one run window — so the per-run-reporting honesty requirement
# is met. Emits one JSON line per flagged event: malformed-ts, unattributed, or ambiguous.
otel_diagnostics() {
  local otel="$1" sid="$2" assert="$3" now="$4"
  [ -z "$otel" ] && return 0
  local events rc; events="$(otel_scoped_events "$otel" "$sid" "$assert")"; rc=$?; [ "$rc" -eq 2 ] && return 0
  local wins; wins="$(build_windows_v2 "$sid" "$now" | awk -F'\t' 'NF>=3{print $1"\t"$2"\t"$3}')"
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

# build_per_run_rows_v2 <prices> <otel> <session_id> <scope_assert> <now_epoch>
# v2 per-run rows: run-manifest windows (build_windows_v2) × durable-log harvest. Each row:
#   { run_id, skill, codex:{in,cached_in,out,reasoning}, cc_subagent:{tokens,cost_usd},
#     wallclock_s, codex_cost_usd, dispatch_total_cost_usd }
# wallclock is DERIVED from the window (end-start) — no meta.ended_at. codex from ~/.codex/sessions
# (cwd+window); cc_subagent from OTel (window attribution, reusing cc_subagent_cell). dispatch_total
# propagates the FAILING leg's own closed-list sentinel (codex leg preferred if both).
build_per_run_rows_v2() {
  local prices="$1" otel="$2" sid="$3" assert="$4" now="$5"
  local wins5; wins5="$(build_windows_v2 "$sid" "$now")"
  [ -n "$wins5" ] || return 0
  # 3-col window TSV (run_id start end) for OTel attribution reuse
  local wins3; wins3="$(printf '%s\n' "$wins5" | awk -F'\t' 'NF>=3{print $1"\t"$2"\t"$3}')"
  local events="" otel_state="present" rc
  if [ -n "$otel" ]; then
    events="$(otel_scoped_events "$otel" "$sid" "$assert")"; rc=$?
    [ "$rc" -eq 2 ] && otel_state="absent"
  else
    otel_state="absent"
  fi
  local rid s e cwd skill wc agg codex codex_cost cc_sub cell total
  while IFS=$'\t' read -r rid s e cwd skill; do
    [ -z "$rid" ] && continue
    wc=$(( e - s ))
    agg="$(codex_window_aggregate "$cwd" "$s" "$e" "$prices")"
    codex="$(printf '%s' "$agg" | cut -f1)"
    codex_cost="$(printf '%s' "$agg" | cut -f2)"
    if [ "$otel_state" = absent ]; then
      cc_sub="$(UNVERIFIED 'subagent usage requires OTel')"
    else
      if cell="$(cc_subagent_cell "$rid" "$events" "$wins3" 2>/dev/null)"; then cc_sub="$cell"; else cc_sub="$(UNVERIFIED 'no OTel subagent events for run')"; fi
    fi
    if echo "$codex_cost" | grep -q '^\[unverified'; then
      total="$codex_cost"
    elif echo "$cc_sub" | grep -q '^\[unverified'; then
      total="$cc_sub"
    else
      total="$(awk -v a="$codex_cost" -v b="$(echo "$cc_sub" | jq -r '.cost_usd')" 'BEGIN{printf "%.6f", a+b}')"
    fi
    jq -nc --arg rid "$rid" --arg skill "$skill" --arg codex "$codex" --arg cc "$cc_sub" \
      --argjson wc "$wc" --arg cc_cost "$codex_cost" --arg total "$total" \
      '{run_id:$rid, skill:$skill,
        codex:        ($codex | (fromjson? // .)),
        cc_subagent:  ($cc    | (fromjson? // .)),
        wallclock_s:  $wc,
        codex_cost_usd: $cc_cost,
        dispatch_total_cost_usd: $total }'
  done <<< "$wins5"
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

usage() { echo "usage: metrics-report.sh --session-id <id> [--session <transcript>] [--otel <p>] [--otel-session-scope <s>] [--prices <p>] [--costs <p>] [--now <epoch>]" >&2
  echo "  run-manifests read from \${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs; Codex from ~/.codex/sessions (\$CODEX_SESSIONS_DIR override)." >&2; }

main() {
  local session="" otel="" scope="" prices="" costs="" sid_override="" now_override=""
  # every value-taking flag guards that an operand exists BEFORE reading $2, so a trailing bare
  # flag returns the usage code 2, not an `unbound variable` abort under `set -u`.
  while [ $# -gt 0 ]; do
    case "$1" in
      --session)             [ $# -ge 2 ] || { usage; return 2; }; session="$2"; shift 2;;
      --session-id)          [ $# -ge 2 ] || { usage; return 2; }; sid_override="$2"; shift 2;;
      --otel)                [ $# -ge 2 ] || { usage; return 2; }; otel="$2"; shift 2;;
      --otel-session-scope)  [ $# -ge 2 ] || { usage; return 2; }; scope="$2"; shift 2;;
      --prices)              [ $# -ge 2 ] || { usage; return 2; }; prices="$2"; shift 2;;
      --costs)               [ $# -ge 2 ] || { usage; return 2; }; costs="$2"; shift 2;;
      --now)                 [ $# -ge 2 ] || { usage; return 2; }; now_override="$2"; shift 2;;
      *) usage; return 2;;
    esac
  done
  # session id: explicit --session-id wins (must match the OTel sink's real session UUID); else
  # fall back to the transcript filename stem. One of the two must be present to scope the report.
  local sid
  if [ -n "$sid_override" ]; then sid="$sid_override"
  elif [ -n "$session" ] && [ -f "$session" ]; then sid="$(basename "$session" | sed 's/\.[^.]*$//')"
  else echo "error: --session-id (or a --session transcript to derive it) is required" >&2; return 2; fi
  [ -z "$prices" ] && prices="$(dirname "$0")/metrics/model-prices.json"
  [ -z "$costs" ] && costs="$HOME/.claude/metrics/costs.jsonl"
  # END of the last (open) run = report-invocation time; --now overrides for deterministic tests.
  local now; now="${now_override:-$(date +%s)}"
  # per-run rows over the run-manifest windows
  build_per_run_rows_v2 "$prices" "$otel" "$sid" "$scope" "$now"
  # per-run-reporting honesty: events matching zero / multiple windows (or a bad ts) are surfaced
  # with their distinct closed-list markers — never silently dropped.
  local diag; diag="$(otel_diagnostics "$otel" "$sid" "$scope" "$now")"
  if [ -n "$diag" ]; then echo "=== OTEL EVENT DIAGNOSTICS ==="; echo "$diag"; fi
  # session summary needs the transcript (main-loop usage + session wallclock); skip if absent.
  if [ -n "$session" ] && [ -f "$session" ]; then
    echo "=== SESSION SUMMARY ==="
    build_session_summary "$session" "$costs" "$otel" "$sid" "$scope"
  fi
  if [ -z "$otel" ]; then
    echo "WARNING: CC-subagent figures are [unverified] — no OTel sink supplied." >&2
    echo "         Deploy the persistent collector once: bash scripts/metrics/setup-otel.sh (then open a new shell / restart CC)." >&2
    echo "         Until then subagent tokens are never captured in a real session (README § OTel setup)." >&2
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then main "$@"; fi
