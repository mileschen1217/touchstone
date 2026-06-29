#!/usr/bin/env bash
# Deterministic tests for the metrics-capture report tool + owned writer.
# Covers AC-1..AC-29 except AC-23 (live-bearing — see test note in that task).
# SC2015: && ok || fail idiom is intentional (ok/fail are counter+echo, not exit-zero guards).
# SC2034: WRITER/FIX/PRICES are scaffolded for later tasks (Task 2+), not yet referenced.
# shellcheck disable=SC2015,SC2034
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="$REPO_ROOT/scripts/metrics-report.sh"
WRITER="$REPO_ROOT/scripts/metrics/persist-dispatch.sh"
PRICES="$REPO_ROOT/scripts/metrics/model-prices.json"
FIX="$REPO_ROOT/scripts/tests/fixtures/metrics"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
# shellcheck source=/dev/null
source "$TOOL"   # source-guard keeps main() from running

# --- AC-7: price table applied; reasoning billed as output ---
# opus: in=1e6 cached=0 out=1e6 reasoning=1e6 → 15 + 0 + (1+1)*75 = 165.0
got="$(compute_codex_cost 1000000 0 1000000 1000000 claude-opus-4-8 "$PRICES")"
[ "$got" = "165.000000" ] && ok "AC-7 reasoning billed at output rate" || fail "AC-7 got=$got want=165.000000"

# --- AC-8: unknown model → MISSING_PRICE ---
if compute_codex_cost 100 0 100 0 no-such-model "$PRICES" >/dev/null 2>&1; then
  fail "AC-8 unpriced model should fail"
else
  ok "AC-8 unpriced model returns MISSING_PRICE"
fi

# --- AC-16/18: writer persists codex+meta pair with full attribution ---
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '{"type":"turn.completed","usage":{"input_tokens":10,"output_tokens":5}}\n' > "$TMP/raw.jsonl"
rec="$("$WRITER" "$TMP/raw.jsonl" "$TMP/col" design-review claude-opus-4-8 2026-06-29T10:00:00Z 2026-06-29T10:01:00Z)"
rid="$(echo "$rec" | jq -r .run_id)"
cdir="$(echo "$rec" | jq -r .collection_dir)"
[ -f "$TMP/col/$rid.meta.json" ] && ok "AC-16 meta written" || fail "AC-16 meta missing"
[ -f "$TMP/col/$rid.codex.jsonl" ] && ok "AC-16 codex copied" || fail "AC-16 codex missing"
[ "$cdir" = "$TMP/col" ] && ok "AC-22-echo collection_dir echoed verbatim" || fail "echo got=$cdir"
m="$TMP/col/$rid.meta.json"
[ "$(jq -r .stage "$m")" = design-review ] && [ "$(jq -r .model "$m")" = claude-opus-4-8 ] \
  && [ "$(jq -r .started_at "$m")" = 2026-06-29T10:00:00Z ] && [ "$(jq -r .ended_at "$m")" = 2026-06-29T10:01:00Z ] \
  && [ "$(jq -r .codex_artifact_path "$m")" = "$rid.codex.jsonl" ] \
  && [ "$(jq -r '.providers_used|join(",")' "$m")" = cc,codex ] \
  && ok "AC-18 meta carries full attribution record" || fail "AC-18 meta fields wrong"

# --- AC-17: collision-resistant across back-to-back invocations ---
r1="$("$WRITER" "$TMP/raw.jsonl" "$TMP/c2" s m 2026-06-29T10:00:00Z 2026-06-29T10:00:01Z | jq -r .run_id)"
r2="$("$WRITER" "$TMP/raw.jsonl" "$TMP/c2" s m 2026-06-29T10:00:00Z 2026-06-29T10:00:01Z | jq -r .run_id)"
[ "$r1" != "$r2" ] && [ -f "$TMP/c2/$r1.meta.json" ] && [ -f "$TMP/c2/$r2.meta.json" ] \
  && ok "AC-17 distinct run_ids, no overwrite" || fail "AC-17 collision r1=$r1 r2=$r2"

# --- AC-24: --no-codex fallback persists meta-only run ---
rec3="$("$WRITER" --no-codex --fallback-reason "codex unhealthy" "$TMP/c3" s claude-opus-4-8 2026-06-29T10:00:00Z 2026-06-29T10:00:01Z)"
rid3="$(echo "$rec3" | jq -r .run_id)"; m3="$TMP/c3/$rid3.meta.json"
[ ! -f "$TMP/c3/$rid3.codex.jsonl" ] && [ "$(jq -r .codex_artifact_path "$m3")" = null ] \
  && [ "$(jq -r '.providers_used|join(",")' "$m3")" = cc ] \
  && [ "$(jq -r .fallback_reason "$m3")" = "codex unhealthy" ] \
  && ok "AC-24 no-codex meta-only run" || fail "AC-24 fallback meta wrong"

# --- AC-22 seam: writer stdout is EXACTLY one JSON line with exactly {run_id, collection_dir} ---
raw_out="$("$WRITER" "$TMP/raw.jsonl" "$TMP/c4" s claude-opus-4-8 2026-06-29T10:00:00Z 2026-06-29T10:00:01Z)"
[ "$(printf '%s' "$raw_out" | wc -l | tr -d ' ')" = 0 ] && [ "$(printf '%s\n' "$raw_out" | wc -l | tr -d ' ')" = 1 ] \
  && ok "AC-22 writer emits exactly one stdout line" || fail "AC-22 stdout not single line: [$raw_out]"
[ "$(printf '%s' "$raw_out" | jq -rc '[keys[]]|sort|join(",")')" = "collection_dir,run_id" ] \
  && ok "AC-22 stdout record carries exactly run_id+collection_dir" || fail "AC-22 stdout keys wrong: $raw_out"

# --- AC-1: codex usage summed across turn.completed events ---
cx="$TMP/c.jsonl"
printf '%s\n' \
 '{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":10,"output_tokens":50,"reasoning_output_tokens":30}}' \
 '{"type":"other","usage":{"input_tokens":999}}' \
 '{"type":"turn.completed","usage":{"input_tokens":5,"cached_input_tokens":1,"output_tokens":2,"reasoning_output_tokens":1}}' > "$cx"
u="$(codex_usage "$cx")"
[ "$(echo "$u" | jq -r '.in')" = 105 ] && [ "$(echo "$u" | jq -r '.cached_in')" = 11 ] \
  && [ "$(echo "$u" | jq -r '.out')" = 52 ] && [ "$(echo "$u" | jq -r '.reasoning')" = 31 ] \
  && ok "AC-1 codex usage summed from turn.completed" || fail "AC-1 got=$u"
# missing file → MISSING
if codex_usage "$TMP/nope.jsonl" >/dev/null 2>&1; then fail "AC-10 missing codex should fail"; else ok "AC-10 missing codex → MISSING"; fi

# --- AC-2: one meta path per sidecar; meta set is the run index ---
col="$TMP/runs"; mkdir -p "$col"
"$WRITER" "$TMP/raw.jsonl" "$col" pass1 claude-opus-4-8 2026-06-29T10:00:00Z 2026-06-29T10:01:00Z >/dev/null
"$WRITER" "$TMP/raw.jsonl" "$col" pass2 claude-opus-4-8 2026-06-29T10:02:00Z 2026-06-29T10:03:30Z >/dev/null
n="$(resolve_runs "$col" | wc -l | tr -d ' ')"
[ "$n" = 2 ] && ok "AC-2 two metas → two runs" || fail "AC-2 got n=$n"

# --- AC-25: duplicate run_id is a deterministic hard error naming both paths ---
dcol="$TMP/dup"; mkdir -p "$dcol"
printf '{"run_id":"X","codex_artifact_path":null,"stage":"a","model":"m","started_at":"t","ended_at":"t","providers_used":["cc"],"fallback_reason":null}' > "$dcol/a.meta.json"
printf '{"run_id":"X","codex_artifact_path":null,"stage":"b","model":"m","started_at":"t","ended_at":"t","providers_used":["cc"],"fallback_reason":null}' > "$dcol/b.meta.json"
err="$(resolve_runs "$dcol" 2>&1 >/dev/null)"; rc=$?
[ "$rc" != 0 ] && echo "$err" | grep -q a.meta.json && echo "$err" | grep -q b.meta.json \
  && ok "AC-25 duplicate run_id hard error names both" || fail "AC-25 rc=$rc err=$err"

# --- AC-4: per-run wall-clock from meta (exact, non-vacuous); malformed names the field ---
firstmeta="$(resolve_runs "$col" | head -1)"   # pass1: 10:00:00 → 10:01:00 = 60s
wc4="$(meta_wallclock "$firstmeta")"
[ "$wc4" = 60 ] && ok "AC-4 wallclock = ended-started (exact 60s)" || fail "AC-4 got=$wc4 want=60"
bad="$TMP/bad.meta.json"; printf '{"run_id":"Y","started_at":"2026-06-29T10:00:00Z"}' > "$bad"
w="$(meta_wallclock "$bad" 2>&1)"; rc=$?
[ "$rc" != 0 ] && echo "$w" | grep -q ended_at && ok "AC-4 malformed names offending field" || fail "AC-4 got=$w rc=$rc"

# --- AC-3: main-loop sums only isSidechain false/absent ---
tr="$TMP/transcript.jsonl"
printf '%s\n' \
 '{"type":"assistant","timestamp":"2026-06-29T10:00:00Z","message":{"usage":{"input_tokens":100,"output_tokens":40}}}' \
 '{"type":"assistant","isSidechain":true,"timestamp":"2026-06-29T10:00:30Z","message":{"usage":{"input_tokens":999,"output_tokens":999}}}' \
 '{"type":"assistant","isSidechain":false,"timestamp":"2026-06-29T10:05:00Z","message":{"usage":{"input_tokens":20,"output_tokens":10}}}' > "$tr"
ml="$(mainloop_usage "$tr")"
[ "$(echo "$ml" | jq -r .in)" = 120 ] && [ "$(echo "$ml" | jq -r .out)" = 50 ] \
  && ok "AC-3 main-loop excludes sidechain" || fail "AC-3 got=$ml"
# --- AC-21: session wallclock; malformed → unverified marker ---
sw="$(session_wallclock "$tr")"
[ "$sw" = 300 ] && ok "AC-21 session wallclock = last-first" || fail "AC-21 got=$sw"
badtr="$TMP/badtr.jsonl"; printf '%s\n' '{"type":"assistant","message":{"usage":{}}}' '{"type":"assistant","timestamp":"nope","message":{"usage":{}}}' > "$badtr"
if session_wallclock "$badtr" >/dev/null 2>&1; then fail "AC-21 malformed should fail"; else ok "AC-21 malformed transcript ts → MALFORMED"; fi

# --- AC-6: costs.jsonl single-scope sums only target session ---
co="$TMP/costs.jsonl"
printf '%s\n' \
 '{"session_id":"S1","input_tokens":100,"output_tokens":50,"cost_usd":0.5}' \
 '{"session_id":"S2","input_tokens":999,"output_tokens":999,"cost_usd":9.9}' \
 'not json' \
 '{"session_id":"S1","input_tokens":10,"output_tokens":5,"cost_usd":0.25}' > "$co"
agg="$(costs_aggregate "$co" S1)"
[ "$(echo "$agg" | jq -r .usd)" = 0.75 ] && ok "AC-6 single-scope sums only target" || fail "AC-6 got=$agg"
# unparseable counts the 'not json' line, NOT the out-of-session S2 row
[ "$(echo "$agg" | jq -r .unparseable_lines)" = 1 ] && ok "AC-6 scope-excluded row not unparseable" || fail "AC-6 unparseable wrong: $agg"
# --- AC-6: no-scope file → NOSCOPE + stderr note ---
co2="$TMP/costs2.jsonl"; printf '%s\n' '{"input_tokens":100,"output_tokens":50,"cost_usd":0.5}' > "$co2"
note="$(costs_aggregate "$co2" S1 2>&1 >/dev/null)"; rc=$?
[ "$rc" != 0 ] && echo "$note" | grep -qi "session scope" && ok "AC-6 no-scope → NOSCOPE + note" || fail "AC-6 noscope rc=$rc note=$note"
# --- AC-6: mixed-schema → NOSCOPE ---
co3="$TMP/costs3.jsonl"; printf '%s\n' '{"session_id":"S1","input_tokens":1,"output_tokens":1}' '{"input_tokens":1,"output_tokens":1}' > "$co3"
if costs_aggregate "$co3" S1 >/dev/null 2>&1; then fail "AC-6 mixed-schema should be NOSCOPE"; else ok "AC-6 mixed-schema → NOSCOPE"; fi

# --- G-2 (regression): unparseable_lines preserved through build_session_summary when costs NOSCOPE ---
# A NOSCOPE costs file WITH malformed lines: the count must survive the NOSCOPE else-branch.
co_ns_bad="$TMP/costs_ns_bad.jsonl"
printf '%s\n' '{"input_tokens":100,"output_tokens":50,"cost_usd":0.5}' 'not json' > "$co_ns_bad"
sum_ns="$(build_session_summary "$tr" "$co_ns_bad" "" SES "" 2>/dev/null)"
[ "$(echo "$sum_ns" | jq -r .unparseable_lines)" = 1 ] \
  && ok "G-2 unparseable_lines=1 preserved through NOSCOPE else-branch" \
  || fail "G-2 unparseable_lines wrong: $(echo "$sum_ns" | jq -r .unparseable_lines)"

# --- AC-15: OTel scoping — matching included, foreign excluded, unscoped marked ---
ot="$TMP/otel.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"reviewer","tokens":100,"cost_usd":0.1,"ts":1000}' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"OTHER","agent_name":"reviewer","tokens":900,"cost_usd":0.9,"ts":1000}' \
 '{"name":"claude_code.api_request","query_source":"main","session_id":"SES","agent_name":"orchestrator","tokens":50,"cost_usd":0.05,"ts":1000}' > "$ot"
n="$(otel_scoped_events "$ot" SES "" | wc -l | tr -d ' ')"
[ "$n" = 1 ] && ok "AC-15 only matching-session subagent event included" || fail "AC-15 got n=$n"
# unscoped event marked _unscoped without an --otel-session-scope assertion
ot2="$TMP/otel2.jsonl"; printf '%s\n' '{"name":"claude_code.api_request","query_source":"subagent","agent_name":"r","tokens":1,"cost_usd":0.01,"ts":1}' > "$ot2"
u="$(otel_scoped_events "$ot2" SES "")"
[ "$(echo "$u" | jq -r '._unscoped')" = true ] && ok "AC-15 unscoped event marked" || fail "AC-15 unscoped got=$u"
# with scope assertion, unscoped event is included as scoped
u2="$(otel_scoped_events "$ot2" SES SES)"
[ "$(echo "$u2" | jq -r '._unscoped // false')" = false ] && ok "AC-15 scope assertion includes unscoped" || fail "AC-15 assert got=$u2"
# absent file → typed no-data (return 2)
otel_scoped_events "$TMP/nofile" SES "" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "AC-9 absent OTel → typed no-data" || fail "AC-9 no-data rc wrong"

# --- AC-20: half-open containment, touching → later run, zero/multi distinguished ---
# windows: r1 [100,200)  r2 [200,300)  (touch at 200);  r3 [150,250) overlaps r2 for genuine ambiguity
win="$(printf 'r1\t100\t200\nr2\t200\t300\n')"
[ "$(attribute_event 150 "$win")" = r1 ] && ok "AC-20 inside r1" || fail "AC-20 inside r1"
[ "$(attribute_event 200 "$win")" = r2 ] && ok "AC-20 touching boundary → later run" || fail "AC-20 boundary"
[ "$(attribute_event 50  "$win")" = UNATTRIBUTED ] && ok "AC-20 no window → UNATTRIBUTED" || fail "AC-20 zero"
win2="$(printf 'r2\t200\t300\nr3\t150\t250\n')"
[ "$(attribute_event 220 "$win2")" = AMBIGUOUS ] && ok "AC-20 overlap → AMBIGUOUS" || fail "AC-20 multi"
# --- AC-14: cc_subagent cell sums attributed events across agent.names ---
ev="$(printf '%s\n' \
 '{"agent_name":"reviewer","tokens":100,"cost_usd":0.10,"ts":150}' \
 '{"agent_name":"architect","tokens":40,"cost_usd":0.04,"ts":160}' \
 '{"agent_name":"reviewer","tokens":5,"cost_usd":0.005,"ts":50}')"
cell="$(cc_subagent_cell r1 "$ev" "$win")"
[ "$(echo "$cell" | jq -r .tokens)" = 140 ] && ok "AC-14 cc_subagent summed over names" || fail "AC-14 got=$cell"
# --- AC-12: OTel present but run has zero subagent events → NOEVENTS ---
if cc_subagent_cell r2 "$ev" "$win" >/dev/null 2>&1; then fail "AC-12 should be NOEVENTS"; else ok "AC-12 zero events → NOEVENTS"; fi
# --- H8: float/ms epoch timestamp attributes correctly (not a spurious UNATTRIBUTED) ---
[ "$(attribute_event 150.5 "$win")" = r1 ] && ok "H8 float ts attributes to r1" || fail "H8 float ts"
# malformed numeric edges ('.', multi-dot) must NOT coerce into a window
[ "$(attribute_event . "$win")" = UNATTRIBUTED ] && [ "$(attribute_event 1.2.3 "$win")" = UNATTRIBUTED ] \
  && ok "H8 malformed numeric ts rejected (., 1.2.3)" || fail "H8 malformed numeric not rejected"
# --- H6: a real zero-token matched event is NOT NOEVENTS ---
zev='{"agent_name":"reviewer","tokens":0,"cost_usd":0,"ts":150}'
zc="$(cc_subagent_cell r1 "$zev" "$win")"
[ "$(echo "$zc" | jq -r .tokens)" = 0 ] && ok "H6 zero-token event still counted (not NOEVENTS)" || fail "H6 got=$zc"
# --- H1: an _unscoped event is never attributed to a run even if ts lands in a window ---
uev='{"agent_name":"reviewer","tokens":99,"cost_usd":0.99,"ts":150,"_unscoped":true}'
if cc_subagent_cell r1 "$uev" "$win" >/dev/null 2>&1; then fail "H1 unscoped event leaked into run"; else ok "H1 unscoped event excluded from run total"; fi

# --- AC-26 / AC-7 / AC-10 / AC-13: assembler emits per-run rows, no session cells, typed unverified ---
acol="$TMP/asm"; mkdir -p "$acol"
# run A: full codex + priced model
printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":1000000,"output_tokens":0,"reasoning_output_tokens":0,"cached_input_tokens":0}}' > "$TMP/rawA.jsonl"
"$WRITER" "$TMP/rawA.jsonl" "$acol" passA claude-opus-4-8 2026-06-29T10:00:00Z 2026-06-29T10:01:00Z >/dev/null
# run B: meta references a missing codex artifact (simulate by deleting codex, keep meta)
recB="$("$WRITER" "$TMP/rawA.jsonl" "$acol" passB claude-opus-4-8 2026-06-29T10:02:00Z 2026-06-29T10:03:00Z)"
ridB="$(echo "$recB" | jq -r .run_id)"; rm -f "$acol/$ridB.codex.jsonl"
rows="$(build_per_run_rows "$acol" "$PRICES" "" SES "")"
# exactly 2 rows, none carrying a cc_main / costs cell
[ "$(echo "$rows" | jq -s 'length')" = 2 ] && ok "AC-2 assembler one row per meta" || fail "row count"
[ "$(echo "$rows" | jq -s 'map(has("cc_main") or has("costs_aggregate_usd")) | any')" = false ] \
  && ok "AC-26 no per-run row carries a session-level cell" || fail "AC-26 leak"
# run A codex_cost = 15.0; cc_subagent unverified (no OTel) ⇒ dispatch_total unverified
rowA="$(echo "$rows" | jq -c 'select(.stage=="passA")')"
[ "$(echo "$rowA" | jq -r .codex_cost_usd)" = "15.000000" ] && ok "AC-7 codex_cost computed" || fail "AC-7 got=$(echo "$rowA" | jq -r .codex_cost_usd)"
# EXACT equality (not grep) so a corrupted cell (e.g. a jq error string containing the reason) fails
[ "$(echo "$rowA" | jq -r .cc_subagent)" = "[unverified: subagent usage requires OTel]" ] && ok "AC-9 cc_subagent unverified no OTel" || fail "AC-9 cc_subagent=$(echo "$rowA" | jq -r .cc_subagent)"
# dispatch_total must propagate the FAILING leg's EXACT closed-list reason (no OTel → cc_subagent leg)
[ "$(echo "$rowA" | jq -r .dispatch_total_cost_usd)" = "[unverified: subagent usage requires OTel]" ] \
  && ok "AC-7 dispatch_total carries failing leg's closed-list reason" || fail "AC-7 total reason: $(echo "$rowA" | jq -r .dispatch_total_cost_usd)"
# run B codex cell unverified (artifact absent), row still present
rowB="$(echo "$rows" | jq -c 'select(.stage=="passB")')"
[ "$(echo "$rowB" | jq -r '.codex')" = "[unverified: codex artifact absent]" ] && ok "AC-10 missing codex → row kept, cell unverified" || fail "AC-10 codex=$(echo "$rowB" | jq -r .codex)"

# --- AC-27/28/29: by-agent rollup is a complete superset incl. non-composite subagents ---
sumcol_otel="$TMP/otel_roll.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"reviewer","tokens":100,"cost_usd":0.10,"ts":1000}' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"reviewer","tokens":50,"cost_usd":0.05,"ts":1200}' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"sdd-task","tokens":400,"cost_usd":0.40,"ts":9999}' \
 '{"name":"claude_code.api_request","query_source":"main","session_id":"SES","agent_name":"orch","tokens":1,"cost_usd":0.01,"ts":1000}' > "$sumcol_otel"
sum="$(build_session_summary "$tr" "$co" "$sumcol_otel" SES "")"
# sdd-task (outside any composite window) is present → no session-level gap
echo "$sum" | jq -e '.by_agent[] | select(.agent_name=="sdd-task")' >/dev/null && ok "AC-27 rollup captures non-composite subagent" || fail "AC-27 missing sdd-task"
# reviewer aggregated: tokens 150, event_count 2, wall_span_s 200
rv="$(echo "$sum" | jq -c '.by_agent[] | select(.agent_name=="reviewer")')"
[ "$(echo "$rv" | jq -r .tokens)" = 150 ] && [ "$(echo "$rv" | jq -r .event_count)" = 2 ] && [ "$(echo "$rv" | jq -r .wall_span_s)" = 200 ] \
  && ok "AC-29 per-agent envelope span + count" || fail "AC-29 got=$rv"
# query_source=main excluded
echo "$sum" | jq -e '.by_agent[] | select(.agent_name=="orch")' >/dev/null && fail "AC-27 main leaked into rollup" || ok "AC-27 main excluded from rollup"
# no OTel → whole rollup unverified
sum2="$(build_session_summary "$tr" "$co" "" SES "")"
echo "$sum2" | jq -r '.by_agent' | grep -q "subagent usage requires OTel" && ok "AC-27 no sink → rollup unverified" || fail "AC-27 no-sink leak"
# --- AC-28: rollup is a COMPLETE superset of the window-bounded per-run subset, never summed ---
# windows that bound only the reviewer events (1000,1200); sdd-task (ts 9999) is OUTSIDE.
acol28="$TMP/asm28"; mkdir -p "$acol28"
printf '{"run_id":"R1","codex_artifact_path":null,"stage":"s","model":"claude-opus-4-8","started_at":"1970-01-01T00:16:40Z","ended_at":"1970-01-01T00:20:01Z","providers_used":["cc"],"fallback_reason":null}' > "$acol28/R1.meta.json"
rows28="$(build_per_run_rows "$acol28" "$PRICES" "$sumcol_otel" SES "")"
perrun_tok="$(echo "$rows28" | jq -s '[ .[] | .cc_subagent | if type=="object" then .tokens else 0 end ] | add')"
rollup_tok="$(echo "$sum" | jq '[ .by_agent[].tokens ] | add')"
# rollup (150 reviewer + 400 sdd-task = 550) is a strict superset of the window subset (150)
[ "$rollup_tok" -ge "$perrun_tok" ] && [ "$rollup_tok" = 550 ] \
  && ok "AC-28 rollup is complete superset (>= window-bounded subset)" || fail "AC-28 rollup=$rollup_tok perrun=$perrun_tok"
# no per-run dispatch_total silently absorbs a rollup addend (it is [unverified] here — a leg is)
echo "$rows28" | jq -e '.dispatch_total_cost_usd | type=="string" and startswith("[unverified")' >/dev/null \
  && ok "AC-28 per-run total never includes a rollup addend" || fail "AC-28 total absorbed rollup"
# --- AC-29: a non-numeric ts → that agent's wall_span_s is [unverified: malformed OTel timestamp] ---
badts="$TMP/otel_badts.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"reviewer","tokens":10,"cost_usd":0.01,"ts":"not-a-number"}' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"reviewer","tokens":10,"cost_usd":0.01,"ts":1000}' > "$badts"
sum3="$(build_session_summary "$tr" "$co" "$badts" SES "")"
[ "$(echo "$sum3" | jq -r '.by_agent[] | select(.agent_name=="reviewer") | .wall_span_s')" = "[unverified: malformed OTel timestamp]" ] \
  && ok "AC-29 malformed OTel ts → wall_span_s unverified" || fail "AC-29 got=$(echo "$sum3" | jq -rc '.by_agent')"

# --- AC-22: writer→report seam (forward the printed collection_dir verbatim) ---
seamrec="$("$WRITER" "$TMP/rawA.jsonl" "$TMP/seam" stageS claude-opus-4-8 2026-06-29T10:00:00Z 2026-06-29T10:01:00Z)"
seamdir="$(echo "$seamrec" | jq -r .collection_dir)"
out="$(bash "$TOOL" --session "$tr" --collection "$seamdir" 2>/dev/null)"
echo "$out" | grep -q stageS && ok "AC-22 report enumerates writer-persisted run via printed dir" || fail "AC-22 seam"
# --- AC-11: no --otel → visible warning pointing to README ---
warn="$(bash "$TOOL" --session "$tr" --collection "$seamdir" 2>&1 >/dev/null)"
echo "$warn" | grep -qi "OTel" && echo "$warn" | grep -qi "README" && ok "AC-11 missing-OTel warning → README" || fail "AC-11 warning"
# --- AC-25 wiring: duplicate run_id → exit 1 ---
bash "$TOOL" --session "$tr" --collection "$dcol" >/dev/null 2>&1; [ $? -eq 1 ] && ok "AC-25 duplicate → exit 1" || fail "AC-25 exit code"
# --- usage errors ---
bash "$TOOL" --session "$tr" >/dev/null 2>&1; [ $? -eq 2 ] && ok "usage: missing --collection → exit 2" || fail "exit 2 missing collection"
bash "$TOOL" --session /no/such --collection "$seamdir" >/dev/null 2>&1; [ $? -eq 2 ] && ok "usage: missing transcript → exit 2" || fail "exit 2 missing transcript"
# --- AC-5: tool dispatches no LLM (no Agent/claude call in source) ---
# Pattern requires Agent as a call (Agent\() to avoid false-positives on agent_name/by_agent identifiers.
grep -qE '(^|[^a-zA-Z0-9_])(Agent\(|claude -p|claude --print)' "$TOOL" && fail "AC-5 tool references an LLM dispatch" || ok "AC-5 no LLM dispatch in tool"
# --- M-new-1: a value-taking flag with no operand → clean exit 2 (not unbound-variable abort) ---
bash "$TOOL" --session >/dev/null 2>&1; [ $? -eq 2 ] && ok "usage: dangling --session → exit 2" || fail "dangling flag not exit 2"
# --- AC-20 surfacing: unattributed / ambiguous / malformed-ts events get closed-list markers ---
dcol2="$TMP/diag"; mkdir -p "$dcol2"
# D1 window [100,200)  (1970-01-01T00:01:40Z=100, 00:03:20Z=200);  D2 [60,300) overlaps D1
printf '{"run_id":"D1","codex_artifact_path":null,"stage":"s","model":"m","started_at":"1970-01-01T00:01:40Z","ended_at":"1970-01-01T00:03:20Z","providers_used":["cc"],"fallback_reason":null}' > "$dcol2/D1.meta.json"
printf '{"run_id":"D2","codex_artifact_path":null,"stage":"s","model":"m","started_at":"1970-01-01T00:01:00Z","ended_at":"1970-01-01T00:05:00Z","providers_used":["cc"],"fallback_reason":null}' > "$dcol2/D2.meta.json"
dotel="$TMP/diag_otel.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"x","tokens":1,"cost_usd":0.01,"ts":50}' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"z","tokens":1,"cost_usd":0.01,"ts":150}' \
 '{"name":"claude_code.api_request","query_source":"subagent","session_id":"SES","agent_name":"y","tokens":1,"cost_usd":0.01,"ts":"bad"}' \
 '{"name":"claude_code.api_request","query_source":"subagent","agent_name":"u","tokens":1,"cost_usd":0.01,"ts":150}' > "$dotel"
diag="$(otel_diagnostics "$dcol2" "$dotel" SES "")"
echo "$diag" | grep -q "unattributed OTel event"        && ok "AC-20 unattributed event surfaced"   || fail "AC-20 unattributed: $diag"
echo "$diag" | grep -q "ambiguous OTel run attribution" && ok "AC-20 ambiguous event surfaced"      || fail "AC-20 ambiguous: $diag"
echo "$diag" | grep -q "malformed OTel timestamp"       && ok "AC-20 malformed-ts event surfaced"   || fail "AC-20 malformed ts: $diag"
# AC-15 per-run: an unscoped event (no session_id, no scope assertion) is surfaced, not dropped
echo "$diag" | grep -q "OTel events lack session scope" && ok "AC-15 unscoped event surfaced per-run" || fail "AC-15 unscoped: $diag"

# --- AC-19: composites wire the owned writer with a real (uncommented, unfenced) invocation ---
guard_wired() {  # <skill_md>
  awk '
    /^```/ { infence = !infence; next }       # toggle fenced blocks; skip the fence lines
    infence { next }                           # ignore content inside ``` examples
    /^[[:space:]]*#/ { next }                  # ignore comment lines
    /persist-dispatch\.sh/ { found=1 }
    END { exit (found?0:1) }
  ' "$1"
}
for sk in cross-provider-reviewer cross-provider-architect; do
  f="$REPO_ROOT/skills/$sk/SKILL.md"
  if guard_wired "$f"; then ok "AC-19 $sk wires persist-dispatch.sh (real line)"; else fail "AC-19 $sk missing real persist-dispatch.sh line"; fi
done

# --- AC-23 (live-bearing): committed OTel fixture is a real capture with provenance ---
OTEL_FIX="$FIX/otel-export.jsonl"
if [ -f "$OTEL_FIX" ]; then
  if head -20 "$OTEL_FIX" "$FIX/otel-export.provenance.txt" 2>/dev/null | grep -qiE 'otelcol|CLAUDE_CODE_ENABLE_TELEMETRY|capture date'; then
    ok "AC-23 OTel fixture carries capture provenance"
  else
    fail "AC-23 OTel fixture lacks provenance header (real-capture unproven)"
  fi
  # ≥1 subagent event outside every committed meta window — exercised in Task 10 against this fixture
else
  echo "WARN - AC-23 live-bearing: OTel real capture not present → [unverified] carried to Evidence Reckoning"
fi

echo ""; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ]
