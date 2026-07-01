#!/usr/bin/env bash
# check-live-bearing.sh <spec> — STRUCTURAL-ONLY check over a spec's Verification
# Strategy Live-bearing declaration. NEVER renders the semantic live-bearing verdict
# (that stays reviewer judgment). Exit 0 = VS integrity holds + no orphan (advisory
# candidate lines may still print to stdout, non-fatal). Non-zero + report on
# orphan / no-VS / malformed. Candidate heuristic signals sourced from
# skills/_shared/inject/live-bearing-predicate.md (documented, inspectable).
#
# Candidate heuristic grep signals (structural, advisory — NOT semantic verdict):
#   deployed       — wired/deployed target boundary
#   real session   — real Claude Code session (cannot be discharged offline)
#   real Bash      — real Bash shell invocation (live subprocess)
#   live session   — live/wired session
#   out-of-band    — out-of-band trigger (external)
#   real .*session — "real <adjective> session" variants
#   really fires   — execution that genuinely fires (not a dry-run)
# These are heuristics; the predicate is behavioural — reviewers apply the full
# predicate; this check surfaces candidates for their attention only.
set -uo pipefail
spec="${1:-}"; [ -f "$spec" ] || { echo "usage: check-live-bearing.sh <spec>" >&2; exit 2; }

# 1. Extract the VS section + the Live-bearing value.
vs="$(awk '/^## Verification Strategy/{f=1} f{print}' "$spec")"
if [ -z "$vs" ]; then
  echo "[unverified: no Verification Strategy] $spec" >&2
  exit 1
fi
val="$(printf '%s' "$vs" | sed -n 's/.*Live-bearing AC IDs:\*\*[[:space:]]*//p' | head -1 \
        | sed 's/[[:space:]]*$//')"
# Extract the LEADING well-formed id-list (or `none`), discarding any trailing prose
# regardless of separator (arrow ←, em-dash —, space-hyphen, or a bare title). Extracting
# the valid prefix — rather than stripping at the first separator char — avoids corrupting
# the hyphen INSIDE `AC-1` (a naive `s/-.*//` would). A value that does NOT start with a
# valid token (e.g. `TBD`, `see above`) yields no match → we keep the raw value so the
# format check below fails it (AC-41). Em-dash trailing prose is handled (a real reviewer catch).
extracted="$(printf '%s' "$val" | grep -oE '^(none|AC-[0-9]+([, ]+AC-[0-9]+)*)' || true)"
[ -n "$extracted" ] && val="$extracted"

# 2. Validate syntax: `none` OR a list of AC-N tokens.
if [ "$val" = "none" ]; then
  listed=""
elif printf '%s' "$val" | grep -qE '^(AC-[0-9]+)([, ]+AC-[0-9]+)*$'; then
  listed="$(printf '%s' "$val" | grep -oE 'AC-[0-9]+')"
else
  echo "[format error] Live-bearing AC IDs value is neither 'none' nor an AC-N list: '$val'" >&2
  exit 1
fi

# 3. Orphan check: each listed AC-N must have a matching #### AC-N heading.
rc=0
for ac in $listed; do
  grep -qE "^#### $ac( |—|\$)" "$spec" || { echo "[orphan] VS lists $ac but no '#### $ac' heading" >&2; rc=1; }
done

# 4. Advisory candidate sweep (ALWAYS runs, even under `none`). Structural signals
# from the predicate: an AC whose GWT carries a live-artifact signal but is not listed.
signals='deployed|real session|real Bash|live session|out-of-band|real .*session|really fires'
awk -v sig="$signals" '
  /^#### AC-/ { ac=$2; body="" }
  /^#### AC-/,/^$/ { body=body" "$0 }
  /^$/ { if (ac!="" && body ~ sig) print ac; ac="" }
  END  { if (ac!="" && body ~ sig) print ac }   # last AC at EOF (no trailing blank line)
' "$spec" | while read -r cand; do
  echo "$listed" | grep -qx "$cand" || echo "[candidate] $cand carries a live-artifact signal but is absent from the VS list (reviewer to judge)"
done

exit "$rc"
