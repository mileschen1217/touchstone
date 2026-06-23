---
status: Accepted
date: 2026-06-22
kill-on: skill-ceiling
deciders: project owner
---

# ADR-0019 — keystone naming: substrate-neutral, function-named structural-commitment construct

## Triggered by

The arch-review → keystone rename executed as part of the design-stage subsystem refactor.
The naming decision warrants its own ADR: it is a durable externally-visible commitment
(skill namespace, routing docs, ADR cross-references) that is hard to reverse once
consumer surface grows, and the rationale is non-obvious — the old name was not wrong
by convention, only by mis-fit with the construct's actual function and dogfood use.

## Related ADRs

- ADR-0015 (a critique never discharges the design-review gate) — confirms the
  Pillar-2 construct is advisory-only; the name must not imply a gate or evidence check.
- ADR-0016 (skill-suite structure convention) — the construct model this ADR names.
- ADR-0018 (touchstone identity is the honesty-spine core; deprecate arch-discovery) —
  the identity decision that makes substrate-neutrality a requirement: touchstone is an
  honesty overlay on AI-delivered work, not locked to software architecture.

## Context

The Pillar-2 structural-commitment construct (now `touchstone:keystone`) was previously
named `arch-review`. That name has two mis-fits:

1. **"arch" hard-binds to software architecture.** The construct's invariant (minimize
   expected complexity, probability × cost weighted, bounded by YAGNI — see
   ADR-0018 § Decision for the two-pillar derivation) mentions no artifact type. Its forces apply
   to code, documentation structure, skill-suite organization, and any other persistent
   artifact that faces change-over-time. In this project's own dogfood history, the
   construct's primary use has been deciding the structure of the skill suite itself — a
   non-code artifact. The name creates an expectation the construct cannot fulfill
   (software critique for a non-software question) and suppresses legitimate invocations.

2. **"review" misnames the function.** The construct's output is a committed ADR with a
   revisit-trigger — a durable bet with a named human owner. That is a *decision* act, not
   a *review* act. Naming it "review" obscures its consequential nature and invites
   confusion with the evidence-comparator design-review gate (Pillar 1 feedback).

## Decision

**Name the construct `keystone`.** Rationale:

- **Function-named, not domain-named.** A keystone is the load-bearing element that locks
  an arch into shape: remove it and the structure collapses. The construct's role in the
  workflow is exactly this — it is the step where a human commits to a structural shape
  (recording it as an ADR with a flip-trigger) before downstream work proceeds. The
  metaphor is accurate and substrate-neutral: a keystone can lock a software architecture,
  a document structure, or a skill-suite design.
- **Substrate-agnostic.** The name carries no implication of project class (no "arch",
  no "software", no "design"). Any Pillar-2 structural-commitment question in any domain
  is a valid invocation.
- **Honest engine limit stated, not hidden.** The default critique engine
  (`touchstone:cross-provider-architect`) is software-architecture-tuned. The naming
  is neutral; the engine note is not. The skill's content explicitly states this limit
  so operators invoking keystone for non-code decisions know the engine's calibration
  and can substitute a domain-appropriate critique if needed.

## Revisit trigger

If the `touchstone:keystone` namespace is published to a plugin marketplace and the name
causes adoption confusion (e.g., operators do not recognize "keystone" as an arch/decision
construct), revisit — a more explicit name such as `structure-decision` may be warranted.

## Alternatives considered

- **`arch-decision`.** Corrects the "review" mis-naming but retains the "arch" domain-bind.
  Rejected: the Pillar-2 invariant is substrate-neutral and the primary dogfood use is
  non-code; "arch" would perpetuate the domain mis-fit in the name.
- **`decision` or `structure-decision`.** Accurate and neutral but generic; "decision" alone
  gives no hint of the durability/Pillar-2 character. Rejected in favour of a metaphor
  that encodes both the structural and the commitment aspects.
- **Keep `arch-review`.** No implementation cost. Rejected: the name actively misfires on
  two axes (domain and function), suppresses non-code invocations, and conflicts with the
  substrate-neutral identity established in ADR-0018.

## Consequences

- All routing docs, agent descriptions, and inject-fragment frontmatter that referenced
  `arch-review` are updated to `keystone`.
- Historical committed ADRs that mentioned `arch-review` retain the original literal and
  append `(now keystone)` on the same line — so the rename is traceable without rewriting
  the historical record.
- The default critique engine (`cross-provider-architect`) remains software-architecture-
  tuned. The honest limit is stated in the skill content, not papered over by the naming.
