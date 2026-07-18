#!/usr/bin/env bash
# Canonical spec extractor — the ONE parse the checker, the challenge validator,
# and the design-review pre-check all call. Attested surface: `## Foundation`,
# `## User Stories`, and `## Acceptance Criteria` sections, fence-aware.
set -uo pipefail
cmd="${1:-}"; spec="${2:-}"
if [ "$cmd" != "normalizer-version" ]; then
  { [ -n "$cmd" ] && [ -f "$spec" ]; } || { echo "usage: spec-extract.sh <reqs|stories|raw-stories|raw-reqs|traces|digest|normalizer-version> <spec>" >&2; exit 2; }
fi

reqs() {
  awk '
    /^```/ { fence = !fence; next }
    fence  { next }
    /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
    inac && /^## / { inac=0 }
    !inac  { next }
    /^### Requirement:[[:space:]]+REQ-[0-9]+/ { match($0,/REQ-[0-9]+/); print substr($0,RSTART,RLENGTH) }
  ' "$spec" | sort -u
}

stories() {
  awk '
    /^```/ { fence = !fence; next }
    fence  { next }
    /^## User Stories[[:space:]]*$/ { inus=1; next }
    inus && /^## / { inus=0 }
    !inus  { next }
    /^[[:space:]]*-[[:space:]]+US-[0-9]+([^[:alnum:]_]|$)/ { match($0,/US-[0-9]+/); print substr($0,RSTART,RLENGTH) }
  ' "$spec" | sort -u
}

raw_stories() {
  awk '
    /^```/ { fence = !fence; next }
    fence  { next }
    /^## User Stories[[:space:]]*$/ { inus=1; next }
    inus && /^## / { inus=0 }
    !inus  { next }
    /^[[:space:]]*-[[:space:]]+US-[0-9]+([^[:alnum:]_]|$)/ { match($0,/US-[0-9]+/); print substr($0,RSTART,RLENGTH) }
  ' "$spec"
}
raw_reqs() {
  awk '
    /^```/ { fence = !fence; next }
    fence  { next }
    /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
    inac && /^## / { inac=0 }
    !inac  { next }
    /^### Requirement:[[:space:]]+REQ-[0-9]+/ { match($0,/REQ-[0-9]+/); print substr($0,RSTART,RLENGTH) }
  ' "$spec"
}
# Type-tagged trace pairs: one line per traces-to target, `<req> <type> <target>`.
# Target vocabulary (the type is the deterministic routing signal): US-N | REQ-N |
# ADR-NNNN | finding:<path>#<id>. Finding-refs are extracted+stripped FIRST (their
# path may embed other tokens); the remainder is scanned for US / ADR / REQ.
# The digest path (attested_section) is untouched by this function.
traces() {
  awk '
    /^```/ { fence = !fence; next }
    fence  { next }
    /^## Acceptance Criteria[[:space:]]*$/ { inac=1; next }
    inac && /^## / { inac=0 }
    !inac  { next }
    /^### Requirement:[[:space:]]+REQ-[0-9]+/ { match($0,/REQ-[0-9]+/); cur=substr($0,RSTART,RLENGTH); next }
    /^traces-to:/ && cur!="" {
      line=$0
      while (match(line,/finding:[^ ,]+#[^ ,]+/)) { print cur " finding " substr(line,RSTART,RLENGTH); line=substr(line,1,RSTART-1) substr(line,RSTART+RLENGTH) }
      tmp=line; while (match(tmp,/US-[0-9]+/))  { print cur " US "  substr(tmp,RSTART,RLENGTH); tmp=substr(tmp,RSTART+RLENGTH) }
      tmp=line; while (match(tmp,/ADR-[0-9]+/)) { print cur " ADR " substr(tmp,RSTART,RLENGTH); tmp=substr(tmp,RSTART+RLENGTH) }
      tmp=line; while (match(tmp,/REQ-[0-9]+/)) { print cur " REQ " substr(tmp,RSTART,RLENGTH); tmp=substr(tmp,RSTART+RLENGTH) }
    }
  ' "$spec"
}

NORMALIZER_VERSION=1

# Normalized body of ONE attested section, fence-aware, per-line right-trim + CRLF strip.
# Exits with awk status 2 if the heading appears twice (ambiguous); exit 0 otherwise.
# The dup signal is out-of-band (exit code), never mixed into stdout body.
attested_section() {
  awk -v name="$1" '
    function ishdr(l)  { return l ~ ("^## " name "[[:space:]]*$") }
    /^```/ { if (inx) { fence=!fence; sub(/\r$/,""); sub(/[[:space:]]+$/,""); print; next } gfence=!gfence; next }
    gfence { next }
    ishdr($0) { if (seen){ exit 2 } seen=1; inx=1; print "## " name; next }
    inx && !fence && /^## / { inx=0 }
    inx { sub(/\r$/,""); sub(/[[:space:]]+$/,""); print }
    END { if (gfence) exit 2 }
  ' "$2"
}
# (heading matched by the canonical ^## <name>[[:space:]]*$ rule — a trailing-space
#  heading IS the section, and prints canonically; add a trailing-space-heading fixture
#  + a duplicate trailing-space heading fixture to the Task 2 fixture set.)
digest_input() {
  local rc=0
  # canonical fixed order — independent of file appearance order
  for s in "Foundation" "User Stories" "Acceptance Criteria"; do
    attested_section "$s" "$1" || rc=$?
  done
  return "$rc"
}
digest() {
  local body
  body="$(digest_input "$spec")" || { echo "BLOCK: duplicate top-level attested heading" >&2; exit 1; }
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$body" | shasum -a 256 | awk '{print $1}'
  else printf '%s' "$body" | sha256sum | awk '{print $1}'; fi
}
case "$cmd" in
  reqs)               reqs ;;
  stories)            stories ;;
  raw-stories)        raw_stories ;;
  raw-reqs)           raw_reqs ;;
  traces)             traces ;;
  digest)             digest ;;
  normalizer-version) echo "$NORMALIZER_VERSION" ;;
  *)                  echo "unknown subcommand: $cmd" >&2; exit 2 ;;
esac
