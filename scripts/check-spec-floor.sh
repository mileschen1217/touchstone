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
#   scope : ONLY the `## Acceptance Criteria` section is scanned (from that heading
#           to the next top-level `## ` heading), and fenced code blocks (```)
#           inside it are ignored — so example tables / fenced `### AC-N` snippets
#           elsewhere or in examples cannot pollute the AC set.
#   checks: AC set enumerable (index <-> body agree); AC ids unique; every inline
#           `[unverified: ...]` (in-section, non-fenced) has a non-empty reason.
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

ex="$(dirname "$0")/spec-extract.sh"
reqset="$(bash "$ex" reqs "$spec")"

if [ -n "$reqset" ]; then
  # ---- requirement-bearing path ----
  scan="$(awk '
    /^```/ { fence = !fence; next }
    fence  { next }
    /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
    inac && /^## / { inac=0 }
    !inac  { next }
    /^[[:space:]]*\|/ {
      n=split($0,a,"|"); r=a[2]; c=a[3]
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",r); gsub(/^[[:space:]]+|[[:space:]]+$/,"",c)
      if (r ~ /^REQ-[0-9]+$/ && c ~ /^AC-[0-9]+$/) print "IDXPAIR " r " " c
      next
    }
    /^### Requirement:[[:space:]]+REQ-[0-9]+/ {
      match($0,/REQ-[0-9]+/); cur=substr($0,RSTART,RLENGTH); print "REQHEAD " cur
      bare=$0; gsub(/`[^`]*`/,"",bare)
      if (bare ~ /\[NEEDS CLARIFICATION:[^]]*\]/) print "MARKER"
      if (bare ~ /\[unverified:[[:space:]]*\]/) print "EMPTYUNV"
      next
    }
    /^### / { cur="" }
    /^#### AC-[0-9]+/ { match($0,/AC-[0-9]+/); print "AC " (cur==""?"(none)":cur) " " substr($0,RSTART,RLENGTH) }
    { bare=$0; gsub(/`[^`]*`/,"",bare) }
    bare ~ /\[NEEDS CLARIFICATION:[^]]*\]/ { print "MARKER" }
    bare ~ /\[unverified:[[:space:]]*\]/ { print "EMPTYUNV" }
  ' "$spec")"

  # zero-AC requirement
  for r in $reqset; do
    printf '%s\n' "$scan" | grep -q "^AC $r " || note "$r requirement has no AC"
  done
  # empty [unverified:] reason (carry the existing legacy guarantee onto this path)
  ec="$(printf '%s\n' "$scan" | grep -c '^EMPTYUNV')"
  [ "$ec" -gt 0 ] && note "$ec empty [unverified] reason(s) in the AC section"
  # orphan AC
  for a in $(printf '%s\n' "$scan" | sed -n 's/^AC //p' | awk '$1=="(none)"{print $2}'); do
    note "$a is an orphan AC (no in-scope parent requirement)"
  done
  # duplicate REQ id
  for r in $(printf '%s\n' "$scan" | sed -n 's/^REQHEAD //p' | sort | uniq -d); do
    note "$r is a duplicated requirement id"
  done
  # duplicate AC id in the body (by AC id alone, across parents)
  for a in $(printf '%s\n' "$scan" | sed -n 's/^AC [^ ]* //p' | sort | uniq -d); do
    note "$a is a duplicated AC id"
  done
  # duplicate AC id in the INDEX
  for a in $(printf '%s\n' "$scan" | sed -n 's/^IDXPAIR [^ ]* //p' | sort | uniq -d); do
    note "$a is a duplicated AC id in the index"
  done
  # index <-> body (REQ,AC) set equality
  idx="$(printf '%s\n' "$scan" | sed -n 's/^IDXPAIR //p' | sort -u)"
  bod="$(printf '%s\n' "$scan" | sed -n 's/^AC //p' | awk '$1!="(none)"{print $1" "$2}' | sort -u)"
  while read -r r c; do [ -n "$r" ] && note "(REQ,AC) pair $r/$c in index but not body"; done < <(comm -23 <(printf '%s\n' "$idx") <(printf '%s\n' "$bod"))
  while read -r r c; do [ -n "$r" ] && note "(REQ,AC) pair $r/$c in body but not index"; done < <(comm -13 <(printf '%s\n' "$idx") <(printf '%s\n' "$bod"))
  # unresolved [NEEDS CLARIFICATION] markers
  mk="$(printf '%s\n' "$scan" | grep -c '^MARKER')"
  [ "$mk" -gt 0 ] && note "$mk unresolved [NEEDS CLARIFICATION] clarification(s) in the AC section"
  if [ "$violations" -eq 0 ]; then echo "pass"; exit 0; fi
  echo "RED: $violations violation(s)"; exit 1
fi

# Single stateful scan of the `## Acceptance Criteria` section, ignoring fenced
# code blocks. Emits "INDEX <id>" for index-table rows and "BODY <id>" for
# `### AC-N` headings. Section = from `## Acceptance Criteria` to the next `## `.
scan="$(awk '
  /^```/ { fence = !fence; next }
  fence  { next }
  /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
  inac && /^## / { inac=0 }
  !inac  { next }
  /^[[:space:]]*\|/ {
    split($0, a, "|"); cell=a[2]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
    if (cell ~ /^AC-[0-9]+$/) print "INDEX " cell
    next
  }
  /^###[[:space:]]+AC-[0-9]+/ { match($0,/AC-[0-9]+/); print "BODY " substr($0,RSTART,RLENGTH) }
' "$spec")"

index_raw="$(printf '%s\n' "$scan" | sed -n 's/^INDEX //p')"
body_raw="$(printf '%s\n' "$scan" | sed -n 's/^BODY //p')"

# de-duplicated, empty-line-stripped sets for the cross-check
index_ids="$(printf '%s\n' "$index_raw" | sed '/^$/d' | sort -u)"
body_ids="$(printf '%s\n' "$body_raw"  | sed '/^$/d' | sort -u)"

# no AC index table in a non-draft spec -> error
if [ -z "$index_ids" ]; then echo "FAIL: no AC table"; exit 1; fi

# AC ids must be UNIQUE — a reused AC-N breaks the 1:1 enumerable contract
# (set-equality alone would not catch it; sort -u collapses the dupe).
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

# every in-section, non-fenced inline [unverified: ...] must have a non-empty
# reason; name the nearest AC.
empty_unverified="$(awk '
  /^```/ { fence = !fence; next }
  fence  { next }
  /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
  inac && /^## / { inac=0 }
  !inac  { next }
  /^###[[:space:]]+AC-[0-9]+/ { match($0,/AC-[0-9]+/); cur=substr($0,RSTART,RLENGTH) }
  /\[unverified:[[:space:]]*\]/ { print (cur=="" ? "(no AC)" : cur) }
' "$spec")"
for id in $empty_unverified; do note "empty [unverified] reason under $id"; done

if [ "$violations" -eq 0 ]; then echo "pass"; exit 0; fi
echo "RED: $violations violation(s)"; exit 1
