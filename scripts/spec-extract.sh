#!/usr/bin/env bash
# Canonical spec extractor — the ONE parse the checker, the challenge validator,
# and the design-review pre-check all call. Scope: the `## Acceptance Criteria`
# section only (heading → next non-fenced `## `), fence-aware.
set -uo pipefail
cmd="${1:-}"; spec="${2:-}"
{ [ -n "$cmd" ] && [ -f "$spec" ]; } || { echo "usage: spec-extract.sh <reqs|stories|digest> <spec>" >&2; exit 2; }

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

digest_input() {
  awk '
    /^## Acceptance Criteria[[:space:]]*$/ { inac=1; print "## Acceptance Criteria"; next }
    inac && /^```/ { fence = !fence; print "```"; next }
    inac && !fence && /^## / { inac=0; next }
    inac { sub(/\r$/,""); sub(/[[:space:]]+$/,""); print }
  ' "$spec"
}
digest() {
  if command -v shasum >/dev/null 2>&1; then digest_input | shasum -a 256 | awk '{print $1}'
  else digest_input | sha256sum | awk '{print $1}'; fi
}

case "$cmd" in
  reqs)    reqs ;;
  stories) stories ;;
  digest)  digest ;;
  *)       echo "unknown subcommand: $cmd" >&2; exit 2 ;;
esac
