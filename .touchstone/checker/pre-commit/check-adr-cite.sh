#!/usr/bin/env bash
# check-adr-cite.sh — no ADR-NNNN citation in a skills/*/SKILL.md body.
# Mechanizes the CLAUDE.md rule: "State the rule, not the ADR."
set -uo pipefail
root="${TOUCHSTONE_CHECK_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}" || exit 0
[ -n "$root" ] || exit 0
hits="$(grep -rInE 'ADR-[0-9]{3,4}' "$root"/skills/*/SKILL.md 2>/dev/null || true)"
[ -z "$hits" ] && exit 0
echo "[check-adr-cite] skill body cites an ADR number (state the rule, not the ADR):"; echo "$hits"; exit 1
