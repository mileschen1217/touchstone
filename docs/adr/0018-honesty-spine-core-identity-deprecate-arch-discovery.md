---
status: Accepted
date: 2026-06-22
kill-on: skill-ceiling-closed
deciders: project owner (owns the Pillar-2 bet below)
---

# ADR-0018 — touchstone identity is the honesty-spine core (project-agnostic); deprecate arch-discovery

## Triggered by

A first-principles derivation of the design+review subsystem conducted during the
skill-ceiling work. The derivation, not a single arch-review consult, surfaced the
decision — recording it here because it meets all three ADR criteria (hard to reverse,
surprising without context, the result of a real trade-off).

## Related ADRs

- ADR-0015 (a critique never discharges the design-review gate) — this decision derives
  the *root* of that boundary: gate-vs-critique is a necessity of comparator type
  (evidence → may block; judgment → advisory only), not a stipulated rule.
- ADR-0016 (skill-suite structure convention) — the construct model below refines what a
  design-stage skill is for.
- ADR-0017 (injectable doctrine fragments home) — the honesty doctrine that constitutes
  the "core" lives as those injected invariants.

## Context

Driving the design+review subsystem down to its forces shows it serves **two distinct
pillars**, sharing a floor but diverging in mechanism:

- **Pillar 1 — per-delivery trust.** Mediated-observation × satisficer × scarce-attention
  → the mission: trust an agent's "done" without re-doing it, via `claim ≤ evidence`
  keeping verify-cost below produce-cost. Mechanism: **measure-after** (an evidence
  comparator; can gate/block).
- **Pillar 2 — cross-delivery durability (architecture / -ility).** Change-over-time ×
  bounded-present-knowledge × scarcity. -ility is a modal property over possible futures:
  it has no present extension to measure, and late correction is entrenched-costly — so
  it can only be **secured by construction** (constrain-before), via an ex-ante judgment
  (a probability × cost bet, bounded by YAGNI), never by measurement. Mechanism:
  **judgment comparator; advisory only**.

The honesty spine (Pillar 1's invariants — `claim ≤ evidence`, builder ⊥ reviewer, the
contract spine) is **project-class-agnostic**: it applies to any AI-delivered work.
Pillar 2's *function* (record durability bets as ADRs with revisit-triggers) is likewise
needed by any project facing change. But the **heavy, multi-session, multi-actor variant**
of Pillar-2 feedforward — system-model discovery (ownership/invariants/flows alignment
before a spec is writable) — serves a *specific* project class (networking / embedded /
hardware-software co-design) that is orthogonal to the honesty-spine core.

Empirically, in this project's own history: the lightweight standalone arch consult
triggered zero ADRs (architectural decisions happened inline — during spec drafting and
during first-principles derivations like this one), and the heavy discovery scaffold was
exercised once and abandoned mid-flight.

## Decision

**touchstone's identity is the honesty-spine core: an honesty overlay on AI-delivered
work, not locked to any project class.**

1. **Keep a thin Pillar-2 arch construct** — frame a question → run the critique engine
   (advisory) → the human makes the bet → record an ADR with a revisit-trigger. It carries
   the architecture invariant *minimize expected complexity (change-cost + cognition),
   probability-weighted, bounded by YAGNI on cost* as a principle, never as a
   pattern/anti-pattern checklist.
2. **Deprecate the heavy multi-actor system-model discovery capability.** It is not part
   of the core identity and serves a population this project does not target or dogfood.
   Cutting it does not touch the honesty-spine core.
3. **Doctrine-form rule (comparator-scoped).** A skill carries its *judgment* content as an
   **invariant** (an objective / force), never as a pattern / anti-pattern *judgment
   checklist* — which pre-bakes the situational bet, freezes a mechanism, and caps strong
   models. This forbids **only judgment-comparator** checklists (Pillar 2 — "apply these
   design patterns"). It does NOT forbid **gate checklists** (Pillar 1 — a done-gate /
   Ship-gate enumeration of falsifiable evidence-conditions); those are legitimate and good,
   because each item is itself a `claim ≤ evidence` invariant (the explicit decomposition of
   the honesty spine), not a scripted mechanism. Dividing test: is each item a *falsifiable
   evidence condition* (keep) or a *pre-baked situational solution* (forbid)? — the same
   comparator-type line that fixes gate-ability. Reflexively, this makes a skill a "deep
   module" (a small principled interface over a large judgment space) rather than a shallow
   checklist.

This decision is itself a Pillar-2 bet (dogfooding the construct it defines): it bets that
P(touchstone must serve a multi-actor/embedded population) × value is below the cost of
carrying the discovery capability.

## Revisit trigger

If touchstone is adopted by a team building multi-actor / embedded / hardware-software
co-design systems where the system model must be aligned *before* a spec is writable, and
that need recurs, revisit — the discovery capability can be revived from deprecation or
rebuilt.

## Alternatives considered

- **Broad identity (serve multi-actor / embedded).** Keep the discovery capability as the
  heavy Pillar-2 variant plus a thin consult for light forks. Rejected: commits to
  maintaining a capability the project neither targets nor dogfoods, and dilutes the
  honesty-spine identity; the empirical record shows it unused.
- **Defer the identity call; thin both arch skills without cutting.** Rejected: leaves the
  suite's identity ambiguous and pays ongoing carrying cost for a capability likely to be
  cut anyway — the YAGNI-on-cost test favours deciding now.

## Consequences

- The architecture decision capability becomes a thin construct (frame → critique engine →
  ADR), not a heavyweight standalone skill.
- Deprecating the discovery capability has blast radius to clean up: the design-review
  discovery-doc audit path, routing mentions in other skills, the workflow's discovery
  stage, and README cross-references.
- The mandatory pre-authoring vocabulary-sharpening gate guards a smaller set of downstream
  skills afterward (one fewer arch path; the consult becomes a thin construct).
- The implementing refactor (thin arch construct + deprecation + gate adjustment) is a
  multi-file contract change and goes through the normal design-spec / plan workflow — it
  is not part of this ADR.
