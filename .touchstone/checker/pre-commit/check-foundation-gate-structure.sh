#!/usr/bin/env bash
# check-foundation-gate-structure.sh — pre-commit wrapper that calls the repo's
# structural regression check for the intention-first foundation gate.
# Delegates to scripts/check-foundation-gate-structure.sh at repo root.
# Degrade: if the script is absent (e.g. scaffold copy in another repo), exit 0.
set -uo pipefail
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[ -n "$root" ] || exit 0
script="$root/scripts/check-foundation-gate-structure.sh"
[ -f "$script" ] || exit 0   # absent → degrade silently (another repo's scaffold copy)
exec "$script"
