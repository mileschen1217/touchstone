---
kind: workflow
adr_id: 0027
status: Accepted
date: 2026-06-28
---

# ADR-0027: Design-quality arm — normative `## Architecture` (feedforward) + design-soundness feedback arm at deliverable review (feedback), not a new gate

## Status

Accepted. Keystone bet for the `code-facing-design-quality` epic (Phase 1). Human bet-owner: the touchstone maintainer.

## Triggered by

`/touchstone:keystone` during the `code-facing-design-quality` epic — the structural fork over where a code-facing design-quality (module-depth / interface-economy) arm lives and what surface carries it.

## Context

Design quality has the same two arms as behavioral quality, but only one is wired:

- **Behavioral** quality runs US → REQ → AC (feedforward declaration) and a verifying reviewer / Evidence Reckoning (feedback). Rich, two-armed.
- **Design** quality has, since Phase 3.2 (ADR-0026), a **design-soundness lens** — but it fires only on the spec **document** at `design-review` (a feedforward / declaration-altitude check). Nothing reads the **delivered code** against the design intent. "Is this module deep" is a semantic judgment (Rice / intension–extension), not a behavior, so it can never be a TDD-style AC; it needs a *judging reader* on the code, which today does not exist.

The named failure this leaves open: an **AC-green-but-shallow** implementation. Worked example — the `SspSession` active-session struct (~25 fine-grained mutators with the orchestration living in the handlers = a shallow module; plus same-name-two-meaning fields) was missed end-to-end by every touchstone gate; it surfaced only via an external manual audit. `design-review` reviews a *document* (its "Interfaces" item = contract specificity, NOT interface narrowness/depth); `code-review` is diff-scoped quality/security with no module-depth axis; `keystone` decides a named fork but does not *scan*. The doctrine (`arch-rubric.md` interface-economy force + deep-module L3) exists; the **wiring** is missing.

The fork explored three feedback surfaces and rejected the reflexive ones:

1. A new dedicated subsystem-scoped FB skill — owns the class but is a standing new gate built before the felt pain recurs (YAGNI / speculative cost).
2. A module-depth dimension on `code-review` — diff-scoped, so it **structurally cannot** catch accreted debt (the SSP struct accreted over many commits, each diff innocent); piling a lens on a gate that also can't catch the target class.
3. Both — four touchpoints (author + design-review + code-review + new skill) = piling lenses, which the gate-topology doctrine names as the anti-pattern ("a gate earns its place by one unique false-green class; quality lives in gates that name their class, not piling lenses").

A re-clarification of each `design-spec` section's purpose showed that **structural design-intent is genuinely homeless**: `## Architecture` is descriptive (system shape, "skip if additive"); `## Invariants` is *correctness* rules that become property tests; `## Interfaces / Contracts` is *specificity* for the inner TDD loop. The arch-rubric forces (interface-economy / cohesion / coupling) are a *structural commitment* kind — distinct from all three.

## Decision

Wire the design-quality arm as **two arms of one existing lens**, mirroring evidence-honesty's two-arm structure (declare @ design-review, verify @ batch) — **zero new gate**.

1. **Feedforward — `## Architecture` becomes normative.** `design-spec`'s `## Architecture` section is sharpened from descriptive-shape to **normative**: it authors per-component structural commitments grounded in `arch-rubric.md` (e.g. "module M SHALL be deep — hide X; SHALL NOT leak its orchestration sequence to callers"). It **loads** `arch-rubric.md`; it never restates the interface-economy force (bridge-content-gate P1 non-duplication). These commitments are an **L3 application of the existing interface-economy L2 force** — no new axis. They are reviewed at design time by the design-soundness lens that already exists at `design-review` (ADR-0026).

2. **Feedback — the design-soundness lens grows a feedback arm at the deliverable review.** The same design-soundness lens runs a second time at the **deliverable review** (anvil's final cross-vendor review / `code-review batch`): an **AI-semantic, subsystem-scoped honor-check** of the delivered code against the spec's normative `## Architecture` commitments. It is **not** per-task and **not** a per-diff lens — it reviews the whole deliverable against the whole Architecture section, which is the scope the judgment actually needs. It rides an existing review surface (no new gate).

3. **The check is semantic, not mechanical.** Module-depth honor cannot be deterministically decided (Rice). The deterministic floor checks only **structural presence** — that a spec carrying normative `## Architecture` commitments is *referenced* by the deliverable review (the floor never judges whether a commitment was honored). Honor is the reviewer's AI-semantic judgment, consistent with how the spine already treats AC coverage and sweep saturation. (This is the qualified-AC pattern: a mechanical floor where mechanizable, a semantic review scoped at the subject — never a deterministic check masquerading as a semantic verdict.)

4. **Deferred increment — commitment-less accreted debt.** The honor-check catches "spec declared a structural commitment, code did not honor it." It cannot catch a shallow module that accreted with **no governing spec commitment** (the historical SSP case) — there is nothing to check against. A standalone subsystem-scan for commitment-less accreted debt is **deferred**, with the flip-trigger below.

## Honest ceiling (what this round does NOT buy)

This round does not catch the historical, commitment-less, accreted SSP struct — only going-forward work where a spec authored an `## Architecture` commitment the code then violated. The original epic acceptance bar ("scan a struct of the SSP shape and raise shallow-module") is therefore **re-scoped**: the demonstrable bar this round is "a spec declares a normative structural commitment; the deliverable review flags code that violates it." The SSP-as-accreted-no-spec catch belongs to the deferred subsystem-scan.

## Flip-trigger

Build the deferred standalone subsystem-scan when a **second** commitment-less accreted shallow-module miss (SSP-class) reaches a deliverable — i.e. structural debt the honor-check cannot catch because no governing spec commitment existed — recurs as a felt pain. Review owner: the touchstone maintainer, at epic close or the next architecture-drift incident, whichever first.

## Alternatives considered

- **New dedicated FB skill now** (fork option 1) — rejected: a standing new gate built ahead of recurring felt pain; the honor-check rides existing reviews at lower cost; the gate-topology doctrine prefers owning the class in the smallest sufficient surface.
- **Module-depth dimension on `code-review`** (fork option 2) — rejected: diff-scoped, structurally blind to accreted debt; piles a lens on a gate that cannot catch the class.
- **Both** (fork option 3) — rejected: four touchpoints = piling lenses (gate-topology anti-pattern).
- **Home structural intent in `## Invariants` or `## Interfaces`** — rejected: cohesion — those sections own *correctness* and *specificity* respectively; overloading either with structural commitments muddies one-reason-to-change.

## Consequences

- **design-spec/template.md**: `## Architecture` reworded to normative — authors arch-rubric-grounded per-component structural commitments; drops "skip if additive" for components with depth stakes; loads (never restates) `arch-rubric.md`.
- **design-review SKILL.md**: design-soundness lens already present (ADR-0026); its scope note clarified to read the spec's normative `## Architecture` commitments as the feedforward subject.
- **deliverable review** (anvil final-review prompt / `code-review batch`): gains the design-soundness **feedback arm** — an honor-check of delivered code against the spec's `## Architecture` commitments; AI-semantic, subsystem-scoped, deterministic floor checks reference-presence only.
- **CONTEXT.md**: a glossary entry for the design-soundness lens's two arms (declare @ design-review / honor-check @ deliverable review), parallel to the evidence-honesty two-arm entry.
- No new gate, no new Review-Gate row, no new skill this round.

## Related ADRs

- ADR-0026 (consolidated design-review, design-soundness lens) — this adds that lens's **feedback arm**; ADR-0026 wired only its feedforward (doc) arm.
- ADR-0020 (locality-first / deep-module-over-merge) — the deep-module doctrine and `arch-rubric.md` single-home this builds on.
- ADR-0019 (keystone substrate-neutral arch-rubric) — the L1/L2/L3 rubric the structural commitments are graded against; deep-module is L3 of the interface-economy L2 force.
- ADR-0009 / ADR-0010 (evidence-honesty gate / live-bearing AC) — the two-arm (declare/verify) structure this mirrors for design quality.
- ADR-0018 (honesty-spine two-pillar) — design quality as the second pillar's feedback expression (constrain-before + measure-after).
