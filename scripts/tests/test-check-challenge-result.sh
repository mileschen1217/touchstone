#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
val="$here/../check-challenge-result.py"
spec="$here/floor-fixtures/req-happy.md"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0
write() { printf '%s' "$2" > "$tmp/$1"; }

write valid.json          '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: which X?]","req":"REQ-1"}]}'
write extra-top.json      '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"x","verdict":"complete","findings":[]}'
write extra-finding.json  '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-1","verdict":"complete"}]}'
write missing-field.json  '{"schema_version":1,"author_id":"A","challenger_id":"B","findings":[]}'
write bad-req.json        '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: q]","req":"REQ-9"}]}'
write bad-marker.json     '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: unclosed","req":"REQ-1"}]}'
write bad-type.json       '{"schema_version":true,"author_id":"A","challenger_id":"B","input_digest":"x","findings":[]}'
write malformed.json      '{not json'

chk() { # want_rc jsonfile want_sub name
  local out rc; out="$(python3 "$val" --skip-freshness "$spec" "$tmp/$2" 2>&1)"; rc=$?
  [ "$rc" -eq "$1" ] || { echo "FAIL $4: rc want=$1 got=$rc ($out)"; fail=$((fail+1)); return; }
  printf '%s' "$out" | grep -qF "$3" || { echo "FAIL $4: missing '$3' ($out)"; fail=$((fail+1)); return; }
  echo "ok $4"
}
chk 0 valid.json         "ok"      valid
chk 1 extra-top.json     "extra"   extra-top
chk 1 extra-finding.json "extra"   extra-finding
chk 1 missing-field.json "missing" missing-field
chk 1 bad-req.json       "REQ-9"   bad-req
chk 1 bad-marker.json    "marker"  bad-marker
chk 1 bad-type.json      "type"    bad-type
chk 1 malformed.json     "parse"   malformed
DG="$(bash "$here/../spec-extract.sh" digest "$spec")"
write fresh-valid.json '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"'"$DG"'","findings":[{"id":"F-1","marker":"[NEEDS CLARIFICATION: which X?]","req":"REQ-1"}]}'
write stale.json       '{"schema_version":1,"author_id":"A","challenger_id":"B","input_digest":"deadbeef","findings":[]}'
write equal-ids.json   '{"schema_version":1,"author_id":"A","challenger_id":"A","input_digest":"'"$DG"'","findings":[]}'
chkF() { local out rc; out="$(python3 "$val" "$spec" "$tmp/$2" 2>&1)"; rc=$?
  [ "$rc" -eq "$1" ] || { echo "FAIL $4: rc want=$1 got=$rc ($out)"; fail=$((fail+1)); return; }
  printf '%s' "$out" | grep -qF "$3" || { echo "FAIL $4: missing '$3' ($out)"; fail=$((fail+1)); return; }; echo "ok $4"; }
chkF 0 fresh-valid.json "ok"          fresh-valid
chkF 1 stale.json       "stale"       stale
chkF 1 equal-ids.json   "independent" equal-ids
[ "$fail" -eq 0 ] && { echo ALL GREEN; exit 0; } || { echo "RED: $fail"; exit 1; }
