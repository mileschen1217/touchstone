---
kind: workflow
adr_id: 0023
status: Accepted
date: 2026-06-24
kill-on: grill-and-explore-merge-into-one-iterative-phase
---

# ADR-0023: Exploration has two roles — grill before explore by default in contract-forging

## Status

Accepted. Decided 2026-06-24 while reviewing the Phase-2.10 crucible changes, when the
question "should exploration come before or after grill?" surfaced and felt genuinely
balanced — a sign a distinguishing force was missing, not that the two were equivalent.

## Context

`touchstone:crucible` forges a contract (why → requirements → ACs) by chaining
`brainstorming → grill-with-docs → … → design-spec`. Where does **exploration** of the
existing system sit relative to `grill-with-docs`?

Both orders seem reasonable, which is the tell that the orders are answering different
questions:

- **What each step operates on.** `grill-with-docs` challenges the *intent* against the
  project's documented model and sharpens vocabulary — it reads and edits CONTEXT.md /
  ADRs inline. It is a **what-layer** operation (intent / doctrine). Exploration discovers
  the system's reality — code paths, patterns, constraints. It is a **how-layer**
  operation. Sharpen the *what* before grounding it in the *how* ⇒ grill precedes explore.

- **Exploration has two roles.** The pull toward "explore first" comes entirely from a
  second role:
  - **Solution-grounding** — you can state the intent now; exploration grounds that
    sharpened intent in the system (feasibility, what-to-touch). Exploration *serves* an
    intent that already exists.
  - **Problem-finding** — you cannot state the intent until you have looked (an audit or
    heavy refactor where the work's shape depends on what is actually there). Exploration
    *produces* the intent.

A linear chain must pick a start, but the dependency is real in both directions
(grill wants explore's ground-truth; explore wants grill's target). The two roles resolve
it: the default role is solution-grounding, so the default order is grill → explore; only
problem-finding flips it.

This supersedes the framing introduced earlier in Phase 2.10, where "explore-dominant"
work was routed **out** of the chain by a STOP gate ("crucible's chain has no slot for an
open-ended audit"). That framing mis-located exploration as a precondition rather than a
chain phase, and contradicted the intent-first principle for the common case.

## Decision

In contract-forging (`crucible`):

1. **Exploration is a phase of the chain, after `grill-with-docs`** —
   `brainstorming → grill-with-docs → explore → keystone → design-spec`. The default
   (solution-grounding) explore grounds a sharpened intent in the system.

2. **A head router classifies the exploration role**, it does not exit the chain:
   - *Solution-grounding (default)* → proceed; explore runs as the in-chain phase after grill.
   - *Problem-finding* → run a discovery exploration first to surface the intent, then enter
     the chain (the in-chain explore phase is then light / confirmatory).

3. The classification is **orthogonal to story recognition** — a recognized story (≥1 US-N)
   does not settle which exploration role applies.

## Consequences

- crucible's chain gains an explicit `explore` phase between grill and keystone; the former
  "explore-dominant → STOP / exit chain" gate becomes a one-question router that front-loads
  exploration only for problem-finding work.
- This **reverses the order in the global workflow** (`~/.claude/CLAUDE.md`: Stage 1 Explore →
  Stage 1.5 grill-with-docs), which puts explore first unconditionally. The global workflow is
  to be corrected to match — flagged here, **not** done in this ADR.
- `kill-on`: if `grill-with-docs` and `explore` are ever merged into a single iterative phase
  (explore-a-bit ⇄ grill-a-bit), the fixed ordering this ADR sets retires — the bidirectional
  dependency would then be handled by iteration, not by sequence.

## Related ADRs

- ADR-0022 (skill comprehension-cost doctrine) — the router and the `explore` phase are named
  by function, not position, per that doctrine.
- ADR-0018 (honesty-spine core identity) — `explore` feeds the requirement → AC contract but
  does not author it; the contract layer still owns the claim.
