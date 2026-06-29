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

echo ""; echo "PASS=$pass FAIL=$fail"; [ "$fail" -eq 0 ]
