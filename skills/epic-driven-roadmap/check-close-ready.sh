#!/usr/bin/env bash
# check-close-ready.sh <index.md> — honesty floor for a good-faith author's
# close mistake (not a security boundary). Asserts: file exists; frontmatter
# `status:` is a legal enum value; when status == done, `## Evidence
# Reckoning` and a non-empty `## Retrospective` are both present.
# Self-test: --self-test (runs green/red fixtures; override fixture root
# with TOUCHSTONE_CHECK_ROOT).
set -uo pipefail

if [ "${1:-}" = "--self-test" ]; then
  root="${TOUCHSTONE_CHECK_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
  d="$root/.touchstone/checker/fixtures/close-ready"
  "$0" "$d/green.md" >/dev/null || { echo "self-test FAIL: green fixture flagged"; exit 1; }
  "$0" "$d/red.md" >/dev/null 2>&1 && { echo "self-test FAIL: red fixture passed"; exit 1; }
  echo "self-test OK"; exit 0
fi

FILE="${1:-}"
[ -n "$FILE" ] || { echo "ERROR: usage: check-close-ready.sh <index.md>" >&2; exit 1; }
[ -f "$FILE" ] || { echo "ERROR: file not found: $FILE" >&2; exit 1; }

ERRORS=()
fail() { ERRORS+=("$1"); }

frontmatter=$(awk '/^---$/{if(depth==0){depth=1;next}else{exit}} depth==1{print}' "$FILE")
body=$(awk '/^---$/{c++; if(c==2){b=1; next}; next} b{print}' "$FILE")

status=$(echo "$frontmatter" | grep -E '^status:[ \t]*' | sed 's/^status:[ \t]*//' | tr -d '\r' | head -1)

case "$status" in
  proposed|active|paused|done|cancelled) ;;
  *) fail "frontmatter status must be one of proposed|active|paused|done|cancelled, got: '$status'" ;;
esac

if [ "$status" = "done" ]; then
  echo "$body" | grep -qE '^## Evidence Reckoning[[:space:]]*$' \
    || fail "status is done but '## Evidence Reckoning' section is missing"
  retro=$(echo "$body" | awk '/^## Retrospective[[:space:]]*$/{f=1;next} /^## /{f=0} f{print}')
  echo "$retro" | grep -qE '[^[:space:]]' \
    || fail "status is done but '## Retrospective' section is missing or empty"
fi

echo "=== check-close-ready: $FILE ==="
echo "  status: ${status:-<missing>}"

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "FAIL — close-readiness check failed (${#ERRORS[@]} fault(s)):"
  for e in "${ERRORS[@]}"; do
    echo "  - $e"
  done
  exit 1
else
  echo ""
  echo "PASS — all close-readiness checks passed."
  exit 0
fi
