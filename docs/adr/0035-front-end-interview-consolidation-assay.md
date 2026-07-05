---
kind: workflow
adr_id: 0035
status: Accepted
date: 2026-07-05
---

# ADR-0035: Front-end interview consolidation — assay as the fused instrument

**Triggered by:** `/touchstone:crucible` (guardrail-interview-and-gate-reaudit, Phase 1 contract interview — the instrument dogfooding its own fixation, second run)
**Related ADRs:** 0034 (guardrail interview GO + keystone absorption), 0032 (plugin boundary — slim inside known ceilings), 0026 (consolidated design-review), 0023 (grill-before-explore)
**Bet-owner:** Miles

## Context

ADR-0034 ruled GO on fixing the guardrail interview as a skill (named `assay`,
forging series) with keystone absorbed. During the fixation contract's own
interview, three structural questions opened beyond ADR-0034's scope:

1. touchstone's front-end chain hard-depends on `grill-with-docs` — a
   **user-global private skill** no external plugin user can install. The
   superpowers exception-dep precedent (official plugin ≈ CC capability) does
   not cover it. Self-containment hole.
2. `superpowers:brainstorming` as crucible's conditional first step has fired
   0–1 times since wiring (human testimony): in an existing project, intent
   arrives pre-formed; the work is sharpening. Yet crucible Step 0 hard-stops
   on its absence — a near-zero-fire step carrying a hard external dependency
   (retirement-policy R1′ cost-to-keep analysis).
3. Three sequential interviews (brainstorm → grill → assay) is heavy per
   contract; the human sit-down count, not the concepts, is the cost (S6:
   human availability is the wall-clock bottleneck).

Key insight from the interview: the three layers have distinct comparators
(recognition / vocabulary / unknown-accounting) but identical mechanics
(question the human). And falsifiability already forces terminology precision —
every 1a assumption must name file/interface/behavior against the docs, so a
vocabulary conflict surfaces AS an assumption mismatch. A separate vocabulary
pass is redundant in the common case.

## Decision

1. **assay is a fused single-session interview** — not a multi-pass lens
   stack. Doc-grounding is part of 1a falsifiability (each assumption checked
   against CONTEXT.md / ADRs); vocabulary alignment happens per-assumption
   inside the same conversation. assay's body carries grill's **write-side
   discipline** as a standing rule: when a term resolves against the docs,
   update CONTEXT.md inline.
2. **assay becomes touchstone's own front-door interview;
   `grill-with-docs` exits the crucible chain NOW (Phase 1)** — the human
   ruled the exit forward from the staged plan. Rationale: the deviation log
   measures the residual directly (what the fused interview misses is the
   instrument's standing validity metric), which is a more direct measurement
   than keeping grill and measuring overlap; the failure cost is an internal
   hole (rework), not an escaped false-green. `grill-with-docs` remains the
   user's personal skill for non-touchstone work. Flip-trigger: vocabulary-
   class misses (term-conflict gaps grill would have caught) recurring in the
   deviation log / gate-miss ledger → reinstate a vocabulary step or add a
   dedicated vocabulary lens to assay. assay's body stays shaped for lens
   addition without rename/rewire.
3. **`superpowers:brainstorming` is removed from the crucible chain now**
   (Phase 1). Retirement grounds: R1′ cost-to-keep (hard Step-0 dependency +
   skip-signal cognitive area vs 0–1 fires). Out-of-band access persists
   (the plugin does not uninstall it); assay's interview carries one steering
   line: if intent is genuinely unformed, recommend an out-of-band
   brainstorming run before continuing. Flip-trigger: if ≥2 future contracts
   stall on unformed intent requiring out-of-band brainstorming, revisit the
   chain step.
4. **keystone absorption executes as ADR-0034 §3 ruled** — clean retirement
   of the standalone entry; the structural fork becomes one readiness-fork
   case inside assay; ADR fields (flip-trigger / bet-owner / assumptions)
   carry over into assay's fork dispositions.
5. **foundation-gate stays put (v1)** — real overlap with assay 1b
   acknowledged, but `_shared/foundation-gate.md` serves two callers and the
   epic-scaffold caller (Stage 0) runs before crucible, so a merge cannot
   reach it. Flip-trigger: Phase 2 dogfood measures duplication between assay
   1b extraction and the foundation 3 fields; substantive duplication →
   revisit (merge direction: design-spec's foundation elicitation degrades to
   "inherit assay output"; the epic-scaffold end keeps its own).

## Assumptions (decision bets, not implementation facts)

- Brainstorm 0–1 fire testimony holds (no fire-log for chain steps; human
  recall is the only denominator).
- Vocabulary conflicts not attached to any surfaced assumption are rare
  enough to leave to the FB tower (named residual: consistently-shared wrong
  terms are invisible to a fused interview).
- CONTEXT.md's marginal-read cost stays below re-derivation cost while the
  admission narrowing (below) holds its size.

## Consequences

- Crucible chain (Phase-1 landed shape): **intention (Stage-0 foundation) →
  explore → assay → design-spec → design-review**; brainstorming and
  grill-with-docs steps deleted; keystone step replaced in place by assay
  (unconditional + proportionality fast-path); crucible Step 0 external-skill
  dependency check drops with them.
- Global CLAUDE.md's mandatory grill gate (pre-spec vocabulary alignment for
  DIRECT stage-skill invocation) re-targets to assay at ship — executed under
  the harness maintenance procedure (backup + changelog), since the plugin
  chain no longer contains a grill step to discharge it.
- CONTEXT.md §story→requirement completeness re-points its generative
  recognition step from `brainstorming` to "assay's intent extraction;
  out-of-band brainstorming for genuinely unformed intent".
- **CONTEXT.md admission narrowing** (ruled in the same interview): only
  cross-epic load-bearing terms enter (referenced by ≥2 epics or a shipped
  surface); single-epic terminology lives and dies with its epic's spec. One
  boundary line lands in CONTEXT.md's "What this document is"; a consumption
  audit (which lines are actually read/referenced) goes to the Phase 2 gate
  re-audit for a denominator-backed pruning ruling.
- The honest ceiling stands (ADR-0034 §4): assay narrows unknown-unknowns,
  never proves them zero; instrument validity is measured downstream by the
  deviation log, not claimed at interview end.
