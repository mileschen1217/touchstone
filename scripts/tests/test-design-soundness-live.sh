#!/usr/bin/env bash
# test-design-soundness-live.sh — Live-bearing honor-check harness scaffold
# (AC-4/5/8/11/12 — requires real reviewer dispatch; Task 6 of cfdq plan)
#
# ORCHESTRATOR RUNS THIS — do NOT invoke from run-all.sh (not a deterministic test).
# This script documents the dispatch parameters for each fixture; it does NOT
# invoke a live reviewer. To produce transcripts, run this with --live and ensure
# the touchstone plugin is loaded (touchstone:cross-provider-reviewer available).
#
# TRANSCRIPT PATH:
#   scripts/tests/transcripts/cfdq/<fixture-name>/<commit>.md
#   Each transcript must carry: dispatch-id, git-rev-parse HEAD, fixture arm.
#
# ARM ROUTING (per plan Task 6 dispatch spec):
#   descriptive-only → FF arm → dispatch touchstone:cross-provider-reviewer
#                               as design-review reviewer (subject = spec document)
#   honored          → FB arm → dispatch touchstone:cross-provider-reviewer
#                               as deliverable-review reviewer (subject = code vs spec ## Architecture)
#   violated         → FB arm → same as honored
#   multi            → FB arm → same as honored
#   ambiguous        → FB arm → same as honored
#
# PASS CRITERION (per plan Task 6):
#   violated/multi   → transcript names the violated commitment (AC-5/AC-12)
#   descriptive-only → transcript names a missing-commitment finding (AC-11)
#   ambiguous        → transcript carries [unverified: reason] (AC-8)
#   honored          → transcript has no finding (AC-4)
#
# WIRING GUARD: the three consumer surfaces must reference the fragment by path.
# If any surface is unwired, the guard below exits non-zero loudly.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FRAGMENT="skills/_shared/inject/design-soundness-honor-check.md"
TRANSCRIPT_DIR="scripts/tests/transcripts/cfdq"
# FIXTURE_DIR: fixture root; referenced in dispatch parameters below (comments)
FIXTURE_DIR="scripts/tests/fixtures/cfdq"
export FIXTURE_DIR

# ---------------------------------------------------------------------------
# Wiring guard: fail loudly if any consumer is not wired
# ---------------------------------------------------------------------------
wiring_ok=1
for consumer in \
  "skills/anvil/SKILL.md" \
  "skills/code-review/references/batch-mode.md" \
  "skills/design-review/SKILL.md"
do
  if ! grep -qF "$FRAGMENT" "$REPO_ROOT/$consumer" 2>/dev/null; then
    echo "ERROR: wiring guard failed — $consumer does not reference $FRAGMENT" >&2
    wiring_ok=0
  fi
done
if [ "$wiring_ok" -eq 0 ]; then
  echo "Halting — wired surfaces must load the fragment before the harness runs." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Dispatch parameters per fixture (for live run by orchestrator)
# ---------------------------------------------------------------------------
# Each block documents:
#   fixture:     path to the fixture directory
#   arm:         FF or FB
#   surface:     which consumer surface's prompt to use
#   spec:        the fixture's spec file
#   code:        the fixture's code tree (for FB arm)
#   ac:          which live-bearing AC this dispatch witnesses
#   pass-crit:   what the transcript must show to discharge the AC
# ---------------------------------------------------------------------------

# --- honored (FB arm, AC-4) -----------------------------------------------
# DISPATCH: touchstone:cross-provider-reviewer (deliverable-review FB role)
#   fragment: inject verbatim from ${REPO_ROOT}/${FRAGMENT}
#   spec: ${REPO_ROOT}/${FIXTURE_DIR}/honored/spec.md
#   code: ${REPO_ROOT}/${FIXTURE_DIR}/honored/src/
#   prompt: load skills/anvil/SKILL.md Stage-5 envelope; inject fragment verbatim
#   transcript: ${REPO_ROOT}/${TRANSCRIPT_DIR}/honored/<git-rev>.md
#   pass-crit: reviewer finds NO violated commitment (AC-4)

# --- violated (FB arm, AC-5) ----------------------------------------------
# DISPATCH: touchstone:cross-provider-reviewer (deliverable-review FB role)
#   fragment: inject verbatim from ${REPO_ROOT}/${FRAGMENT}
#   spec: ${REPO_ROOT}/${FIXTURE_DIR}/violated/spec.md
#   code: ${REPO_ROOT}/${FIXTURE_DIR}/violated/src/
#   prompt: load skills/anvil/SKILL.md Stage-5 envelope; inject fragment verbatim
#   transcript: ${REPO_ROOT}/${TRANSCRIPT_DIR}/violated/<git-rev>.md
#   pass-crit: reviewer names the violated commitment (AC-5)

# --- multi (FB arm, AC-12) ------------------------------------------------
# DISPATCH: touchstone:cross-provider-reviewer (deliverable-review FB role)
#   fragment: inject verbatim from ${REPO_ROOT}/${FRAGMENT}
#   spec: ${REPO_ROOT}/${FIXTURE_DIR}/multi/spec.md
#   code: ${REPO_ROOT}/${FIXTURE_DIR}/multi/src/
#   prompt: load skills/anvil/SKILL.md Stage-5 envelope; inject fragment verbatim
#   transcript: ${REPO_ROOT}/${TRANSCRIPT_DIR}/multi/<git-rev>.md
#   pass-crit: reviewer names the one violated commitment (RateLimiter) and
#              confirms the honored one (CacheLayer) — one finding, not two (AC-12)

# --- descriptive-only (FF arm, AC-11) -------------------------------------
# DISPATCH: touchstone:cross-provider-reviewer (design-review FF role)
#   fragment: inject verbatim from ${REPO_ROOT}/${FRAGMENT}
#   spec: ${REPO_ROOT}/${FIXTURE_DIR}/descriptive-only/spec.md
#   code: NOT injected — FF arm subjects the spec document only
#   prompt: load skills/design-review/SKILL.md doc-review envelope; inject fragment verbatim
#   transcript: ${REPO_ROOT}/${TRANSCRIPT_DIR}/descriptive-only/<git-rev>.md
#   pass-crit: reviewer raises a missing-commitment finding on the depth-stakes
#              component whose ## Architecture is descriptive-only (AC-11)

# --- ambiguous (FB arm, AC-8) ---------------------------------------------
# DISPATCH: touchstone:cross-provider-reviewer (deliverable-review FB role)
#   fragment: inject verbatim from ${REPO_ROOT}/${FRAGMENT}
#   spec: ${REPO_ROOT}/${FIXTURE_DIR}/ambiguous/spec.md
#   code: ${REPO_ROOT}/${FIXTURE_DIR}/ambiguous/src/
#   prompt: load skills/anvil/SKILL.md Stage-5 envelope; inject fragment verbatim
#   transcript: ${REPO_ROOT}/${TRANSCRIPT_DIR}/ambiguous/<git-rev>.md
#   pass-crit: reviewer marks the commitment [unverified: reason] rather than
#              asserting honored or violated (AC-8)

# ---------------------------------------------------------------------------
# Live run stub (requires --live flag + plugin loaded)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--live" ]; then
  echo "Live dispatch is not implemented in this scaffold."
  echo "To run live: load the touchstone plugin, then invoke"
  echo "  touchstone:cross-provider-reviewer per the dispatch parameters above."
  echo "Transcript paths: ${REPO_ROOT}/${TRANSCRIPT_DIR}/<fixture>/<git-rev>.md"
  echo "Commit hash for provenance: $(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo '[unknown]')"
  exit 0
fi

echo "test-design-soundness-live.sh: scaffold only."
echo "Run with --live flag (and plugin loaded) to dispatch live reviewers."
echo "Wiring guard: PASSED (all three consumer surfaces reference the fragment)."
exit 0
