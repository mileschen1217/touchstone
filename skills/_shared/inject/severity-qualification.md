---
injected-by: [design-review, deliverable-review]
kind: bridge
---

# Severity qualification (arm-injected segment)

The severity standard every review arm applies; the round budget that consumes these
severities is host-side (`severity-tiered-stopping-rule.md`, read by the merging gate
session, never injected into an arm).

**Severity qualification (gate on coverage, not polish).** A finding earns Critical or
High ONLY by exposing an uncovered behaviour (a requirement / party / path carrying no
AC) or a real defect. A pure refinement — one whose fix changes no behaviour boundary,
tested by removal (delete the finding's target: does any pass/fail behaviour change? no →
refinement) — is Low by construction: its marker rides to the human, it never blocks, and
it never enters the re-verify budget.
