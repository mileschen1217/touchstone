#!/usr/bin/env bash
# Deterministic tests for the metrics-capture v2 report tool + START hook.
#
# v2 contract: a UserPromptSubmit + PreToolUse/Skill hook (hooks/stamp-run.sh) stamps a run-manifest per auto-run
# gate; the reporter windows those manifests by next-START (last run bounded at report-time `now`)
# and harvests each window from DURABLE logs — OTel for CC subagents, ~/.codex/sessions rollouts for
# Codex. No owned-writer, no meta sidecars, no --collection. Windows are contiguous/disjoint by
# construction, so a slow Codex review can never truncate a run and AMBIGUOUS never arises via real
# windows (attribute_event still supports it defensively; unit-tested with hand-crafted overlap).
#
# SC2015: && ok || fail idiom is intentional. SC2034: some scaffolding vars.
# SC2181: `cmd; [ $? -eq N ]` is intentional for asserting a subprocess exit code.
# shellcheck disable=SC2015,SC2034,SC2181
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TOOL="$REPO_ROOT/scripts/metrics-report.sh"
HOOK="$REPO_ROOT/hooks/stamp-run.sh"
PRICES="$REPO_ROOT/scripts/metrics/model-prices.json"
FIX="$REPO_ROOT/scripts/tests/fixtures/metrics"
CODEX_FIX="$FIX/codex-sessions"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
# shellcheck source=/dev/null
source "$TOOL"   # source-guard keeps main() from running
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ==================================================================================
# UNCHANGED HELPERS — still present in v2, tested verbatim
# ==================================================================================

# --- AC-7: price table applied; reasoning billed as output ---
got="$(compute_codex_cost 1000000 0 1000000 1000000 claude-opus-4-8 "$PRICES")"
[ "$got" = "165.000000" ] && ok "AC-7 reasoning billed at output rate" || fail "AC-7 got=$got want=165.000000"
# --- AC-8: unknown model → MISSING_PRICE ---
if compute_codex_cost 100 0 100 0 no-such-model "$PRICES" >/dev/null 2>&1; then fail "AC-8 unpriced model should fail"; else ok "AC-8 unpriced model returns MISSING_PRICE"; fi

# --- AC-3: main-loop sums only isSidechain false/absent ---
tr="$TMP/transcript.jsonl"
printf '%s\n' \
 '{"type":"assistant","timestamp":"2026-06-29T10:00:00Z","message":{"usage":{"input_tokens":100,"output_tokens":40}}}' \
 '{"type":"assistant","isSidechain":true,"timestamp":"2026-06-29T10:00:30Z","message":{"usage":{"input_tokens":999,"output_tokens":999}}}' \
 '{"type":"assistant","isSidechain":false,"timestamp":"2026-06-29T10:05:00Z","message":{"usage":{"input_tokens":20,"output_tokens":10}}}' > "$tr"
ml="$(mainloop_usage "$tr")"
[ "$(echo "$ml" | jq -r .in)" = 120 ] && [ "$(echo "$ml" | jq -r .out)" = 50 ] && ok "AC-3 main-loop excludes sidechain" || fail "AC-3 got=$ml"
# --- AC-21: session wallclock; malformed → fail ---
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
[ "$(echo "$agg" | jq -r .unparseable_lines)" = 1 ] && ok "AC-6 scope-excluded row not unparseable" || fail "AC-6 unparseable wrong: $agg"
co2="$TMP/costs2.jsonl"; printf '%s\n' '{"input_tokens":100,"output_tokens":50,"cost_usd":0.5}' > "$co2"
note="$(costs_aggregate "$co2" S1 2>&1 >/dev/null)"; rc=$?
[ "$rc" != 0 ] && echo "$note" | grep -qi "session scope" && ok "AC-6 no-scope → NOSCOPE + note" || fail "AC-6 noscope rc=$rc note=$note"
co3="$TMP/costs3.jsonl"; printf '%s\n' '{"session_id":"S1","input_tokens":1,"output_tokens":1}' '{"input_tokens":1,"output_tokens":1}' > "$co3"
if costs_aggregate "$co3" S1 >/dev/null 2>&1; then fail "AC-6 mixed-schema should be NOSCOPE"; else ok "AC-6 mixed-schema → NOSCOPE"; fi

# --- G-2 (regression): unparseable_lines preserved through build_session_summary NOSCOPE branch ---
co_ns_bad="$TMP/costs_ns_bad.jsonl"; printf '%s\n' '{"input_tokens":100,"output_tokens":50,"cost_usd":0.5}' 'not json' > "$co_ns_bad"
sum_ns="$(build_session_summary "$tr" "$co_ns_bad" "" SES "" 2>/dev/null)"
[ "$(echo "$sum_ns" | jq -r .unparseable_lines)" = 1 ] && ok "G-2 unparseable_lines=1 preserved through NOSCOPE else-branch" || fail "G-2 unparseable wrong"

# --- AC-15: OTel scoping — matching included, foreign excluded, unscoped marked ---
ot="$TMP/otel.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:reviewer","session_id":"SES","agent_name":"reviewer","tokens":100,"cost_usd":0.1,"ts":1000}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:reviewer","session_id":"OTHER","agent_name":"reviewer","tokens":900,"cost_usd":0.9,"ts":1000}' \
 '{"name":"claude_code.api_request","query_source":"main","session_id":"SES","agent_name":"orchestrator","tokens":50,"cost_usd":0.05,"ts":1000}' > "$ot"
n="$(otel_scoped_events "$ot" SES "" | wc -l | tr -d ' ')"
[ "$n" = 1 ] && ok "AC-15 only matching-session subagent event included" || fail "AC-15 got n=$n"
ot2="$TMP/otel2.jsonl"; printf '%s\n' '{"name":"claude_code.api_request","query_source":"agent:builtin:r","agent_name":"r","tokens":1,"cost_usd":0.01,"ts":1}' > "$ot2"
u="$(otel_scoped_events "$ot2" SES "")"
[ "$(echo "$u" | jq -r '._unscoped')" = true ] && ok "AC-15 unscoped event marked" || fail "AC-15 unscoped got=$u"
u2="$(otel_scoped_events "$ot2" SES SES)"
[ "$(echo "$u2" | jq -r '._unscoped // false')" = false ] && ok "AC-15 scope assertion includes unscoped" || fail "AC-15 assert got=$u2"
otel_scoped_events "$TMP/nofile" SES "" >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] && ok "AC-9 absent OTel → typed no-data" || fail "AC-9 no-data rc wrong"

# --- AC-20: attribute_event half-open containment (UNIT — hand-crafted windows incl. overlap) ---
win="$(printf 'r1\t100\t200\nr2\t200\t300\n')"
[ "$(attribute_event 150 "$win")" = r1 ] && ok "AC-20 inside r1" || fail "AC-20 inside r1"
[ "$(attribute_event 200 "$win")" = r2 ] && ok "AC-20 touching boundary → later run" || fail "AC-20 boundary"
[ "$(attribute_event 50  "$win")" = UNATTRIBUTED ] && ok "AC-20 no window → UNATTRIBUTED" || fail "AC-20 zero"
win2="$(printf 'r2\t200\t300\nr3\t150\t250\n')"
[ "$(attribute_event 220 "$win2")" = AMBIGUOUS ] && ok "AC-20 overlap → AMBIGUOUS (defensive; v2 windows never overlap)" || fail "AC-20 multi"
[ "$(attribute_event 150.5 "$win")" = r1 ] && ok "H8 float ts attributes to r1" || fail "H8 float ts"
[ "$(attribute_event . "$win")" = UNATTRIBUTED ] && [ "$(attribute_event 1.2.3 "$win")" = UNATTRIBUTED ] && ok "H8 malformed numeric ts rejected (., 1.2.3)" || fail "H8 malformed numeric not rejected"

# --- AC-14/12/H6/H1: cc_subagent_cell ---
ev="$(printf '%s\n' \
 '{"agent_name":"reviewer","tokens":100,"cost_usd":0.10,"ts":150}' \
 '{"agent_name":"architect","tokens":40,"cost_usd":0.04,"ts":160}' \
 '{"agent_name":"reviewer","tokens":5,"cost_usd":0.005,"ts":50}')"
cell="$(cc_subagent_cell r1 "$ev" "$win")"
[ "$(echo "$cell" | jq -r .tokens)" = 140 ] && ok "AC-14 cc_subagent summed over names" || fail "AC-14 got=$cell"
if cc_subagent_cell r2 "$ev" "$win" >/dev/null 2>&1; then fail "AC-12 should be NOEVENTS"; else ok "AC-12 zero events → NOEVENTS"; fi
zev='{"agent_name":"reviewer","tokens":0,"cost_usd":0,"ts":150}'
zc="$(cc_subagent_cell r1 "$zev" "$win")"
[ "$(echo "$zc" | jq -r .tokens)" = 0 ] && ok "H6 zero-token event still counted (not NOEVENTS)" || fail "H6 got=$zc"
uev='{"agent_name":"reviewer","tokens":99,"cost_usd":0.99,"ts":150,"_unscoped":true}'
if cc_subagent_cell r1 "$uev" "$win" >/dev/null 2>&1; then fail "H1 unscoped event leaked into run"; else ok "H1 unscoped event excluded from run total"; fi

# ==================================================================================
# V2 NEW — Codex durable-log reader (~/.codex/sessions rollouts)
# ==================================================================================
ROLL="$CODEX_FIX/2026/07/01/rollout-2026-07-01T10-00-00-synthetic.jsonl"

# codex_rollout_usage: takes LAST cumulative token_count + model from turn_context
u="$(codex_rollout_usage "$ROLL")"
[ "$(echo "$u" | jq -r .model)" = gpt-5-codex ] && [ "$(echo "$u" | jq -r .in)" = 3000 ] \
  && [ "$(echo "$u" | jq -r .cached_in)" = 1200 ] && [ "$(echo "$u" | jq -r .out)" = 180 ] \
  && [ "$(echo "$u" | jq -r .reasoning)" = 40 ] \
  && ok "CX-1 codex_rollout_usage = LAST cumulative token_count + turn_context model" || fail "CX-1 got=$u"
if codex_rollout_usage "$TMP/nope.jsonl" >/dev/null 2>&1; then fail "CX-2 missing rollout should fail"; else ok "CX-2 missing rollout → MISSING"; fi

# codex_rollouts_in_window: cwd + half-open window + originator=codex_exec
s0=$(iso_to_epoch 2026-07-01T09:00:00Z); e0=$(iso_to_epoch 2026-07-01T11:00:00Z)
hit="$(CODEX_SESSIONS_DIR="$CODEX_FIX" codex_rollouts_in_window /synthetic/project "$s0" "$e0")"
[ "$(printf '%s\n' "$hit" | grep -c synthetic)" = 1 ] && ok "CX-3 rollout selected by cwd+window+originator" || fail "CX-3 got=$hit"
miss_cwd="$(CODEX_SESSIONS_DIR="$CODEX_FIX" codex_rollouts_in_window /other/cwd "$s0" "$e0")"
[ -z "$miss_cwd" ] && ok "CX-4 cwd mismatch → excluded" || fail "CX-4 got=$miss_cwd"
s1=$(iso_to_epoch 2026-07-01T11:00:00Z); e1=$(iso_to_epoch 2026-07-01T12:00:00Z)
miss_win="$(CODEX_SESSIONS_DIR="$CODEX_FIX" codex_rollouts_in_window /synthetic/project "$s1" "$e1")"
[ -z "$miss_win" ] && ok "CX-5 ts outside window → excluded" || fail "CX-5 got=$miss_win"

# codex_window_aggregate: sum over rollouts, priced; grounded ZERO when none; unverified propagation
agg="$(CODEX_SESSIONS_DIR="$CODEX_FIX" codex_window_aggregate /synthetic/project "$s0" "$e0" "$PRICES")"
au="$(printf '%s' "$agg" | cut -f1)"; ac="$(printf '%s' "$agg" | cut -f2)"
[ "$(echo "$au" | jq -r .in)" = 3000 ] && [ "$ac" = "0.006100" ] \
  && ok "CX-6 codex_window_aggregate sums + prices (in=3000 cost=0.006100)" || fail "CX-6 usage=$au cost=$ac"
# grounded zero: window with no rollout → all-zero usage, cost 0 (NOT unverified)
gz="$(CODEX_SESSIONS_DIR="$CODEX_FIX" codex_window_aggregate /synthetic/project "$s1" "$e1" "$PRICES")"
gzu="$(printf '%s' "$gz" | cut -f1)"; gzc="$(printf '%s' "$gz" | cut -f2)"
[ "$(echo "$gzu" | jq -r .in)" = 0 ] && [ "$gzc" = 0 ] \
  && ok "CX-7 no rollout in window → grounded ZERO codex cost (not [unverified])" || fail "CX-7 usage=$gzu cost=$gzc"
# unverified propagation: an unpriced-model rollout → cost sentinel
UPROLL="$TMP/codex/2026/07/01"; mkdir -p "$UPROLL"
printf '%s\n' \
 '{"type":"session_meta","payload":{"cwd":"/unpriced/proj","originator":"codex_exec","timestamp":"2026-07-01T10:00:00.000Z"}}' \
 '{"type":"turn_context","model":"totally-unknown-model"}' \
 '{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":9,"cached_input_tokens":0,"output_tokens":9,"reasoning_output_tokens":0}}}}' \
 > "$UPROLL/rollout-2026-07-01T10-00-00-unpriced.jsonl"
upa="$(CODEX_SESSIONS_DIR="$TMP/codex" codex_window_aggregate /unpriced/proj "$s0" "$e0" "$PRICES")"
[ "$(printf '%s' "$upa" | cut -f2)" = "[unverified: model not in price table]" ] \
  && ok "CX-8 unpriced-model rollout → cost propagates closed-list sentinel" || fail "CX-8 got=$(printf '%s' "$upa" | cut -f2)"
# CX-9 (Codex H1): absent scan root ≠ scanned-empty → [unverified], NOT grounded zero
a9="$(CODEX_SESSIONS_DIR="$TMP/does-not-exist" codex_window_aggregate /synthetic/project "$s0" "$e0" "$PRICES")"
[ "$(printf '%s' "$a9" | cut -f2)" = "[unverified: codex artifact absent]" ] \
  && ok "CX-9 absent CODEX_SESSIONS_DIR → [unverified] (not fabricated grounded zero)" || fail "CX-9 got=$(printf '%s' "$a9" | cut -f2)"
# CX-10 (Codex H2): matched-but-malformed rollout (no token_count) → poisons the leg
BADR="$TMP/badroll/2026/07/01"; mkdir -p "$BADR"
printf '%s\n' \
 '{"type":"session_meta","payload":{"cwd":"/bad/proj","originator":"codex_exec","timestamp":"2026-07-01T10:00:00.000Z"}}' \
 '{"type":"turn_context","model":"gpt-5-codex"}' > "$BADR/rollout-2026-07-01T10-00-00-nomcount.jsonl"
a10="$(CODEX_SESSIONS_DIR="$TMP/badroll" codex_window_aggregate /bad/proj "$s0" "$e0" "$PRICES")"
[ "$(printf '%s' "$a10" | cut -f2)" = "[unverified: malformed meta codex-rollout]" ] \
  && ok "CX-10 matched-but-malformed rollout → poisons codex leg [unverified]" || fail "CX-10 got=$(printf '%s' "$a10" | cut -f2)"
# CX-11 (Codex H2): good + bad rollout mix → poisoned total, never a partial sum
MIX="$TMP/mixroll/2026/07/01"; mkdir -p "$MIX"
printf '%s\n' \
 '{"type":"session_meta","payload":{"cwd":"/mix/proj","originator":"codex_exec","timestamp":"2026-07-01T10:00:00.000Z"}}' \
 '{"type":"turn_context","model":"gpt-5-codex"}' \
 '{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":10,"reasoning_output_tokens":0}}}}' \
 > "$MIX/rollout-2026-07-01T10-00-00-good.jsonl"
printf '%s\n' \
 '{"type":"session_meta","payload":{"cwd":"/mix/proj","originator":"codex_exec","timestamp":"2026-07-01T10:00:05.000Z"}}' \
 '{"type":"turn_context","model":"gpt-5-codex"}' > "$MIX/rollout-2026-07-01T10-00-05-bad.jsonl"
a11="$(CODEX_SESSIONS_DIR="$TMP/mixroll" codex_window_aggregate /mix/proj "$s0" "$e0" "$PRICES")"
[ "$(printf '%s' "$a11" | cut -f2)" = "[unverified: malformed meta codex-rollout]" ] \
  && ok "CX-11 good+bad rollout mix → poisoned (no partial sum claimed)" || fail "CX-11 got=$(printf '%s' "$a11" | cut -f2)"

# ==================================================================================
# V2 NEW — run-manifest windows (build_windows_v2)
# ==================================================================================
mkmani() { # <dir> <run_id> <skill> <session> <cwd> <started_at>
  jq -nc --arg r "$2" --arg s "$3" --arg sid "$4" --arg cwd "$5" --arg st "$6" \
    '{schema:"run-manifest/v1",run_id:$r,skill:$s,session_id:$sid,cwd:$cwd,started_at:$st}' > "$1/runs/$2.json"; }
WD="$TMP/wd"; mkdir -p "$WD/runs"
mkmani "$WD" A design-review sess-1 /proj 2026-07-01T10:00:00Z
mkmani "$WD" B anvil         sess-1 /proj 2026-07-01T10:30:00Z
mkmani "$WD" C design-spec   sess-1 /proj 2026-07-01T11:00:00Z
mkmani "$WD" X anvil         sess-OTHER /proj 2026-07-01T09:00:00Z
nowW=$(iso_to_epoch 2026-07-01T11:15:00Z)
wins="$(TOUCHSTONE_METRICS_DIR="$WD" build_windows_v2 sess-1 "$nowW")"
[ "$(printf '%s\n' "$wins" | wc -l | tr -d ' ')" = 3 ] && ok "BW-1 only session-matching manifests windowed (sess-OTHER excluded)" || fail "BW-1 count=$(printf '%s\n' "$wins" | wc -l)"
durA="$(printf '%s\n' "$wins" | awk -F'\t' '$1=="A"{print $3-$2}')"
durB="$(printf '%s\n' "$wins" | awk -F'\t' '$1=="B"{print $3-$2}')"
durC="$(printf '%s\n' "$wins" | awk -F'\t' '$1=="C"{print $3-$2}')"
[ "$durA" = 1800 ] && [ "$durB" = 1800 ] && ok "BW-2 non-last run ends at next START (A,B = 1800s)" || fail "BW-2 durA=$durA durB=$durB"
[ "$durC" = 900 ]  && ok "BW-3 last run ends at report-time now (C = 900s)" || fail "BW-3 durC=$durC"
# BW-4/5 (Codex M1): two same-second manifests → overlapping non-zero windows; overlap event → AMBIGUOUS
SS="$TMP/samesec"; mkdir -p "$SS/runs"
mkmani "$SS" P design-review sess-1 /proj 2026-07-01T10:00:00Z
mkmani "$SS" Q anvil         sess-1 /proj 2026-07-01T10:00:00Z
mkmani "$SS" R design-spec   sess-1 /proj 2026-07-01T10:05:00Z
nowSS=$(iso_to_epoch 2026-07-01T10:10:00Z)
wss="$(TOUCHSTONE_METRICS_DIR="$SS" build_windows_v2 sess-1 "$nowSS")"
pdur="$(printf '%s\n' "$wss" | awk -F'\t' '$1=="P"{print $3-$2}')"
qdur="$(printf '%s\n' "$wss" | awk -F'\t' '$1=="Q"{print $3-$2}')"
[ "$pdur" = 300 ] && [ "$qdur" = 300 ] && ok "BW-4 same-second runs → overlapping non-zero windows (no silent zero-length)" || fail "BW-4 pdur=$pdur qdur=$qdur"
w3="$(printf '%s\n' "$wss" | awk -F'\t' 'NF>=3{print $1"\t"$2"\t"$3}')"
mid=$(( $(iso_to_epoch 2026-07-01T10:00:00Z) + 100 ))
[ "$(attribute_event "$mid" "$w3")" = AMBIGUOUS ] && ok "BW-5 event in same-second overlap → AMBIGUOUS (surfaced, not silently one run)" || fail "BW-5 not ambiguous"
# BW-6: malformed manifests (missing run_id / unparseable started_at / non-JSON) are silently
# excluded from windowing — the good manifest still windows, and the builder exits 0.
MF="$TMP/malformed"; mkdir -p "$MF/runs"
mkmani "$MF" GOOD anvil sess-1 /proj 2026-07-01T10:00:00Z
jq -nc '{schema:"run-manifest/v1",skill:"anvil",session_id:"sess-1",cwd:"/proj",started_at:"2026-07-01T10:01:00Z"}' > "$MF/runs/norunid.json"
jq -nc '{schema:"run-manifest/v1",run_id:"BADTS",skill:"anvil",session_id:"sess-1",cwd:"/proj",started_at:"not-a-date"}' > "$MF/runs/BADTS.json"
jq -nc '{schema:"run-manifest/v1",run_id:"NOTS",skill:"anvil",session_id:"sess-1",cwd:"/proj"}' > "$MF/runs/NOTS.json"
printf 'not json at all' > "$MF/runs/garbage.json"
nowMF=$(iso_to_epoch 2026-07-01T10:10:00Z)
wmf="$(TOUCHSTONE_METRICS_DIR="$MF" build_windows_v2 sess-1 "$nowMF")"; rcmf=$?
{ [ "$rcmf" -eq 0 ] && [ "$(printf '%s\n' "$wmf" | grep -c .)" = 1 ] \
  && [ "$(printf '%s\n' "$wmf" | awk -F'\t' '{print $1}')" = GOOD ]; } \
  && ok "BW-6 malformed manifests (no run_id / bad or missing started_at / non-JSON) silently excluded, good one windows" \
  || fail "BW-6 rc=$rcmf windows=$wmf"

# ==================================================================================
# V2 NEW — per-run rows (build_per_run_rows_v2) end-to-end + honesty spine
# ==================================================================================
PR="$TMP/pr"; mkdir -p "$PR/runs"
# run DR: window [09:59,10:02) contains the synthetic rollout@10:00 (cwd /synthetic/project)
mkmani "$PR" DR design-review sess-1 /synthetic/project 2026-07-01T09:59:00Z
# run AN: window [10:02,now) — no rollout in /synthetic/project → grounded zero codex
mkmani "$PR" AN anvil         sess-1 /synthetic/project 2026-07-01T10:02:00Z
nowPR=$(iso_to_epoch 2026-07-01T10:10:00Z)
rows="$(TOUCHSTONE_METRICS_DIR="$PR" CODEX_SESSIONS_DIR="$CODEX_FIX" build_per_run_rows_v2 "$PRICES" "" sess-1 "" "$nowPR")"
[ "$(echo "$rows" | jq -s 'length')" = 2 ] && ok "PR-1 one row per manifest" || fail "PR-1 count"
[ "$(echo "$rows" | jq -s 'map(has("cc_main") or has("costs_aggregate_usd")) | any')" = false ] && ok "PR-2 no per-run row carries a session-level cell" || fail "PR-2 leak"
[ "$(echo "$rows" | jq -s 'map(has("stage")) | any')" = false ] && ok "PR-3 v2 rows carry skill not stage" || fail "PR-3 stage leaked"
rowDR="$(echo "$rows" | jq -c 'select(.skill=="design-review")')"
[ "$(echo "$rowDR" | jq -r .codex.in)" = 3000 ] && [ "$(echo "$rowDR" | jq -r .codex_cost_usd)" = "0.006100" ] \
  && ok "PR-4 codex leg harvested from rollout + priced" || fail "PR-4 got=$rowDR"
[ "$(echo "$rowDR" | jq -r .wallclock_s)" = 180 ] && ok "PR-5 wallclock DERIVED from window (end-start=180)" || fail "PR-5 wc=$(echo "$rowDR" | jq -r .wallclock_s)"
# EXACT equality (not grep) so a corrupted/error-string cell fails
[ "$(echo "$rowDR" | jq -r .cc_subagent)" = "[unverified: subagent usage requires OTel]" ] && ok "PR-6 cc_subagent unverified without OTel" || fail "PR-6 cc=$(echo "$rowDR" | jq -r .cc_subagent)"
[ "$(echo "$rowDR" | jq -r .dispatch_total_cost_usd)" = "[unverified: subagent usage requires OTel]" ] && ok "PR-7 dispatch_total propagates failing leg's exact reason" || fail "PR-7 total=$(echo "$rowDR" | jq -r .dispatch_total_cost_usd)"
rowAN="$(echo "$rows" | jq -c 'select(.skill=="anvil")')"
[ "$(echo "$rowAN" | jq -r .codex.in)" = 0 ] && [ "$(echo "$rowAN" | jq -r .codex_cost_usd)" = 0 ] \
  && ok "PR-8 no-rollout window → codex GROUNDED ZERO (row kept)" || fail "PR-8 got=$rowAN"

# ==================================================================================
# V2 NEW — by-agent rollup superset (build_session_summary paired with v2 per-run subset)
# ==================================================================================
sumcol_otel="$TMP/otel_roll.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:reviewer","session_id":"SES","agent_name":"reviewer","tokens":100,"cost_usd":0.10,"ts":1000}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:reviewer","session_id":"SES","agent_name":"reviewer","tokens":50,"cost_usd":0.05,"ts":1200}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:sdd-task","session_id":"SES","agent_name":"sdd-task","tokens":400,"cost_usd":0.40,"ts":9999}' \
 '{"name":"claude_code.api_request","query_source":"main","session_id":"SES","agent_name":"orch","tokens":1,"cost_usd":0.01,"ts":1000}' > "$sumcol_otel"
sum="$(build_session_summary "$tr" "$co" "$sumcol_otel" SES "")"
echo "$sum" | jq -e '.by_agent[] | select(.agent_name=="sdd-task")' >/dev/null && ok "AC-27 rollup captures non-composite subagent" || fail "AC-27 missing sdd-task"
rv="$(echo "$sum" | jq -c '.by_agent[] | select(.agent_name=="reviewer")')"
[ "$(echo "$rv" | jq -r .tokens)" = 150 ] && [ "$(echo "$rv" | jq -r .event_count)" = 2 ] && [ "$(echo "$rv" | jq -r .wall_span_s)" = 200 ] && ok "AC-29 per-agent envelope span + count" || fail "AC-29 got=$rv"
echo "$sum" | jq -e '.by_agent[] | select(.agent_name=="orch")' >/dev/null && fail "AC-27 main leaked into rollup" || ok "AC-27 main excluded from rollup"
sum2="$(build_session_summary "$tr" "$co" "" SES "")"
echo "$sum2" | jq -r '.by_agent' | grep -q "subagent usage requires OTel" && ok "AC-27 no sink → rollup unverified" || fail "AC-27 no-sink leak"
# AC-28: rollup is a COMPLETE superset of the window-bounded per-run subset, never summed.
# manifest window [1000,1300) bounds reviewer events (ts 1000,1200) but EXCLUDES sdd-task (ts 9999).
AS="$TMP/asm28"; mkdir -p "$AS/runs"
mkmani "$AS" R1 anvil SES /proj 1970-01-01T00:16:40Z   # 00:16:40Z = epoch 1000
rows28="$(TOUCHSTONE_METRICS_DIR="$AS" build_per_run_rows_v2 "$PRICES" "$sumcol_otel" SES "" 1300)"
perrun_tok="$(echo "$rows28" | jq -s '[ .[] | .cc_subagent | if type=="object" then .tokens else 0 end ] | add')"
rollup_tok="$(echo "$sum" | jq '[ .by_agent[].tokens ] | add')"
[ "$rollup_tok" -ge "$perrun_tok" ] && [ "$rollup_tok" = 550 ] && [ "$perrun_tok" = 150 ] \
  && ok "AC-28 rollup (550) is complete superset of window-bounded subset (150)" || fail "AC-28 rollup=$rollup_tok perrun=$perrun_tok"
# --- AC-29: a non-numeric ts → that agent's wall_span_s is [unverified: malformed OTel timestamp] ---
badts="$TMP/otel_badts.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:reviewer","session_id":"SES","agent_name":"reviewer","tokens":10,"cost_usd":0.01,"ts":"not-a-number"}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:reviewer","session_id":"SES","agent_name":"reviewer","tokens":10,"cost_usd":0.01,"ts":1000}' > "$badts"
sum3="$(build_session_summary "$tr" "$co" "$badts" SES "")"
[ "$(echo "$sum3" | jq -r '.by_agent[] | select(.agent_name=="reviewer") | .wall_span_s')" = "[unverified: malformed OTel timestamp]" ] \
  && ok "AC-29 malformed OTel ts → wall_span_s unverified" || fail "AC-29 got=$(echo "$sum3" | jq -rc '.by_agent')"

# ==================================================================================
# V2 NEW — main CLI end-to-end + OTel diagnostics (v2 signature) + usage errors
# ==================================================================================
out="$(TOUCHSTONE_METRICS_DIR="$PR" CODEX_SESSIONS_DIR="$CODEX_FIX" bash "$TOOL" --session-id sess-1 --now "$nowPR" 2>/dev/null)"
echo "$out" | jq -e 'select(.skill=="design-review")' >/dev/null && ok "CLI-1 main enumerates manifest-stamped runs" || fail "CLI-1 no run row"
# --- AC-11: no --otel → visible warning pointing to README ---
warn="$(TOUCHSTONE_METRICS_DIR="$PR" bash "$TOOL" --session-id sess-1 --now "$nowPR" 2>&1 >/dev/null)"
echo "$warn" | grep -qi "OTel" && echo "$warn" | grep -qi "README" && ok "AC-11 missing-OTel warning → README" || fail "AC-11 warning"
# --- AC-5: tool dispatches no LLM ---
grep -qE '(^|[^a-zA-Z0-9_])(Agent\(|claude -p|claude --print)' "$TOOL" && fail "AC-5 tool references an LLM dispatch" || ok "AC-5 no LLM dispatch in tool"
# --- usage errors ---
bash "$TOOL" >/dev/null 2>&1; [ $? -eq 2 ] && ok "usage: no --session-id/--session → exit 2" || fail "exit 2 missing session id"
bash "$TOOL" --session-id >/dev/null 2>&1; [ $? -eq 2 ] && ok "usage: dangling --session-id → exit 2 (not unbound-var abort)" || fail "dangling flag not exit 2"
# --- OTel diagnostics (v2 sig: otel sid assert now): unattributed / malformed-ts / unscoped surfaced ---
DG="$TMP/diag"; mkdir -p "$DG/runs"
mkmani "$DG" D1 anvil SES /proj 1970-01-01T00:01:40Z   # window [100, now=200)
dotel="$TMP/diag_otel.jsonl"
printf '%s\n' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:x","session_id":"SES","agent_name":"x","tokens":1,"cost_usd":0.01,"ts":50}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:z","session_id":"SES","agent_name":"z","tokens":1,"cost_usd":0.01,"ts":150}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:y","session_id":"SES","agent_name":"y","tokens":1,"cost_usd":0.01,"ts":"bad"}' \
 '{"name":"claude_code.api_request","query_source":"agent:builtin:u","agent_name":"u","tokens":1,"cost_usd":0.01,"ts":150}' > "$dotel"
diag="$(TOUCHSTONE_METRICS_DIR="$DG" otel_diagnostics "$dotel" SES "" 200)"
echo "$diag" | grep -q "unattributed OTel event"        && ok "DG-1 unattributed event surfaced (ts=50 before window)" || fail "DG-1: $diag"
echo "$diag" | grep -q "malformed OTel timestamp"       && ok "DG-2 malformed-ts event surfaced"   || fail "DG-2: $diag"
echo "$diag" | grep -q "OTel events lack session scope" && ok "DG-3 unscoped event surfaced per-run" || fail "DG-3: $diag"

# ==================================================================================
# V2 NEW — START hook (hooks/stamp-run.sh) + hooks.json
# ==================================================================================
# The gate name is DERIVED from the payload (event-shape aware), never passed as an arg — the two
# live paths are UserPromptSubmit (user types the slash command) and PreToolUse/Skill (assistant
# auto-invokes, e.g. crucible → design-spec/design-review). Manifests land under
# TOUCHSTONE_METRICS_DIR, off the project tree.
HKD="$TMP/hk"
mkfresh() { rm -rf "$HKD"; }   # isolate each stamp assertion so `find … | head -1` sees only its manifest
manifest() { find "$HKD/runs" -name '*.json' 2>/dev/null | head -1; }

# HK-1: UserPromptSubmit, user TYPES a leading slash gate (short form `/design-review`) → manifest
mkfresh
printf '{"session_id":"hk-sess","cwd":"/some/proj","hook_event_name":"UserPromptSubmit","prompt":"/design-review"}' \
  | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
hm="$(manifest)"
[ -n "$hm" ] && [ "$(jq -r .skill "$hm")" = design-review ] && [ "$(jq -r .session_id "$hm")" = hk-sess ] \
  && [ "$(jq -r .cwd "$hm")" = /some/proj ] && [ "$(jq -r .schema "$hm")" = run-manifest/v1 ] \
  && ok "HK-1 UserPromptSubmit typed gate → run-manifest with session_id+cwd+skill" || fail "HK-1 manifest wrong: $(cat "$hm" 2>/dev/null)"

# HK-1b: namespaced form + trailing args (`/touchstone:design-spec specs/x.md`) still matches
mkfresh
printf '{"session_id":"s","cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"/touchstone:design-spec specs/x.md"}' \
  | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
[ "$(jq -r .skill "$(manifest)" 2>/dev/null)" = design-spec ] \
  && ok "HK-1b namespaced + args (/touchstone:design-spec …) → stamps design-spec" || fail "HK-1b did not stamp"

# HK-8: PreToolUse/Skill, assistant AUTO-INVOKES the gate → derive skill from .tool_input.skill
mkfresh
printf '{"session_id":"s","cwd":"/p","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"touchstone:anvil"}}' \
  | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
[ "$(jq -r .skill "$(manifest)" 2>/dev/null)" = anvil ] \
  && ok "HK-8 PreToolUse auto-invoke (crucible-style) → stamps anvil from tool_input.skill" || fail "HK-8 auto-invoke not stamped"

# HK-9: NON-gate prompt (mid-sentence "/anvil", not a leading command) → no stamp, exit 0
mkfresh
printf '{"cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"測試 /anvil 一下"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$(manifest)" ] && ok "HK-9 mid-sentence /anvil (not leading command) → no stamp" || fail "HK-9 false-stamped a chat mention (rc=$rc)"

# HK-10: word-boundary — "/anvilx" must NOT match the anvil gate
mkfresh
printf '{"cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"/anvilx"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
[ -z "$(manifest)" ] && ok "HK-10 /anvilx (word-boundary) → no stamp" || fail "HK-10 matched a non-gate command"

# HK-11: PreToolUse for a NON-gate skill (a composite reviewer) → no stamp
mkfresh
printf '{"cwd":"/p","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"skill":"touchstone:cross-provider-reviewer"}}' \
  | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
[ -z "$(manifest)" ] && ok "HK-11 auto-invoked non-gate skill → no stamp" || fail "HK-11 stamped a non-gate skill"

# HK-12: multi-line prompt — a gate at the start of a LATER line must NOT stamp (only the first
# line is a command). Regression for the grep-anchors-every-line false-stamp.
mkfresh
# jq builds the payload so the embedded newline is properly \n-escaped inside the JSON string
# (a raw newline from printf would be invalid JSON → jq-parse-fail → a FALSE pass here).
jq -nc '{cwd:"/p",hook_event_name:"UserPromptSubmit",prompt:"some context\n/anvil"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
[ -z "$(manifest)" ] && ok "HK-12 gate on line 2 of a multi-line prompt → no stamp" || fail "HK-12 false-stamped a non-leading line"
# HK-13: multi-line prompt whose FIRST line IS the command still stamps (trailing lines don't break it)
mkfresh
jq -nc '{cwd:"/p",hook_event_name:"UserPromptSubmit",prompt:"/anvil specs/x.md\nplease run this"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
[ "$(jq -r .skill "$(manifest)" 2>/dev/null)" = anvil ] && ok "HK-13 command on line 1 of a multi-line prompt → stamps anvil" || fail "HK-13 missed a leading multi-line command"
# HK-14: rapid back-to-back stamps → two manifests with DISTINCT run_ids (collision-resistance
# exercised live, not just visible in the id formula; manifests are named <run_id>.json so a
# collision would clobber to one file)
mkfresh
printf '{"session_id":"s","cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"/anvil"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
printf '{"session_id":"s","cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"/anvil"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"
nman="$(find "$HKD/runs" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')"
nids="$(find "$HKD/runs" -name '*.json' -exec jq -r .run_id {} \; 2>/dev/null | sort -u | grep -c .)"
[ "$nman" = 2 ] && [ "$nids" = 2 ] && ok "HK-14 rapid double stamp → 2 manifests, distinct run_ids" || fail "HK-14 manifests=$nman distinct_ids=$nids"

# HK-2: SAFETY — empty stdin → exit 0 (never blocks the command)
mkfresh
printf '' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"; [ $? -eq 0 ] && ok "HK-2 empty payload → exit 0 (never blocks the command)" || fail "HK-2 empty payload nonzero exit"
# HK-3: unknown event / no gate derivable → exit 0, no write
mkfresh
printf '{"cwd":"/x","hook_event_name":"SessionStart"}' | TOUCHSTONE_METRICS_DIR="$HKD" bash "$HOOK"; [ $? -eq 0 ] && ok "HK-3 non-gate event → exit 0" || fail "HK-3 nonzero"
# HK-7 (Codex M2): SECURITY — pre-existing symlink runs dir → hook bails, never writes THROUGH it
SL="$TMP/sl"; mkdir -p "$SL" "$TMP/sl-target"; ln -s "$TMP/sl-target" "$SL/runs"
printf '{"session_id":"x","cwd":"/p","hook_event_name":"UserPromptSubmit","prompt":"/anvil"}' | TOUCHSTONE_METRICS_DIR="$SL" bash "$HOOK"; rc=$?
[ "$rc" -eq 0 ] && [ -z "$(find "$TMP/sl-target" -name '*.json' 2>/dev/null)" ] \
  && ok "HK-7 symlinked runs dir → hook bails (exit 0, nothing written through symlink)" || fail "HK-7 wrote through symlink or nonzero (rc=$rc)"
# HK-4: hooks.json valid + registers exactly the two LIVE paths (UserPromptSubmit + PreToolUse/Skill)
HJ="$REPO_ROOT/hooks/hooks.json"
jq empty "$HJ" 2>/dev/null && ok "HK-4 hooks.json is valid JSON" || fail "HK-4 hooks.json invalid"
events="$(jq -r '.hooks | keys[]' "$HJ" | sort | tr '\n' ',')"
[ "$events" = "PreToolUse,UserPromptSubmit," ] && ok "HK-5 registers UserPromptSubmit + PreToolUse only (no dead UserPromptExpansion)" || fail "HK-5 events=$events"
[ "$(jq -r '.hooks.PreToolUse[0].matcher' "$HJ")" = Skill ] && ok "HK-5b PreToolUse matcher=Skill (auto-invoke path)" || fail "HK-5b wrong matcher"
jq -e '[.. | objects | select(has("command")) | .command | (test("stamp-run.sh") or test("run-project-checks.sh"))] | all' "$HJ" >/dev/null \
  && ok "HK-6 every hook command invokes a known touchstone hook script (stamp-run / run-project-checks)" || fail "HK-6 command wiring"

# ==================================================================================
# AC-23 (live-bearing) + REAL-DATA FIDELITY — committed real OTel fixture
# ==================================================================================
OTEL_FIX="$FIX/otel-export.jsonl"
if [ -f "$OTEL_FIX" ]; then
  head -20 "$OTEL_FIX" "$FIX/otel-export.provenance.txt" 2>/dev/null | grep -qiE 'otelcol|CLAUDE_CODE_ENABLE_TELEMETRY|capture date' \
    && ok "AC-23 OTel fixture carries capture provenance" || fail "AC-23 OTel fixture lacks provenance header"
  REAL_SID="8211ec02-5d02-4b22-b4be-4433805cef30"
  norm_out="$(otel_normalize "$OTEL_FIX")"
  sub_ev="$(printf '%s\n' "$norm_out" | jq -c 'select(.query_source | startswith("agent:"))' | head -1)"
  [ -n "$sub_ev" ] && ok "REAL-1 otel_normalize emits >= 1 subagent event from real OTLP fixture" || fail "REAL-1 none"
  ts_real="$(printf '%s' "$sub_ev" | jq -r '.ts')"
  awk -v t="$ts_real" 'BEGIN{ exit !(t > 1000000000 && t < 2000000000) }' && ok "REAL-2 normalized ts is epoch seconds; got=$ts_real" || fail "REAL-2 ts=$ts_real"
  an_real="$(printf '%s' "$sub_ev" | jq -r '.agent_name')"
  [ -n "$an_real" ] && [ "$an_real" != "null" ] && ok "REAL-3 non-null agent_name: $an_real" || fail "REAL-3 agent_name=$an_real"
  printf '%s' "$sub_ev" | jq -e '(.tokens | type) == "number" and (.cost_usd | type) == "number"' >/dev/null 2>&1 && ok "REAL-4 tokens/cost_usd numeric" || fail "REAL-4 $sub_ev"
  scoped_real="$(otel_scoped_events "$OTEL_FIX" "$REAL_SID" "")"
  [ -n "$scoped_real" ] && ok "REAL-5 otel_scoped_events auto-detects OTLP + scopes real session" || fail "REAL-5 none"
  sum_real="$(build_session_summary "$tr" "$co" "$OTEL_FIX" "$REAL_SID" "")"
  printf '%s' "$sum_real" | jq -e '.by_agent | type == "array"' >/dev/null 2>&1 && ok "REAL-6 by_agent is real JSON array (not [unverified])" || fail "REAL-6 $(printf '%s' "$sum_real" | jq -r '.by_agent')"
  real_agent="$(printf '%s' "$sum_real" | jq -r '.by_agent[0].agent_name // empty')"
  [ -n "$real_agent" ] && ok "REAL-6b by_agent[0].agent_name=$real_agent (real subagent end-to-end)" || fail "REAL-6b none"
else
  echo "WARN - AC-23 live-bearing: OTel real capture not present → [unverified] carried to Evidence Reckoning"
fi

# ==================================================================================
# DS-1 (regression) — single sentinel home + closed-list guard
# ==================================================================================
outside="$(awk '
  /^UNVERIFIED\(\)/ { in_fn=1; depth=0 }
  in_fn { for (i=1;i<=length($0);i++){ c=substr($0,i,1); if(c=="{")depth++; if(c=="}"){depth--; if(depth==0)in_fn=0} } next }
  /\[unverified:/ { print }
' "$TOOL" | wc -l | tr -d ' ')"
[ "$outside" -eq 0 ] && ok "DS-1 no [unverified: literals outside UNVERIFIED() body" || fail "DS-1 $outside stray literal(s)"
err="$(UNVERIFIED 'totally made up reason' 2>&1)"; rc=$?
[ "$rc" -ne 0 ] && echo "$err" | grep -qi "off-list" && ok "DS-1 closed-list guard rejects off-list reason" || fail "DS-1 guard: rc=$rc err=[$err]"

echo ""; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ]
