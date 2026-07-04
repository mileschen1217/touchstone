---
kind: workflow
adr_id: 0032
status: Accepted
date: 2026-07-04
kill-on: positioning-floor-band-exit
---

# ADR-0032: Plugin boundary — nothing moves out; slim inside; ceilings named

## Status

Accepted. Records the boundary ruling of the feedforward-rebalance agenda
(2026-07-04), the size policy it produced, and the enforcement ceilings the
plugin explicitly declines to fix at this band.

## Context

An audit asked whether touchstone's self-feedback machinery (insight loop,
sweep/ledger family, checker family, metrics capture) is "maintainer
infrastructure" that should move out of the shipped plugin. Verification
corrected the audit's premise: the machinery is machine-relative (any adopting
project's loop consumes it), and its heaviest pieces had cheaper shapes rather
than wrong homes. Separately, review-prompt surfaces had grown by accretion
(top three: 3,093 / 2,668 / 2,193 tokens), and review cost was observed rising
linearly with lens count while the catch-attribution ledger showed **74% of
recorded gate-misses were caught by the human** (90-entry ledger, 2026-07-04)
— the feedback tower's interception rate is thin, which anchors the decision
to rebalance investment toward feedforward instruments (assumption-surfacing
interviews, contract grounding) rather than to add more feedback lenses.

## Decision

1. **Boundary: nothing moves out of the plugin.** The plugin's identity is
   semantic gates + the contract spine + a self-improvement loop that carries
   its own measurement arm. The knife goes INSIDE: single-timestamp sweep
   state, one-script stage gate, task_dir-direct codex metrics, dead surfaces
   deleted (shipped as the Phase-2 slim batch).
2. **Size policy (A3).** Absolute layer: a skill body carries no filler —
   guideline ≤200 lines / ≈2.5k tokens, hard cap 500 lines. Ratchet layer: the
   review-prompt surface's total token count is capped at the 2026-07-04
   baseline — net growth only by matching deletion. Admission/retirement of
   workflow units runs through the insight loop's four admission rules and
   the cost-to-keep retirement pass (their operational home is
   `skills/insight/SKILL.md`).
3. **Known ceilings — declared, not fixed.** Three enforcement holes stay
   prose-level at this band, because the honesty boundary is guarded at the
   EXITS (pre-push gate, epic-close reckoning) and all three are interior
   holes whose cost is rework, not a false-green escaping the repo:
   - *review-before-commit* has no event-bound enforcement (its assembly
     parts — run stamping, the review-summary checker — already exist; a
     future fix is assembly, not construction);
   - *design-review's C+H Build-block* is an instruction the caller follows,
     not a hook (the pre-push `check-review-summary` gate already blocks C/H
     event-bound at the exit; the residual gap is session-internal only);
   - *anvil's AC status handling* relies on prose ("never promote to
     verified"), not a mechanized diff over AC markers.
4. **Band-exit hook (the kill-on trigger).** These ceilings are priced for a
   human-in-the-loop band. If the guardrail-interview practice pushes runs
   toward unattended mid-band operation (ralph-loop territory), the
   positioning-floor band-exit fires and this ADR must be revisited: interior
   holes stop being interior when no human sits between them and the exit.

## Consequences

- Adopters get the full loop (gates + spine + insight/ledger/metrics) in one
  plugin; no companion "maintainer edition" exists to drift.
- Review-prompt token budgets are now a ratchet: every future lens addition
  names its deletion.
- The three ceilings are honest claims — skills describe them as instructions
  to the executing agent, never as system-enforced mechanisms.
