---
kind: workflow
adr_id: 0033
status: Accepted
date: 2026-07-04
---

# ADR-0033: Vocabulary-evolution ledger, 2026 H1 (batch)

## Status

Accepted. A batch ledger entry: it moves the decision *narratives* that had
accreted inline in `CONTEXT.md` into the ADR ledger where rationale history
belongs, so `CONTEXT.md` stays a present-tense vocabulary table. No decision
below is new; each was settled on the date given.

## Context

`CONTEXT.md` is the living vocabulary/authority table. Over 2026 H1 it
accumulated supersession parentheticals ("supersedes the earlier X framing",
"settled YYYY-MM-DD", "dropped YYYY-MM-DD") — history narration a present-tense
reader does not need and the skill-comprehension doctrine forbids leaving in
hot surfaces. The narratives are preserved here; `CONTEXT.md` keeps only the
current rule.

## The ledger

1. **Contract-spine 3-layer model** (settled 2026-06-20/21, skill-ceiling
   Phase-2 grill + a layering first-principles drill): the layers above the AC
   are three points on one intension→extension continuum — user-story →
   requirement → AC. A prior 2-layer framing (story folded into requirement)
   was superseded by the drill.
2. **Always-3-layer production** (decided 2026-06-22): all three layers are
   always produced; solo/non-solo is a READ-depth choice, never a production
   switch. Supersedes the earlier "user-story folds into requirement when
   solo" framing — folding was about production; the completeness floor is
   solo-independent, so production is uniform and the audience picks depth.
3. **OpenSpec dependency dropped** (2026-06-15): touchstone owns its doc
   architecture; OpenSpec's Requirement/Scenario partition is borrowed as a
   reference SHAPE only — no live `opsx` binding, no adapter, storage is the
   local `.md` file. `AC` is the native spine term; `scenario` is merely the
   reference template's word for the same object.
4. **story→requirement completeness** (settled 2026-06-22, first-principles):
   the rung above requirement→AC has the SAME intension–extension floor — no
   finite check totalizes it; the arm shape (enumerate-and-witness + human
   recognition) is reused one rung up rather than a new mechanism invented.
5. **Build-phase vocabulary** (settled 2026-06-27, skill-ceiling Phase 3):
   the back-end layer names — anvil's stage set, Level-A sequencing
   determinism, Level-B per-task independence, the anvil honest ceiling — as
   now tabled in `CONTEXT.md § Build-phase vocabulary`.
6. **Verification vocabulary origin** (testing-strategy epic, closed
   2026-05-27): live-bearing AC, `[unverified]`, coverage-honesty — the terms
   the evidence-honesty lens carries; live in `code-review batch` and the
   epic-close reckoning since that epic shipped.
7. **`_shared/` no-single-host principle** (ADR-0020 Amendment, 2026-06-24):
   cross-skill instruction blocks live in `skills/_shared/` governed by
   no-single-host (same root as the Bridge proximity ladder); recorded here so
   the amendment's date narration can leave the `CONTEXT.md` table.

## Consequences

- `CONTEXT.md` entries state current rules only; "what changed and when" has
  exactly one home (this ledger + the per-decision ADRs it cites).
- Future vocabulary supersessions append a dated entry to an ADR (this batch
  pattern or a dedicated one), never a parenthetical in `CONTEXT.md`.

## Addendum — 2026-07-06 gate re-audit (entries 8–9)

8. **Four-role activation taxonomy retired from `CONTEXT.md`** (2026-07-06):
   the Skill / Mode / Discipline / Baseline block (structural roles table,
   classification flow, agency rationale, current inventory, fire ordering)
   was consumption-audited as orphan — no live surface routed a reader to it,
   and its example row cited the since-retired `grill-with-docs` skill. The
   decision content it carried, for the record: cross-cutting behaviour is
   classified by activation scope (per-invocation Skill / per-session Mode /
   per-project Discipline via `.claude/touchstone.yaml` `adopted_disciplines:`
   / per-plugin Baseline); the classifying question is who has agency over
   the toggle; scope-framing fires before content-rules (intention-first →
   source-as-truth → active Modes). The mechanisms all remain live
   (config-resolver, `adopted_disciplines`, the skills themselves) — only the
   taxonomy prose leaves `CONTEXT.md`. `§ Honesty spine` keeps its "not an
   activation scope of its own" clause without the table.
9. **Epic-tracker projection vocabulary retired from `CONTEXT.md`**
   (2026-07-06): the section duplicated the live home —
   `skills/epic-driven-roadmap/README.md` "Portability model" + ADR-0024 —
   which is what actual readers hit (consumption audit found zero inbound
   references to the CONTEXT.md copy). The terms (agent-as-universal-shim,
   projection, reconciliation, field-location mapping, canonical minimum)
   continue to live there; single-home collapse, no semantic change.
   ("Three layers of knowledge" was also pruned the same day as a pure
   orphan — navigation/bridge/source trust levels remain derivable from
   `§ Four doc kinds` + `§ Bridge content gate`; no decision content lost.)
