#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pc="$here/../design-review-precheck.sh"
src="$here/floor-fixtures/req-happy.md"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
cp "$src" "$tmp/spec.md"
DG="$(bash "$here/../spec-extract.sh" digest "$tmp/spec.md")"
NV="$(bash "$here/../spec-extract.sh" normalizer-version)"
good='{"schema_version":2,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"'"$DG"'","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q?]","req":"REQ-1"}]}'

run() { local out rc; out="$(bash "$pc" "$1" 2>&1)"; rc=$?
  [ "$rc" -eq "$2" ] || { echo "FAIL $4: rc want=$2 got=$rc ($out)"; fail=$((fail+1)); return; }
  printf '%s' "$out" | grep -qF "$3" || { echo "FAIL $4: missing '$3' ($out)"; fail=$((fail+1)); return; }; echo "ok $4"; }

# clean: checker passes + valid fresh challenge → PROCEED
printf '%s' "$good" > "$tmp/spec.challenge.json"
run "$tmp/spec.md" 0 "PRE-CHECK OK" proceed
# missing challenge-result on a requirement-bearing spec → BLOCK
rm -f "$tmp/spec.challenge.json"
run "$tmp/spec.md" 1 "missing" block-missing
# malformed challenge-result → BLOCK (fail closed)
printf '%s' '{bad' > "$tmp/spec.challenge.json"
run "$tmp/spec.md" 1 "BLOCK" block-malformed
# stale challenge-result → BLOCK
printf '%s' '{"schema_version":2,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"old","findings":[]}' > "$tmp/spec.challenge.json"
run "$tmp/spec.md" 1 "BLOCK" block-stale
# structural failure (zero-AC) → BLOCK regardless of challenge
cp "$here/floor-fixtures/req-zero-ac.md" "$tmp/zero.md"
run "$tmp/zero.md" 1 "structural" block-structural
# legacy spec (no requirements) → PROCEED without a challenge-result
cp "$here/floor-fixtures/req-legacy.md" "$tmp/legacy.md"
run "$tmp/legacy.md" 0 "PRE-CHECK OK" proceed-legacy
# FIX-2 (AC-8): duplicate REQ-N → BLOCK at FLOOR step (not challenge step), output contains "structural"
cp "$here/floor-fixtures/req-dup-id.md" "$tmp/dup.md"
run "$tmp/dup.md" 1 "structural" block-dup-id-floor
# Also verify it does NOT say "stale" or "challenge" (it's a floor failure, not freshness)
_dup_out="$(bash "$pc" "$tmp/dup.md" 2>&1)" || true
printf '%s' "$_dup_out" | grep -qiE "stale|challenge" && { echo "FAIL block-dup-id-floor: should not mention stale/challenge ($out)"; fail=$((fail+1)); } || echo "ok block-dup-id-floor-no-stale"
# accepted-candidate IS gated (not skipped); draft still skipped.
# macOS mktemp has no --suffix → use a temp DIR with named files (matches repo test convention).
# Capture output before piping to avoid pipefail masking grep's own exit code.
td=$(mktemp -d); trap 'rm -rf "$td"' EXIT
acc="$td/accepted.md"; printf -- '---\nstatus: accepted-candidate\n---\n## Acceptance Criteria\n### Requirement: REQ-1 — x\ntraces-to: US-1\n#### AC-1 — x\n' > "$acc"
_acc_out="$(bash "$pc" "$acc" 2>&1)" || true
if printf '%s' "$_acc_out" | grep -qv "skipped: draft"; then echo "ok: accepted-candidate not draft-skipped"; else echo "FAIL: accepted-candidate skipped"; fail=$((fail+1)); fi
drf="$td/draft.md"; printf -- '---\nstatus: draft\n---\n' > "$drf"
_drf_out="$(bash "$pc" "$drf" 2>&1)" || true
if printf '%s' "$_drf_out" | grep -q "skipped: draft"; then echo "ok: draft still skipped"; else echo "FAIL: draft not skipped"; fail=$((fail+1)); fi
[ "$fail" -eq 0 ] && { echo ALL GREEN; exit 0; } || { echo "RED: $fail"; exit 1; }
