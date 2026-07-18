#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
val="$here/../check-challenge-result.py"
spec="$here/floor-fixtures/req-happy.md"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
write() { printf '%s' "$2" > "$tmp/$1"; }

NV="$(bash "$here/../spec-extract.sh" normalizer-version)"
# A canonical valid v3 finding (carries the required type + provenance tags).
F='{"id":"F-1","marker":"[NEEDS CLARIFICATION: which X?]","req":"REQ-1","type":"coverage-gap","provenance":"original"}'

write valid.json          '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":['"$F"']}'
write extra-top.json      '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","verdict":"complete","findings":[]}'
write extra-finding.json  '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","type":"coverage-gap","provenance":"original","verdict":"complete"}]}'
write missing-field.json  '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","findings":[]}'
write bad-req.json        '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-9","type":"coverage-gap","provenance":"original"}]}'
write bad-marker.json     '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: unclosed","req":"REQ-1","type":"coverage-gap","provenance":"original"}]}'
write bad-type.json       '{"schema_version":true,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[]}'
write malformed.json      '{not json'
# v3 enum guards: type + provenance must be from their fixed sets, else BLOCK.
write bad-finding-type.json '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","type":"polish","provenance":"original"}]}'
write bad-provenance.json   '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","type":"refinement","provenance":"invented"}]}'
write missing-provenance.json '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","type":"real-defect"}]}'

chk() { # want_rc jsonfile want_sub name
  local out rc; out="$(python3 "$val" --skip-freshness "$spec" "$tmp/$2" 2>&1)"; rc=$?
  [ "$rc" -eq "$1" ] || { echo "FAIL $4: rc want=$1 got=$rc ($out)"; fail=$((fail+1)); return; }
  printf '%s' "$out" | grep -qF "$3" || { echo "FAIL $4: missing '$3' ($out)"; fail=$((fail+1)); return; }
  echo "ok $4"
}
chk 0 valid.json              "ok"          valid
chk 1 extra-top.json          "extra"       extra-top
chk 1 extra-finding.json      "extra"       extra-finding
chk 1 missing-field.json      "missing"     missing-field
chk 1 bad-req.json            "REQ-9"       bad-req
chk 1 bad-marker.json         "marker"      bad-marker
chk 1 bad-type.json           "type"        bad-type
chk 1 malformed.json          "parse"       malformed
chk 1 bad-finding-type.json   "type"        bad-finding-type
chk 1 bad-provenance.json     "provenance"  bad-provenance
chk 1 missing-provenance.json "missing"     missing-provenance
DG="$(bash "$here/../spec-extract.sh" digest "$spec")"
write fresh-valid.json '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"'"$DG"'","findings":['"$F"']}'
write stale.json       '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"deadbeef","findings":[]}'
write equal-ids.json   '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"A","input_digest":"'"$DG"'","findings":[]}'
chkF() { local out rc; out="$(python3 "$val" "$spec" "$tmp/$2" 2>&1)"; rc=$?
  [ "$rc" -eq "$1" ] || { echo "FAIL $4: rc want=$1 got=$rc ($out)"; fail=$((fail+1)); return; }
  printf '%s' "$out" | grep -qF "$3" || { echo "FAIL $4: missing '$3' ($out)"; fail=$((fail+1)); return; }; echo "ok $4"; }
chkF 0 fresh-valid.json "ok"          fresh-valid
chkF 1 stale.json       "stale"       stale
chkF 1 equal-ids.json   "independent" equal-ids

# uniqueness and empty finding id cases
write dup-finding-id.json '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","type":"coverage-gap","provenance":"original"},{"id":"F-1","marker":"[NEEDS CLARIFICATION: r]","req":"REQ-1","type":"refinement","provenance":"fix-induced"}]}'
write empty-finding-id.json '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","type":"coverage-gap","provenance":"original"}]}'
chk 1 dup-finding-id.json  "duplicate"  dup-finding-id
chk 1 empty-finding-id.json "empty"     empty-finding-id

# v1 legacy → BLOCK with "re-challenge under v3"
echo '{"schema_version":1,"author_id":"a","challenger_id":"b","input_digest":"x","findings":[]}' > "$tmp/_v1.json"
_out="$(python3 "$val" --skip-freshness "$spec" "$tmp/_v1.json" 2>&1)"; _rc=$?
if [ "$_rc" -ne 0 ] && echo "$_out" | grep -qi "re-challenge under v3"; then
  echo "ok v1-blocked"
else
  echo "FAIL v1 msg: [$_out]"; fail=$((fail+1))
fi

# v2 now legacy (hard cut to v3) → BLOCK with "legacy"
echo '{"schema_version":2,"normalizer_version":'"$NV"',"author_id":"a","challenger_id":"b","input_digest":"x","findings":[]}' > "$tmp/_v2.json"
_out2="$(python3 "$val" --skip-freshness "$spec" "$tmp/_v2.json" 2>&1)"; _rc2=$?
if [ "$_rc2" -ne 0 ] && echo "$_out2" | grep -qi "legacy"; then
  echo "ok v2-blocked"
else
  echo "FAIL v2 msg: [$_out2]"; fail=$((fail+1))
fi

# boolean normalizer_version → BLOCK
echo '{"schema_version":3,"normalizer_version":true,"author_id":"a","challenger_id":"b","input_digest":"x","findings":[]}' > "$tmp/_vb.json"
if python3 "$val" --skip-freshness "$spec" "$tmp/_vb.json" >/dev/null 2>&1; then
  echo "FAIL bool nv passed"; fail=$((fail+1))
else
  echo "ok bool-nv-rejected"
fi

# v3 happy: build record from live digest + normalizer-version
_dg="$(bash "$here/../spec-extract.sh" digest "$spec")"
_nv="$(bash "$here/../spec-extract.sh" normalizer-version)"
echo '{"schema_version":3,"normalizer_version":'"$_nv"',"author_id":"a","challenger_id":"b","input_digest":"'"$_dg"'","findings":[]}' > "$tmp/_v3ok.json"
if python3 "$val" "$spec" "$tmp/_v3ok.json" >/dev/null 2>&1; then
  echo "ok v3-happy"
else
  echo "FAIL v3-happy"; fail=$((fail+1))
fi

# normalizer_version VALUE mismatch → BLOCK with "mismatch"
# Use nv=0 which is guaranteed != current (always 1); schema_version=3; otherwise valid.
write nv-mismatch.json '{"schema_version":3,"normalizer_version":0,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[]}'
chk 1 nv-mismatch.json "mismatch" nv-value-mismatch
# empty-question marker [NEEDS CLARIFICATION:] → BLOCK (marker must have non-empty question)
write empty-marker.json '{"schema_version":3,"normalizer_version":'"$NV"',"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION:]","req":"REQ-1","type":"coverage-gap","provenance":"original"}]}'
chk 1 empty-marker.json "marker" empty-marker-rejected
# producer↔validator schema consistency (the gap that slipped Phase 3.1's first pass:
# the validator was migrated but the design-spec PRODUCER template still wrote the old version).
# Guard that the record-writing skill template declares the SAME schema_version this
# validator requires, and carries normalizer_version.
prod="$here/../../skills/design-spec/references/draft-workflow.md"
if [ -f "$prod" ]; then
  prod_sv="$(grep -oE '"schema_version": ?[0-9]+' "$prod" | grep -oE '[0-9]+' | head -1)"
  [ "$prod_sv" = "3" ] && echo "ok producer-schema-matches-validator" || { echo "FAIL design-spec producer writes schema_version '$prod_sv', validator requires 3"; fail=$((fail+1)); }
  grep -q "normalizer_version" "$prod" && echo "ok producer-has-normalizer-version" || { echo "FAIL producer template missing normalizer_version"; fail=$((fail+1)); }
else echo "ok producer-guard-skipped (template absent)"; fi
[ "$fail" -eq 0 ] && { echo ALL GREEN; exit 0; } || { echo "RED: $fail"; exit 1; }
