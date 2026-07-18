---
injected-by: [design-review, anvil]
referenced-by: [design-spec, code-review, crucible]
kind: bridge
---

# Severity-tiered stopping rule (single home)

The one normative definition of how a bounded AI review loop in this suite
terminates. A consumer loads this file and carries only its own site delta.

**Budget = initial review + at most ONE re-verify dispatch.** T = 3 (adjustable by a
human ruling recorded in the epic's calibration ledger). "Zero new findings" is a
stopping criterion nowhere in the suite.

**Severity qualification (gate on coverage, not polish).** A finding earns Critical or
High ONLY by exposing an uncovered behaviour (a requirement / party / path carrying no
AC) or a real defect. A pure refinement — one whose fix changes no behaviour boundary,
tested by removal (delete the finding's target: does any pass/fail behaviour change? no →
refinement) — is Low by construction: its marker rides to the human, it never blocks, and
it never enters the re-verify budget below. This is what stops a loop churning on
plausible-but-unbounded polish; only coverage gaps and real defects drive another round.

**Initial round:**
- any Critical, or High ≥ T → fix all → ONE combined re-verify dispatch (boundary pin:
  H = T re-verifies, H = T−1 closes).
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

**Challenge-pass loop** (findings are ungraded markers, not C/H): initial challenge + ONE
re-challenge; every unresolved marker blocks. Route a marker by content — one that would
change a user-story or a requirement's SHALL headline goes to the human, an AC-level one
is resolved by the authoring AI and logged; the terminal human accept covers both.
