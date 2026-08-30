---
kind: workflow
adr_id: 0042
status: accepted
date: 2026-08-30
supersedes: 0041 (the composite-skill ruling; 0020's deep-module-over-merge rule stands)
---

# ADR-0042: Lens × arm review (supersedes ADR-0041's composite ruling)

- **Status:** accepted
- **Date:** 2026-08-30
- **Deciders:** miles (owner)
- **Triggered by:** `/touchstone:assay` (assay-2026-08-30-phase3-refs, rows A-42, A-43, A-44, Q-54..Q-57) → `/touchstone:design-spec (2026-08-30-phase3-refs-and-lens-arm.spec.yaml)`
- **Related ADRs:** 0020 (deep modules over a parameterized merge), 0041 (the composite pair merged into one composite)
- **Flip-trigger:** the first phase reviewed under lens × arm shows the Codex arm's share of unique High findings at the design gate ≥ the CC arm's → make cross-vendor a required arm configuration at the design gate too (today it is required only at the code gate). Revisit point: the phase-ship metrics line of the next phase; the owner reads `found_by` counts in that phase's review.yaml.
- **Bet-owner:** miles
- **Assumptions:** (1) a finding's value comes from the perspective (lens) that produced it more than from the vendor that ran it; (2) independence — the reviewer is never the builder — is the property that must be an invariant, and vendor diversity is only one way to obtain it; (3) the static token estimate (unique loaded bytes ÷ 4) is a usable relative measure of the stage-1 load until a transcript-usage measure replaces it.

## Context

ADR-0041 merged two Pattern-A composites into one (`cross-provider-reviewer`, two internal roles), on the measured fact that they shared more than they diverged. By phase 2 of the human-facing-comm epic the composite had a single live caller (assay's structural-fork critique); design-review and deliverable-review dispatched the two arm agents themselves and only borrowed the composite's provenance table. The plugin's own review (plugin-review round 2, F-9) asked which body actually invokes the composite; the phase-2 load map counted the composite's three files in the contract stage's load set for a skill nothing in that stage executes.

The gates were also shaped by **vendor**: "CC one agent, Codex one agent". That shape hides the question the owner actually wants answered — which perspectives ran, and which arm found what — and makes "add a second arm to one lens" a skill rewrite instead of a configuration.

## Decision

We will make the **lens** the unit of review and the **arm** its configuration:

- A gate declares its lens set (`lenses: [{name, arms, prompt_home}]`) in its body; every lens is dispatched to each of its arms in one message; the merge is keyed by lens; `review.yaml` records `providers` per lens and `found_by` (the arm list) per finding.
- **Vendor diversity is a property of the arm set.** It is a required configuration exactly where independence would otherwise fail: deliverable-review's quality lens must hold the vendor opposite the builder (reviewer ≠ builder is the invariant). Elsewhere it is optional and measurable (`found_by`).
- The composite `cross-provider-reviewer` is deleted. Its provenance table moves to `skills/_shared/provenance.md` (the shared layer, referenced by the two gates and assay); its critique lenses move to `skills/assay/references/critique-lens.md`; assay's fork case dispatches the two arms directly.
- **Provisional load target (direction, not a rule of this phase):** the contract stage's load, measured in tokens (unique loaded bytes ÷ 4), should reach ~10k, with 15k as the waypoint. The single-entry-refactor phase owns that target; this phase only changes the ratchet's unit to tokens and re-seeds the baseline at the measured value.

## Alternatives Considered

- **Keep the composite as the dispatcher every gate calls.** Rejected: one caller, and the gates need per-lens control the composite's two closed roles cannot express.
- **Vendor as the unit ("cross-vendor everywhere").** Rejected: it spends review budget on the vendor axis where the evidence (phase-1/2 rounds) shows the framing, not the vendor, produced the unique findings; it also cannot say which perspective a finding came from.
- **Independence by headcount (two arms always).** Rejected: two arms of the builder's own vendor are not independent; the invariant is reviewer ≠ builder, so the rule is placed on the arm set of the lens where it matters.

## Consequences

- Adding an arm to a lens is a one-line change in the gate's lens table; the merge and the schema already carry it.
- Every finding carries `found_by`, so the next phase can decide from data whether a lens needs a second arm (the flip-trigger above).
- The provenance vocabulary (lens, arm, degraded per lens) is shared by three skills; a change to it is a change to `skills/_shared/provenance.md` alone.
- The phase's own review gates still run under the previous (3.0.1) skills; the reshaped gates are exercised on scratch subjects in this phase and adopted by the next.
