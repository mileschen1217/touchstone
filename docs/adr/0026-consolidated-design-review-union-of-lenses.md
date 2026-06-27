---
kind: workflow
adr_id: 0026
status: Accepted
date: 2026-06-28
---

# ADR-0026: Consolidated design-review applies the UNION of design-soundness and verification-honesty lenses

## Status

Accepted. Decided during Phase 3.2 of the `skill-ceiling` epic (front-end seam 3→2 merge).

**Supersedes: ADR-0015** (see below — the ban on substitution is preserved; this ADR adds the union over two lens-sets and front-loads the gate to the crucible chain).

## Triggered by

Phase 3.2 `skill-ceiling` — architect-critique dispatch was removed from `design-spec` (A1), collapsing the 3-gate front-end (design-spec critique + human-accept + design-review) to 2 (consolidated design-review before human-accept). The consolidation forced the question: the architect critique formerly applied structural / failure-mode lenses; the existing design-review applied verification-honesty lenses. Merging them into one gate required explicitly stating which lenses apply.

## Context

Prior to Phase 3.2:
- `design-spec` ran an **architect critique** (design-soundness lens — structural validity, failure modes, edge cases) as author-time advisory.
- `/touchstone:design-review` ran the **verification-honesty lens** (Verification-Strategy, live-bearing, coverage, `[unverified]`) as the Stage-0 C+H gate on the **final, human-accepted** artifact.

ADR-0015 established that the architect critique **never discharges** the design-review gate — the two are distinct checks with different backends and criteria; the currency of one does not transfer to the other.

Phase 3.2 removes the architect critique entirely (the author-time advisory was over-machinery once the gate became mandatory). This leaves one gate, but the gate must now carry BOTH lens-sets or the design-soundness checks would be silently dropped.

The risk to avoid: treating the union as **substitution** — running one lens and assuming the other is satisfied. That would be the same `claim ≤ evidence` violation ADR-0015 was written to prevent. The ban on substitution survives; only the invocation topology changes (one gate, both lenses, run earlier).

## Decision

The consolidated `/touchstone:design-review` applies **TWO lens-sets (UNION, not substitution)**:

- **(i) design-soundness** — structural validity, failure modes, edge cases; approach/architecture soundness.
- **(ii) verification-honesty** — Verification-Strategy declaration, live-bearing, coverage, `[unverified]` (the existing items 1–7 in the doc-review prompt).

**Passing one lens NEVER discharges the other.** A design-soundness-clean spec may still fail verification-honesty; a verification-honesty-clean spec may still surface design-soundness failures. Each finding is tagged `[lens: design-soundness]` or `[lens: verification-honesty]` so an auditor can count per-lens without re-running; a zero-finding lens must be visibly stated as zero, not hidden.

**Front-load (3→2):** crucible writes `status: accepted-candidate` on the spec, then invokes this consolidated gate before the terminal human-accept. A Critical/High on either lens halts; the spec stays `accepted-candidate` until a clean pass. Human-accept promotes `accepted-candidate → accepted` only after C+H = 0 on both lenses.

The gate still runs on standalone re-review of an `accepted` artifact (backward-compatible).

## Relationship to ADR-0015

ADR-0015's core rule — **the critic's verdict does not discharge the gate's currency** — survives intact. That rule was about *substitution*: one review claiming to discharge another. The union is the opposite: both reviews run, both lenses apply, neither discharges the other. The UNION does not violate the substitution ban; it enforces it at a finer grain (per lens-set, not per review instance).

ADR-0015 also framed the gate as running on the "final, human-accepted" artifact. That lifecycle ordering is updated: the gate now runs on `accepted-candidate` (pre-accept), which is the same artifact examined earlier. The substitution-ban and currency-mismatch doctrine are unchanged; the timing moves earlier (front-loaded), which is strictly safer than gating after accept.

## Consequences

- **design-review SKILL.md**: doc-review prompt extended with design-soundness lens block; per-finding `[lens: ...]` tag required; `STAGE-REVIEW-SUMMARY` sentinel added; lifecycle language updated from "final, human-accepted" to "`accepted-candidate` before crucible's accept".
- **crucible SKILL.md**: step 6 added (set `accepted-candidate`, invoke design-review); mid-chain halt updated from architect-critique-C/H to design-review-C/H; terminal accept promotes `accepted-candidate → accepted`.
- **design-review-precheck.sh**: already gates `accepted-candidate` (only `draft` skips); comment added to make intent explicit.
- **test-skill-wiring.sh**: `crucible-no-design-review-token` negative check flipped to `crucible-has-design-review-token` positive.
- No workflow throughput change in practice — the gate was always expected; it now runs slightly earlier (pre-accept vs post-accept) and carries an additional lens-set.

## Related ADRs

- ADR-0015 (critique-never-discharges-gate) — superseded in lifecycle framing; substitution-ban core rule preserved.
- ADR-0011 (honesty spine as Constitution) — this is a direct `claim ≤ evidence` application at the review-lifecycle boundary.
- ADR-0009 (evidence-honesty gate) — the verification-honesty lens this ADR incorporates into the union.
- ADR-0010 (live-bearing AC contract) — the live-bearing declaration the verification-honesty lens audits.
