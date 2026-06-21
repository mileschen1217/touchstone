#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
pc="$here/../design-review-precheck.sh"
src="$here/floor-fixtures/req-happy.md"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
cp "$src" "$tmp/spec.md"
DG="$(bash "$here/../spec-extract.sh" digest "$tmp/spec.md")"
good='{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"'"$DG"'","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q?]","req":"REQ-1"}]}'

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
printf '%s' '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"old","findings":[]}' > "$tmp/spec.challenge.json"
run "$tmp/spec.md" 1 "BLOCK" block-stale
# structural failure (zero-AC) → BLOCK regardless of challenge
cp "$here/floor-fixtures/req-zero-ac.md" "$tmp/zero.md"
run "$tmp/zero.md" 1 "structural" block-structural
# legacy spec (no requirements) → PROCEED without a challenge-result
cp "$here/floor-fixtures/req-legacy.md" "$tmp/legacy.md"
run "$tmp/legacy.md" 0 "PRE-CHECK OK" proceed-legacy
[ "$fail" -eq 0 ] && { echo ALL GREEN; exit 0; } || { echo "RED: $fail"; exit 1; }
