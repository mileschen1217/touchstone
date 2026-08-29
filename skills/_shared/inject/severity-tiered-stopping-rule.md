---
injected-by: [design-review, deliverable-review]
referenced-by: [design-spec, anvil, crucible]
kind: bridge
---

# Severity-tiered stopping rule (single home)

**Budget = initial review + at most ONE re-verify dispatch.** T = 3 (adjustable by a
human ruling recorded in the epic's calibration ledger). "Zero new findings" is a
stopping criterion nowhere in the suite.

**Severity qualification (gate on coverage, not polish).** A finding earns Critical or
High ONLY by exposing an uncovered behaviour (a requirement / party / path carrying no
AC) or a real defect. A pure refinement — one whose fix changes no behaviour boundary,
tested by removal (delete the finding's target: does any pass/fail behaviour change? no →
refinement) — is Low by construction: its marker rides to the human, it never blocks, and
it never enters the re-verify budget below.

**Initial round:**
- any Critical, or High ≥ T → fix all → ONE combined re-verify dispatch.
- 0 Critical and High < T → fix all → close; the fix diff rides the verdict to the next
  human checkpoint (a clean round attaches no diff).

**Re-verify round (budget spent — no further autonomous dispatch):**
- any Critical → the artifact is **blocked** and surfaced to the human at the next
  existing checkpoint (terminal accept / PR approve / batch report), with a three-path
  menu — authorize one more round / change approach / cut scope. It stays non-passing
  (spec not accepted / commit not made / batch not closed) until the human rules.
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
the terminal human accept covers both.
