---
referenced-by: [design-review, deliverable-review, anvil, plugin-review.sh]
kind: bridge
---

# Severity-tiered stopping rule (single home — host segment)

The one stopping rule of every review gate — design-review, deliverable-review, and the
touchstone-local plugin-review alike; no gate carries a second budget, threshold, or
plateau rule of its own. Read by each gate's merging host session, never injected into an
arm; the severity standard the arms apply travels in each arm's assembled lens file
(composition: the lens manifest).

**Budget = initial review + at most ONE re-verify dispatch.** T = 3 (adjustable by a
human ruling recorded in the epic's calibration ledger). **Terminator: a round that
reports zero new Critical and zero new High closes the gate.** A refinement-class
finding (per the sibling segment) never enters the re-verify budget below.

**Initial round:**
- zero new Critical and zero new High → close (the terminator; nothing to fix, no diff).
- any Critical, or High ≥ T → fix all → ONE combined re-verify dispatch.
- 0 Critical and High < T → fix all → close; the fix diff rides the verdict to the next
  human checkpoint.

A short-chain design-review and the touchstone-local plugin-review spend the initial
round only; their re-verify dispatch is never issued — residue rides to the next phase.

**Re-verify round (budget spent — no further autonomous dispatch):**
- any Critical → the artifact is **blocked** and surfaced to the human at the next
  existing checkpoint (contract accept / ship informed-accept / batch report), with a
  three-path menu — authorize one more round / change approach / cut scope. It stays
  non-passing (spec not accepted / commit not made / batch not closed) until the human rules.
- High only → fix; the diff + markers ride the verdict to the human.

**No unauthorized third round:** while a re-verify round reports any Critical, the loop
SHALL NOT dispatch a further review round without a recorded human authorization.

**Every round:** residual Medium/Low ride to the human as markers (a transient-bridge Low
passes). A dispatch that errors before returning a verdict is a technical failure, not a
round — one technical retry, else the blocked path noted "re-verify incomplete"; never a
silently skipped re-verify, never a fabricated verdict.

**Discovery once, then burn-down (both loops).** The initial round is the one discovery
pass — its gating findings are the **frozen backlog**. The re-verify / re-challenge is
**burn-down**: it confirms the backlog is resolved and catches any real defect a fix
introduced; it does NOT re-run discovery on the fixed text. A `fix-induced` finding may
not re-open a round unless it is a genuine real defect; a refinement of fix text rides to
the human.

**Challenger context** (design-review round 1; markers carry `type` / `provenance`, severity
derived from type at merge): initial challenge + ONE re-challenge inside the same round budget. A `refinement` marker rides to the
human and never blocks; `coverage-gap` / `real-defect` markers are the backlog. Route a
backlog marker by content — one that would change a user-story or a requirement's SHALL
headline goes to the human, an AC-level one is resolved by the authoring AI and logged;
the contract accept covers both.
