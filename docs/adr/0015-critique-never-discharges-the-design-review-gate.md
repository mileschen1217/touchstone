---
kind: workflow
adr_id: 0015
status: Accepted
date: 2026-06-19
---

# ADR-0015: The design-spec Step-5 critique never discharges the design-review gate

> Numbering note: ADR-0013 (two-axis test model) and ADR-0014 (done-gate shape) live on the
> `dev` integration line and are not present on this branch's `main` base; 0015 is the
> globally-next number. The gap (0013–0014 absent here) is a branch-divergence artifact.

## Status

Accepted. Decided during the `skill-ceiling` Phase-1 first-principles audit (2026-06-19),
which surfaced the defect this ADR fixes.

## Triggered by

`skill-ceiling` epic, Phase 1 — first-principles audit of the touchstone skill suite. The defect
was surfaced by driving the critique-vs-gate boundary down to its roots (conflation-risk +
the binding requirement that the gate judge the artifact that actually proceeds).

## Context

`/touchstone:design-spec` runs a **Step-5 critique** while drafting; `/touchstone:design-review`
is the **Stage-0 gate** that blocks Build. Both `design-spec` and `design-review` SKILL.md
carried a *discharge rule*: the Step-5 critique "discharges" / "satisfies" the gate when it was
"iterated to the gate's tiered standard (C+H=0) and the spec was not edited afterward."

That rule is **unsound**, because the two reviews are not the same check in two cadences — they
have different backends and criteria:

- **Step-5 critique** → `cross-provider-architect` composite (CC `architect` validates structure
  + Codex `codex-adversarial-reviewer` pressure-tests). Verdict `approve|revise|block`, advisory,
  **structural**.
- **design-review gate** → `cross-provider-reviewer` composite (CC `code-reviewer` + Codex
  `codex-reviewer`) with the **doc-review system prompt** (Problem/Scope/AC/Interfaces + the
  **Verification-Strategy / live-bearing declaration** check). **C+H-tiered, Build-blocking.**

Step-5 does not emit the gate's doc-review C+H currency. A spec can pass the architect critique
(structurally C+H=0) while its Verification-Strategy is never audited — that check lives only in
the gate's doc-review prompt. Claiming "gate discharged" from a Step-5 verdict asserts a property
(B passed) from evidence a *different* check (A) produced — a `claim ≤ evidence` violation
(currency mismatch), the very thing touchstone's spine exists to prevent.

## Decision

The Step-5 critique **never** discharges the design-review gate. The gate always runs on the
**final, human-accepted** artifact, regardless of how thoroughly Step-5 was iterated. "design-spec
was run" is never "the gate passed."

(Considered and rejected: option (b) — allow discharge only when Step-5 actually ran the gate's
doc-review criteria. Rejected as more complex and unenforceable: Step-5 dispatches the architect
composite by construction, so it does not run the gate's criteria; a conditional discharge invites
exactly the conflation this ADR removes. Option (a) is simpler and matches `builder ≠ reviewer`
currency independence.)

## Consequences

- `design-spec` §Boundary and `design-review` §Relationship updated: the discharge path is removed;
  the criteria/backend difference is made explicit (a "Backend / criteria" row added to the
  boundary table).
- No workflow throughput change in practice — the gate was already expected on the final artifact;
  this removes a latent bypass, not a step.
- Generalizes the spine: a verdict only counts as evidence for the property its own check measured.

## Related ADRs

- ADR-0011 (honesty spine as Constitution) — this is a direct `claim ≤ evidence` application at the
  review-lifecycle boundary.
- ADR-0009 (evidence-honesty gate) — the Verification-Strategy check that Step-5 omits is the gate
  obligation this ADR protects.
- ADR-0010 (live-bearing AC contract) — the live-bearing declaration the gate audits (and Step-5
  skips) is defined here; part of the gap this ADR closes.
