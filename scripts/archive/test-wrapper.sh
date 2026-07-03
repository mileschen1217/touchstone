#!/usr/bin/env bash
# touchstone AC-6a probe: determine if Skill() auto-forward from a wrapper SKILL.md
# preserves user-provided arguments.
#
# This is a probe, NOT a gate. Always exits 0. Caller (Phase A wrapper deployment)
# reads scripts/test-wrapper-result.txt to choose wrapper template path:
#   "auto-forward: YES" → use Skill() dispatch in wrapper body
#   "auto-forward: NO"  → use echo-rewritten-command fallback
#
# MVP: this script CANNOT auto-verify (no programmatic way to drive Claude Code
# from bash). Instead, it prints the verification procedure for a human to run
# and writes the result file based on user-provided answer via stdin.

set -euo pipefail

RESULT_FILE="$(dirname "$0")/test-wrapper-result.txt"

cat <<'PROMPT'
======================================================================
AC-6a probe — wrapper auto-forward feasibility test
======================================================================

To run this test:

1. Open a new Claude Code session (or /reload-plugins in current one).
2. Confirm the touchstone plugin (or a one-skill test plugin) is installed.
3. Write a temporary wrapper SKILL.md at a known location (e.g.,
   ~/.claude/skills/wrapper-test/SKILL.md) with body:

   ---
   name: wrapper-test
   description: Probe — forwards to /touchstone:design-spec.
   kind: workflow
   ---

   Invoke Skill(skill: "touchstone:design-spec", args: { feature: "PROBE-VALUE" })

4. Run `/reload-plugins`.
5. In a fresh session, invoke `/wrapper-test`.
6. Observe: did /touchstone:design-spec receive feature="PROBE-VALUE"?

Answer (y/n): does Skill() auto-forward preserve the arguments?
PROMPT

read -r ANSWER

case "$ANSWER" in
  y|Y|yes|YES)
    echo "auto-forward: YES" > "$RESULT_FILE"
    echo "Result written: auto-forward: YES"
    echo "→ Phase A wrappers will use Skill() dispatch."
    ;;
  n|N|no|NO)
    echo "auto-forward: NO" > "$RESULT_FILE"
    echo "Result written: auto-forward: NO"
    echo "→ Phase A wrappers will use echo-rewritten-command fallback."
    ;;
  *)
    echo "Invalid answer: $ANSWER. Re-run the script." >&2
    exit 1
    ;;
esac

echo ""
echo "Result file: $RESULT_FILE"
exit 0
