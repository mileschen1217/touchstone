#!/usr/bin/env bash
# check-no-stamped-evidence.sh — no commit-hash-named *.md may be committed
# under scripts/tests/. Run-witness transcripts are transient; they belong in
# the local .touchstone/ workspace, not in the committed tree.
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
[ -d "$root/scripts/tests" ] || exit 0
hits="$(git -C "$root" ls-files -- 'scripts/tests' 2>/dev/null | grep -E '[0-9a-f]{7,}[^/]*\.md$' || true)"
[ -z "$hits" ] && exit 0
echo "[check-no-stamped-evidence] commit-hash-named *.md committed under scripts/tests/ (run-witness belongs in .touchstone/):"; echo "$hits"; exit 1
