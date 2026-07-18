#!/usr/bin/env bash
# check-evidence-reckoning.sh — Evidence Reckoning table validator (epic close gate).
# Usage: bash check-evidence-reckoning.sh <index-path> <spec-path>
#
# Reads the ## Evidence Reckoning table from the epic index file and applies
# the five blocking rules from epic-driven-roadmap references/close.md § Evidence Reckoning.
# Non-zero exit means at least one BLOCK rule fired; prints BLOCK: lines per violation.
#
# COVERAGE HONESTY — which rules are deterministic vs heuristic/uncovered:
#   R1 deterministic : non-live-bearing row, no Covered-by + no [unverified] + no waiver
#   R2 HEURISTIC     : live-bearing row, Covered-by contains static-proxy keywords
#                      (grep / doc-grep / mock / env-faked / deployed-file).
#                      Only negative detection — the script cannot positively verify that
#                      a "live artifact with provenance (producer + commit/timestamp)" claim
#                      is genuine. A well-worded static-proxy string may evade this check.
#   R3 deterministic : live-bearing row, Covered-by is empty OR [unverified] present
#                      OR waiver present (all three are "unavailable" for live-bearing ACs)
#   R4 deterministic : [unverified] or waiver present, Issue column is empty
#   R5 deterministic : AC id in spec has no matching row in the Evidence Reckoning table
#
# NOT COVERED: verifying that the live-artifact content is actually live vs stale;
#              R2 catches only explicit static-proxy keywords (heuristic, not exhaustive).
set -uo pipefail

[ $# -eq 2 ] || { echo "usage: check-evidence-reckoning.sh <index-path> <spec-path>" >&2; exit 2; }
index="$1"; spec="$2"
[ -f "$index" ] || { echo "FAIL: index not found: $index" >&2; exit 2; }
[ -f "$spec"  ] || { echo "FAIL: spec not found: $spec" >&2; exit 2; }

blocks=0
block() { echo "BLOCK: $*"; blocks=$((blocks+1)); }

# ── Extract Evidence Reckoning table data rows ────────────────────────────────
# Columns (1-based, pipe-split):
#   a[2]=AC  a[3]=Covered-by  a[4]=[unverified:reason]  a[5]=live-bearing?  a[6]=waiver  a[7]=Issue
# Outputs: tab-delimited (AC, Covered-by, unverified, live-bearing, waiver, Issue)
table_data="$(awk '
  /^## Evidence Reckoning[[:space:]]*$/ { inreck=1; next }
  inreck && /^## / { inreck=0 }
  !inreck { next }
  /^\|/ {
    # skip separator rows (only dashes, pipes, spaces, colons)
    if ($0 ~ /^\|[-| :]+\|?$/) next
    n=split($0,a,"|")
    ac=a[2]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",ac)
    # skip header row (first cell literally "AC")
    if (ac == "AC") next
    # must look like an AC id to be a data row
    if (ac !~ /^AC-[0-9]+$/) next
    cov=a[3]; unv=a[4]; lb=a[5]; wav=a[6]; iss=a[7]
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",cov)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",unv)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",lb)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",wav)
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",iss)
    printf "%s\002%s\002%s\002%s\002%s\002%s\n", ac, cov, unv, lb, wav, iss
  }
' "$index")"

if [ -z "$table_data" ]; then
  block "## Evidence Reckoning section absent or contains no data rows"
  echo "BLOCKED: $blocks rule(s) fired"; exit 1
fi

# ── Extract AC ids from spec (draft spec → empty set, R5 trivially passes) ───
# Handles both legacy (index table AC-N cell / ### AC-N heading) and
# REQ-based (index pair column 2 / #### AC-N heading) spec formats.
spec_status="$(awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^status:/{print tolower($2)}' "$spec")"
if [ "${spec_status:-}" = "draft" ]; then
  spec_acs=""
else
  spec_acs="$(awk '
    /^```/ { fence=!fence; next }
    fence  { next }
    /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
    inac && /^## / { inac=0 }
    !inac  { next }
    /^[[:space:]]*\|/ {
      n=split($0,a,"|")
      for(i=2;i<=n-1;i++){
        cell=a[i]; gsub(/^[[:space:]]+|[[:space:]]+$/,"",cell)
        if(cell ~ /^AC-[0-9]+$/) print cell
      }
      next
    }
    /^#{3,4}[[:space:]]+AC-[0-9]+/ { match($0,/AC-[0-9]+/); print substr($0,RSTART,RLENGTH) }
  ' "$spec" | sort -u)"
fi

# Track which ACs appear in the reckoning table (for R5)
reckoned_acs=""

# ── Apply rules per data row ──────────────────────────────────────────────────
while IFS=$'\002' read -r ac cov unv lb wav iss; do
  [ -n "$ac" ] || continue
  reckoned_acs="$reckoned_acs $ac "

  is_live=0
  [ "$lb" = "yes" ] && is_live=1

  if [ "$is_live" -eq 1 ]; then
    # R3: live-bearing row with empty Covered-by → BLOCK
    if [ -z "$cov" ]; then
      block "$ac: live-bearing row has no Covered-by evidence"
    fi
    # R3: live-bearing row carries [unverified] (unavailable) → BLOCK
    if printf '%s' "$unv" | grep -q '\[unverified'; then
      block "$ac: live-bearing row carries [unverified] (unavailable for live-bearing ACs — defer AC to later phase)"
    fi
    # R3: live-bearing row has waiver (unavailable) → BLOCK
    if [ -n "$wav" ]; then
      block "$ac: live-bearing row has a waiver (waiver unavailable for live-bearing ACs)"
    fi
    # R2 (heuristic): Covered-by matches static-proxy keywords
    if [ -n "$cov" ] && printf '%s' "$cov" | grep -qiE 'grep|doc-grep|mock|env-faked|deployed-file|static.proxy'; then
      block "$ac: live-bearing row Covered-by appears to reference a static proxy (grep/mock/env-faked/deployed-file) — a live artifact with provenance (producer + commit/timestamp) is required"
    fi
  else
    # R1: non-live-bearing row with no Covered-by AND no [unverified] AND no waiver → BLOCK
    has_cov=0; has_unv=0; has_wav=0
    [ -n "$cov" ] && has_cov=1
    printf '%s' "$unv" | grep -q '\[unverified' && has_unv=1 || true
    [ -n "$wav" ] && has_wav=1
    if [ "$has_cov" -eq 0 ] && [ "$has_unv" -eq 0 ] && [ "$has_wav" -eq 0 ]; then
      block "$ac: no Covered-by, no [unverified], and no waiver — row cannot support close"
    fi
  fi

  # R4: [unverified] or waiver present, Issue column is empty → BLOCK
  has_unv2=0; has_wav2=0
  printf '%s' "$unv" | grep -q '\[unverified' && has_unv2=1 || true
  [ -n "$wav" ] && has_wav2=1
  if [ "$((has_unv2 + has_wav2))" -gt 0 ] && [ -z "$iss" ]; then
    block "$ac: [unverified] or waiver present but Issue column is empty — file/link a debt issue before close"
  fi

done <<< "$table_data"

# R5: AC id in spec not reckoned → BLOCK
for ac in $spec_acs; do
  case "$reckoned_acs" in
    *" $ac "*) ;;
    *) block "$ac: appears in spec but has no row in Evidence Reckoning table (un-reckoned AC)" ;;
  esac
done

if [ "$blocks" -eq 0 ]; then
  echo "pass: Evidence Reckoning table satisfies all mechanical blocking rules"
  exit 0
fi
echo "BLOCKED: $blocks rule(s) fired"
exit 1
