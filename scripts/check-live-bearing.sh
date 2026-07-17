#!/usr/bin/env bash
# check-live-bearing.sh <spec> — STRUCTURAL-ONLY check over a spec's Live-bearing
# declaration. NEVER renders the semantic live-bearing verdict (that stays reviewer
# judgment). Exit 0 = declaration integrity holds + no orphan (advisory candidate
# lines may still print, non-fatal). Non-zero + report on orphan / no-declaration /
# malformed / new-vs-legacy disagreement.
#
# TWO ACCEPTED HOMES (P2 REQ-8):
#   new form    — the `- **Live-bearing AC IDs:**` line inside `## Acceptance Criteria`
#                 (authoritative), paired with the Index Live-bearing column.
#   legacy form — the same line inside `## Verification Strategy` (pre-P2 specs,
#                 grandfathered).
# A spec carrying NEITHER form fails (same class as today's missing-VS exit). When
# BOTH are present the new form is authoritative; the two MUST declare the same id
# set or the check fails.
#
# Candidate heuristic grep signals (structural, advisory — NOT semantic verdict):
#   deployed / real session / real Bash / live session / out-of-band /
#   real .*session / really fires — reviewers apply the full behavioural predicate
#   (skills/_shared/inject/live-bearing-predicate.md); this check only surfaces
#   candidates for their attention.
set -uo pipefail
spec="${1:-}"; [ -f "$spec" ] || { echo "usage: check-live-bearing.sh <spec>" >&2; exit 2; }

# Extract the Live-bearing value scoped to one `## <section>` .. next `## `.
# Prints the raw value (may be empty) for the FIRST matching line in that section.
extract_lb() {
  awk -v sec="$1" '
    $0 ~ ("^## " sec "([[:space:]]*$)") { inx=1; next }
    inx && /^## / { inx=0 }
    inx && /Live-bearing AC IDs:\*\*/ {
      sub(/.*Live-bearing AC IDs:\*\*[[:space:]]*/, ""); sub(/[[:space:]]*$/, "")
      print; exit
    }
  ' "$2"
}

# Normalize a raw value to its leading well-formed id-list (or `none`), discarding
# trailing prose regardless of separator (arrow / em-dash / hyphen / bare title).
normalize_lb() {
  local raw="$1" ext
  ext="$(printf '%s' "$raw" | grep -oE '^(none|AC-[0-9]+([, ]+AC-[0-9]+)*)' || true)"
  [ -n "$ext" ] && printf '%s' "$ext" || printf '%s' "$raw"
}
# Sorted id set (for the both-forms agreement compare); `none` → empty set.
id_set() { printf '%s' "$1" | grep -oE 'AC-[0-9]+' | sort -u; }

new_raw="$(extract_lb "Acceptance Criteria" "$spec")"
legacy_raw="$(extract_lb "Verification Strategy" "$spec")"

have_new=0; have_legacy=0
[ -n "$new_raw" ] && have_new=1
[ -n "$legacy_raw" ] && have_legacy=1

if [ "$have_new" -eq 0 ] && [ "$have_legacy" -eq 0 ]; then
  echo "[unverified: no live-bearing declaration] $spec (neither AC-section intro nor Verification Strategy declares Live-bearing AC IDs)" >&2
  exit 1
fi

# New form authoritative when present; on both-present, sets must agree.
if [ "$have_new" -eq 1 ] && [ "$have_legacy" -eq 1 ]; then
  if [ "$(id_set "$(normalize_lb "$new_raw")")" != "$(id_set "$(normalize_lb "$legacy_raw")")" ]; then
    echo "[disagreement] new-form and legacy-form Live-bearing AC ID sets differ — reconcile them" >&2
    exit 1
  fi
fi
if [ "$have_new" -eq 1 ]; then val="$(normalize_lb "$new_raw")"; else val="$(normalize_lb "$legacy_raw")"; fi

# Validate syntax: `none` OR a list of AC-N tokens.
if [ "$val" = "none" ]; then
  listed=""
elif printf '%s' "$val" | grep -qE '^(AC-[0-9]+)([, ]+AC-[0-9]+)*$'; then
  listed="$(printf '%s' "$val" | grep -oE 'AC-[0-9]+')"
else
  echo "[format error] Live-bearing AC IDs value is neither 'none' nor an AC-N list: '$val'" >&2
  exit 1
fi

# Orphan check: each listed AC-N must have a matching #### AC-N heading.
rc=0
for ac in $listed; do
  grep -qE "^#### $ac( |—|\$)" "$spec" || { echo "[orphan] declaration lists $ac but no '#### $ac' heading" >&2; rc=1; }
done

# Advisory candidate sweep (ALWAYS runs, even under `none`).
signals='deployed|real session|real Bash|live session|out-of-band|real .*session|really fires'
awk -v sig="$signals" '
  /^#### AC-/ { ac=$2; body="" }
  /^#### AC-/,/^$/ { body=body" "$0 }
  /^$/ { if (ac!="" && body ~ sig) print ac; ac="" }
  END  { if (ac!="" && body ~ sig) print ac }
' "$spec" | while read -r cand; do
  echo "$listed" | grep -qx "$cand" || echo "[candidate] $cand carries a live-artifact signal but is absent from the declaration (reviewer to judge)"
done

exit "$rc"
