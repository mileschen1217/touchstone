---
kind: workflow
adr_id: 0034
status: Accepted
date: 2026-07-04
---

# ADR-0034: Guardrail interview — skill fixation is GO (spike verdict)

## Status

Accepted. The spike-closure verdict for the guardrail-interview instrument:
fixing it as a skill is GO, with two protocol amendments the spike surfaced.
Authoring the skill body itself is the NEXT phase's work, not this decision's.

## Context

The feedforward-rebalance agenda chartered a three-part interview instrument
(bidirectional map-alignment where the AI lays out its assumptions, a
readiness fork routing to spike/mock, and guardrail authoring that turns the
spec's Interfaces prose into structured contract blocks) — and ruled
spike-first: run the instrument MANUALLY on one real subject (the Phase-2
slim-down execution) and collect catch data before freezing any skill.
Mechanization decisions were deliberately withdrawn until this data existed.

## Spike data (deviation log, 2026-07-04)

Interview period:
- The instrument's own protocol carried an undeclared conservative bias (the
  AI silently assumed "change as little structure as possible" and that bias
  itself was not laid on the table) — caught by the HUMAN, fixable by making
  a bold pass explicit in the protocol.
- **Positive catch:** the bold pass extracted an intent the human had held
  since ~1.5 minor versions earlier (rewrite the three heaviest skills from
  scratch) that repeated in-flight steering had failed to transmit. One round
  of bidirectional assumption-surfacing recovered it — direct evidence that
  when assumptions are out of sync, steering is a lossy channel and the
  interview is the cheaper synchronization.

Execution period (what the interview did NOT catch): an estimation-granularity
miss (a size target that ignored invariant-preservation cost), one ruling
whose referent was never externalized precisely enough to execute without
re-derivation, and one promotion-time scrub the audit list omitted. All three
point at RECORD precision (rulings written as file:line-resolvable
dispositions), not at the instrument's concept.

## Decision

1. **GO** — fix the interview as a touchstone skill in the next phase. The
   instrument produced a catch class nothing else in the suite produces
   (human-side latent intent), at interview cost, before build cost was sunk.
2. **Amendments the skill body must carry** (from the spike):
   - The assumption-surfacing step includes an explicit **bold pass**: propose
     the structurally-larger moves ordered by blast radius; "change nothing
     structural" is itself an assumption to lay on the table.
   - Rulings emitted by the interview are recorded **execution-precise**:
     each disposition names its file (and line/anchor where applicable) so a
     later session executes without re-derivation.
3. **keystone absorbs into the skill at fixation time** (the structural fork
   becomes one case of the readiness fork; the ADR fields flip-trigger /
   bet-owner / assumptions carry over).
4. The honest ceiling stands: the interview NARROWS unknown-unknowns, never
   proves them zero; feedback-lens retirement keyed to interview coverage
   still requires observed fire-rate decline (the insight loop's R2), never
   prediction.

## Consequences

- Next phase: author the skill body (charter as above), replacing the manual
  protocol file.
- The deviation log format (gap / quadrant / which-interview-step-could-have-
  caught / catcher) is retained as the instrument's standing validity metric.
