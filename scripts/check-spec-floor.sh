#!/usr/bin/env bash
# Structural-floor checker for design specs (testing-strategy AC-11).
# Validates STANDING artifact state only — does NOT judge coverage, read
# commit deltas, or parse test semantics (that is the reviewer's job).
#
# Contract (spec Interfaces §4):
#   input : a spec file path
#   parse : an AC is an index-table row whose first cell matches /^AC-\d+$/;
#           "enumerable" = every index row has a matching `### AC-N` body block
#           and every `### AC-N` body block has a matching index row.
#   checks: AC set enumerable (index <-> body agree); AC ids unique; every inline
#           `[unverified: ...]` has a non-empty reason.
#   draft : a `status: draft` spec is exempt -> exit 0 "skipped: draft spec".
#   error : no AC index table in a non-draft spec -> exit non-zero "no AC table".
#   output: exit 0 + "pass" | exit non-zero + a violation list (with AC ids).
set -uo pipefail

[ $# -eq 1 ] || { echo "usage: check-spec-floor.sh <spec-path>" >&2; exit 2; }
spec="$1"
[ -f "$spec" ] || { echo "FAIL: file not found: $spec" >&2; exit 2; }

# draft exemption — read frontmatter status (between the first two `---` lines)
status="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^status:/{print tolower($2)}' "$spec")"
if [ "$status" = "draft" ]; then echo "skipped: draft spec"; exit 0; fi

violations=0
note() { echo "VIOLATION: $*"; violations=$((violations+1)); }

# AC ids from the index table — first pipe-delimited cell == AC-N (RAW, may repeat)
index_raw="$(awk -F'|' '
  /^[[:space:]]*\|/ {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
    if ($2 ~ /^AC-[0-9]+$/) print $2
  }' "$spec")"

# AC ids from body blocks — ### AC-N ... (RAW, may repeat)
body_raw="$(awk '
  /^###[[:space:]]+AC-[0-9]+/ { match($0,/AC-[0-9]+/); print substr($0,RSTART,RLENGTH) }
' "$spec")"

# de-duplicated, empty-line-stripped sets for the cross-check
index_ids="$(printf '%s\n' "$index_raw" | sed '/^$/d' | sort -u)"
body_ids="$(printf '%s\n' "$body_raw"  | sed '/^$/d' | sort -u)"

# no AC index table in a non-draft spec -> error
if [ -z "$index_ids" ]; then echo "FAIL: no AC table"; exit 1; fi

# AC ids must be UNIQUE — a reused AC-N breaks the 1:1 enumerable contract
# (set-equality alone would not catch it; sort -u collapses the dupe). Detect on
# the raw lists with `uniq -d`.
for id in $(printf '%s\n' "$index_raw" | sed '/^$/d' | sort | uniq -d); do
  note "$id appears more than once in the index table (AC ids must be unique)"
done
for id in $(printf '%s\n' "$body_raw" | sed '/^$/d' | sort | uniq -d); do
  note "$id has more than one '### $id' body block (AC ids must be unique)"
done

# enumerable — index <-> body agree both ways
for id in $index_ids; do
  printf '%s\n' "$body_ids" | grep -qx "$id" || note "$id in index but no '### $id' body block"
done
for id in $body_ids; do
  printf '%s\n' "$index_ids" | grep -qx "$id" || note "$id has a body block but no index row"
done

# every inline [unverified: ...] must have a non-empty reason; name the nearest AC
empty_unverified="$(awk '
  /^###[[:space:]]+AC-[0-9]+/ { match($0,/AC-[0-9]+/); cur=substr($0,RSTART,RLENGTH) }
  /\[unverified:[[:space:]]*\]/ { print (cur=="" ? "(no AC)" : cur) }
' "$spec")"
for id in $empty_unverified; do note "empty [unverified] reason under $id"; done

if [ "$violations" -eq 0 ]; then echo "pass"; exit 0; fi
echo "RED: $violations violation(s)"; exit 1
