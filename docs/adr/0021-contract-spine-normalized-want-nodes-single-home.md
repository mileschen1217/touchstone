---
kind: workflow
adr_id: 0021
status: Accepted
date: 2026-06-23
kill-on: skill-ceiling
---

# ADR-0021: Contract spine uses normalized want-nodes; the want-layer lives in the PRD, produced by an always-on to-prd folded into the design-spec

## Status

Accepted. Establishes the first-principles root under the three-layer contract spine
(want → requirement → acceptance-criterion) that the prior phase introduced as
"always-3-layer". Refines that feature: the want-layer (PRD) is no longer produced by a
separately-chained skill nor inherited across artifacts — `to-prd` is **folded into the
design-spec and always runs**, producing the PRD layer inline. The want still lives in the
**PRD layer**, not in the design layer; the design-spec consumes/traces to it.

## Context

The contract spine traces user-stories (wants) → requirements → acceptance criteria. A
recurring challenge — raised again while dogfooding the front-end orchestrator — is: *why
keep a distinct want-layer at all? Can't a requirement just carry the want's meaning in a
"why" field, so there is only one layer?* The same question recurs one rung up: *is a
stakeholder-facing PRD a distinct document from the engineering spec, or just a view of it?*

Both questions are the same question at different rungs. Answering them from first
principles (rather than by convention) is what this ADR records, because a future reader
will otherwise re-ask "why two layers" and be tempted to collapse them — reintroducing the
exact scope-drop failure the spine exists to prevent.

## Decision

1. **The want is a normalized, first-class, persistent node — separated from the
   requirement by cardinality, not by ceremony.** A want and a requirement are different
   *units*: the requirement is the unit you **act on**; the want is the unit you **judge
   coverage against** (act-unit ≠ judge-unit). The relation want↔requirement is at least
   one-to-many (one want decomposes into several requirements) and often many-to-many (one
   cross-cutting requirement serves several wants). Folding the want into a "why" field on
   the requirement is **denormalization**, valid only at strict 1:1. Under one-to-many it
   produces the classic anomalies; the **deletion anomaly is the scope-drop failure
   itself** — drop the last requirement carrying a want and the want vanishes silently, so
   you can never detect "this want is now uncovered." Keeping wants as their own normalized
   node-set (the want-layer) + a trace junction (`traces-to`) is what makes
   "every want has ≥1 requirement" checkable. This is normal form, not ceremony.

2. **Coverage is a continuous standing invariant, so want-nodes must persist; folding is
   legal only when the want stays continuously visible and confirmable.** "Confirmed
   covered once" ≠ "covered forever": every later edit can drop a requirement and re-open an
   uncovered want, so the structural coverage check must be re-runnable, which requires the
   want-nodes to remain present. Collapsing the *machinery* (no separate upstream artifact —
   see Decision 3) is fine; collapsing the *nodes at rest* (deleting wants after a one-time
   confirmation) is not — it destroys re-traceability. The 1:1 collapse is safe precisely
   because the want stays visible (it sits on its single requirement) and coverage is
   trivially re-confirmable; one-to-many collapse-at-rest is unsafe because it destroys the
   single checkable want-node. **The want *form* may be lightweight** (a one-line `US-N:
   <want>` entry) — what is non-negotiable is the want's *node-ness* (first-class,
   enumerated, persistent), not the "as-a-role… so-that…" prose template.

3. **The want-layer has exactly ONE home — the PRD — reached by always producing it
   (single-home via always-on, not by moving the want).** The PRD layer (why + the `US-N`
   want-nodes) and the design layer (requirement + AC) are **two distinct co-located layers
   of one artifact**, at two altitudes / two audiences (stakeholder-why vs engineer-contract
   — the PRD/SRS/SDS distinction): the want is owned by the PRD layer; the design layer
   **consumes and traces to** it (`traces-to: US-N`) and does **not** own it. `to-prd` (the
   PRD-layer producer) is **folded into the design-spec skill and always triggers** — every
   invocation produces the PRD layer first (why + US-N), then requirements tracing to those
   wants, then ACs, then an internal coverage audit (a want whose requirements are all shared
   — nothing is orphaned by removing it — is surfaced as a demote-to-invariant candidate).
   Because the PRD layer is co-located in the same artifact, there is no separate chained
   `to-prd` skill, no cross-artifact mirror, and no re-sync. **The single home is achieved by
   making PRD production unconditional** (always-on), so the want **always** lands in the PRD
   layer — never "sometimes in a PRD, sometimes in the spec." That variable-home alternative
   (conditional/optional PRD) was rejected: the per-case placement decision itself taxes the
   scarce human attention the whole subsystem exists to conserve. The bet (an explicit
   arch-invariant P×cost / YAGNI-on-cost call): one fixed always-present home buys more (zero
   placement-decision tax, one place to read/verify the wants) than a conditional or a
   higher one-to-many system document is expected to pay back at this project's scale.

## Consequences

- The front-end chain's tail collapses to **grill → design-spec**; every design-spec
  invocation always runs the folded-in `to-prd` first to produce the PRD layer (why + US-N),
  then traces requirements to those wants, derives ACs, and audits coverage — one artifact,
  two co-located layers, one always-present home for the want, no separate chained skill, no
  cross-artifact mirror or re-sync. The PRD layer owns the want; the design layer traces to it.
- The PRD-layer producer (the human-heavy want-recognition step) and requirement/AC partition
  co-locate in one skill; the layer-specific procedures move to the skill's `references/` so
  the body stays a small orchestration interface (deep module, not a bloated god-skill) —
  the guardrail carried from the keystone consult on this merge.
- **Flip-trigger (revisit-when):** if the PRD layer genuinely needs to span multiple
  design-specs (one PRD → many specs becomes real and frequent — system-level wants
  duplicated across several artifacts), the co-located always-on model breaks — separate the
  PRD into a standalone higher-altitude document and re-pay the placement cost. Decisions 1–2
  (normalized persistent want-nodes, continuous coverage) do not flip — they are the root,
  not the bet.

## Addendum (2026-06-23, keystone consult during Phase-2.9 design-spec drafting)

**Triggered by:** `/touchstone:keystone` (artifact-count structural fork) while drafting the
Phase-2.9 spec. **Supersedes the placement half of Decision 3** (the "one artifact / no
mirror" bet); Decisions 1–2 stand unchanged.

**The fork.** Decision 3 (above) committed to ONE artifact with the PRD layer co-located as a
section of the design-spec. Re-examined under a keystone consult, the human re-chose a
different placement on these stakes: an externally-shareable PRD, one uniform output mode,
and the System-definition → SRS → SDS layered-document feel.

**Engine evidence** (`cross-provider-architect` keystone consult, 2026-06; transcript retained
in the maintainer's local research notes). Both providers independently found
that a NAIVE two-artifact model with two *living* masters reconciled by "snapshot-authority"
convention re-opens a silent false-green: a want added to the PRD after the spec is drafted is
invisible to the single-file `check-spec-floor.sh` → silent scope-drop, the exact failure the
spine exists to prevent. CC: conditional-approve only with a fail-closed `us_revision` parity
check. Codex: block the naive form; prefer a single living canonical.

**Field research** (SDD-framework survey — Spec-Kit, Kiro, BMAD,
Tessl, OpenSpec, IEEE 29148). No SDD framework mechanically enforces want→spec cross-document
parity — all rely on LLM-regeneration + human/LLM review. The mechanical leaders (Tessl
spec-as-source; OpenSpec single canonical `specs/` with the intent doc transient + archived)
converge on ONE living canonical; none maintain two living parallel masters.

**Resolution (the bet).**
- **The canonical is the design-spec** — a single living source. The want-layer lives IN it,
  mapped to existing sections: `why` = `## Foundation` Intention; the `US-N` want-nodes =
  `## User Stories`; out-of-scope = `## Foundation` Out of scope. No separate "PRD section"
  inside the spec (that would re-duplicate within one file).
- **Want-authoring is always-on and native to design-spec** (mandatory; `check-spec-floor.sh`
  enforces every `US-N` has ≥1 `traces-to`). This is how single-home-via-always-on (Decision 3's
  surviving intent) is now achieved — by the mandatory in-spec want-layer, NOT by a co-located
  PRD layer produced by a folded-in `to-prd`.
- **`to-prd` is removed from touchstone's wiring.** It was an external (Matt Pocock) skill
  chained by `crucible`; the chain drops it. There is no folded-in `to-prd` and no touchstone
  PRD-export. The shareable PRD is a **human, out-of-band** action when a real external-share
  need arises (the human runs `to-prd` or any tool, or copies the three sections). Touchstone
  owns only the want-layer in the canonical spec; the external PRD document is not touchstone's
  concern.
- **Want-authoring guidance** = touchstone's own derived structural/completeness principle
  (US-N as intension pole / judge-unit; recognition via `brainstorming`, not EP/BVA; the
  `traces-to` anchor; anti-redundancy — a requirement adds rule-altitude precision over its
  story) PLUS cited commodity conventions (the `As a <role>, I want… so that…` template,
  Spec-Kit's WHAT/WHY-not-HOW, INVEST), referenced not recopied.

**What flips:** Decision 3's "two co-located layers of one artifact, always-on `to-prd`
folded in, no mirror." **What stands:** Decisions 1–2 — the want remains a normalized,
persistent, enumerable node; coverage is a continuous re-runnable invariant; the
deletion-anomaly is the scope-drop failure. The want's single home is now the spec's
`## User Stories`, checked single-file (no cross-artifact mirror exists to drift).

**Flip-trigger (this addendum):** if a *living, externally-editable* PRD (stakeholders amend
it in place, expecting propagation) becomes a hard requirement, revisit → adopt the
two-living-master model with a fail-closed `us_revision` parity check (CC's mechanism), and
accept that touchstone would be pioneering a parity guard no surveyed SDD framework ships.

**Bet-owner:** the human (project owner). **Engine note:** the default software-arch engine
serves this doc/information-architecture fork adequately because the core reasoning is
data-normalization (want-node persistence + coverage re-runnability) — recorded, no
no-engine-evidence gap.
