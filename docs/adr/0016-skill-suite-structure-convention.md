---
kind: workflow
adr_id: 0016
status: Accepted
date: 2026-06-19
---

# ADR-0016: Skill-suite structure convention — conservative pruning under a human regression-oracle

> Numbering note: ADR-0013/0014 live on the `dev` integration line, not this branch's `main`
> base; 0015–0016 are the globally-next numbers. The gap is a branch-divergence artifact.

## Status

Accepted. Decided by a Pattern-A arch consult (CC architect + Codex adversarial) during the
`skill-ceiling` Phase-1 audit. Codex's verdict was **block**; this ADR adopts the conservative
synthesis (revise → proceed under binding conditions), because the block is spine-aligned.

## Triggered by

`skill-ceiling` Phase 1 — the per-skill audit found 20–40% bloat across the 11 touchstone plugin
skills from three roots: orientation/README content in the executable body; content inlined that a
shared reference already owns; and over-pinned verbatim/AC-label leakage.

## Context

A skill = a prompt-injected instruction that wrangles determinism out of a stochastic agent.
The audit invited an aggressive prune. The adversarial review surfaced the decisive risk:

**Pruning a skill with no behavioral regression test is itself a false-green.** The behavioral
step0-fixture runner is not wired; a pre-commit structural check (`check-foundation-gate-structure.sh`) runs structural greps via the pre-commit checker, but this is structural, not behavioral. Repeated wording in a skill is sometimes the mechanism that
survives truncation / partial attention — removing it can leave the skill semantically
underconstrained while looking cleaner, and the regression is silent. Likewise, moving
disambiguation that prevents a defect (e.g. the critique-vs-gate boundary, ADR-0015) out of the
SKILL.md body risks re-introducing the very defect it prevents.

## Decision

Adopt this skill-suite structure convention:

1. **SKILL.md body = executable procedure.** Move only **provably-omittable** orientation
   (history notes, Related/Dependencies lists already carried by CONTEXT.md) to a per-skill
   `README.md`. Content CONTEXT.md already encodes → delete (Bridge P1). **Load-bearing
   disambiguation stays in-skill** as a minimal block — it is not orientation.
2. **Shared mechanism → `skills/_shared/<concern>.md`**, one file per concern (no consolidated
   god-file index; Bridge P3). Any extraction is **atomic** with repointing its static checker;
   the step0-fixtures test agent OUTPUT, not file content, so they are unaffected by a move.
3. **The human is the named regression oracle** for every prune/extraction commit until a
   behavioral harness is wired: the reviewer reads the changed SKILL.md end-to-end and confirms it
   still steers. Do NOT claim "still works" from green static checks alone. Wiring a minimal
   behavioral step0-fixture check is the real unblock and is tracked as follow-on.
4. **Pattern-A composites are NOT merged/extracted** — accept the ~20-line shared scaffold as
   duplication guarded by a machine-checked drift assert. Flips only if a 3rd composite appears or
   the shared section exceeds ~50 lines.
   > **Amended 2026-07-06 (md-essence-rewrite ruling):** the human-accepted essence-rewrite
   > contract flipped this by direct ruling — the shared scaffold (provenance/artifacts/failure
   > semantics/return) is extracted to `skills/_shared/pattern-a-base.md`. The Codex-probe block
   > stays inline in EACH composite; the machine drift assert in
   > `check-foundation-gate-structure.sh` (probe ×2, composite count = 2) remains live.
5. **`keep-long` annotations** must carry a current line count, enforced by the static checker, and
   declare any orientation kept inline. Length is a ceiling, never a target.

The 20–40% reduction is a ceiling realized only where provably safe — not a goal in itself.

## Consequences

- Phase-1 execution proceeds conservatively: keep-long honesty fix + foundation-gate extraction
  (well-bounded, atomic with checker) first; orientation→README only per-section where safe.
- A new standing obligation: skill pruning is gated on human end-to-end review (oracle) until a
  behavioral skill-regression check exists. Same `claim ≤ evidence` posture as the rest of the spine.
- A `README.md`-rot risk is accepted: orientation that is not worth keeping current should be
  deleted, not moved.

## Related ADRs

- ADR-0015 (critique never discharges the gate) — its boundary block is the canonical example of
  load-bearing disambiguation that must stay in-skill (condition 1).
- ADR-0011 (honesty spine as Constitution) — "pruning-and-claiming-safe without a test = false-green"
  is a direct `claim ≤ evidence` application; it is why the adversarial block was adopted.
