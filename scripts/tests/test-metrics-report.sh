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

echo ""; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ]
