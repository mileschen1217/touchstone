---
kind: workflow
adr_id: 0020
status: Accepted
date: 2026-06-23
kill-on: skill-ceiling
amends: 0016
---

# ADR-0020: Locality-first skill doctrine + deep-module-over-merge (amends ADR-0016)

## Status

Accepted. Amends ADR-0016 (skill-suite-structure-convention): revises its extract-lean
default (Decision pt 1-2) and reaffirms its pt 3 (human oracle) and pt 4 (composites not
merged). This keystone run is itself the **ADR-0018 revisit-signal firing** — a skill-suite
arch-revision / system-model-alignment need recurred (small scale), handled inline by
first-principles + keystone rather than reviving a heavy discovery process.

## Context

ADR-0016 came from a bloat-reduction audit, so its default leaned **extract-to-shared**
("content CONTEXT.md already encodes → delete"). Over subsequent phases CONTEXT.md accreted
from a terminology glossary into a "bible" — arch rationale, doctrine, schema, and
single-consumer concepts all centralized regardless of how many skills actually consume
them. The design-stage refactor (Phase 2.8) forced the question: where should doctrine live,
and should near-scaffold-duplicate skills merge?

## Decision

1. **Locality-first doctrine placement (revises ADR-0016 pt 1-2's lean).** Doctrine lives IN
   the consuming skill (deep module / cohesion) by default. Extract to a shared home
   (`_shared/` inject fragment or a CONTEXT.md definition) ONLY when there are **≥2 real
   consumers** (the consumer-count test). Rationale belongs in an ADR, not CONTEXT.md.
   CONTEXT.md retreats from "bible" to its original role: a **pure cross-cutting glossary**
   (canonical terms used across many skills), not a doctrine/arch repository. This inverts
   0016's extract-default; 0016 pt 2's "shared → `_shared/<concern>.md>`, atomic with its
   checker" mechanism still holds for the genuinely-shared (≥2-consumer) case.

2. **Deep-module-over-merge (reaffirms ADR-0016 pt 4, generalizes it).** The two Pattern-A
   composites (cross-provider-architect, cross-provider-reviewer) are NOT merged into one
   parameterized engine. Measured: shared in-body scaffold ~20 lines (heavy logic already in
   `references/provenance.md`), ~84/194 lines differ, and the two do genuinely different
   synthesis (validate+adversarial+conservative-verdict vs merge-findings+dedupe+divergence).
   0016 pt 4's flip-trigger (3rd composite OR shared >50 lines) is NOT met. More importantly,
   a `{architect|reviewer}`-parameterized engine would be a **shallow module** (large
   interface exposing the divergence) — violating the very deep-module principle this
   refactor optimizes toward. **General rule:** prefer two cohesive deep modules over one
   parameterized shallow module; "merge" is justified only when two skills are genuinely ONE
   concept artificially split (same substance), NOT when they merely share scaffold. This
   retires the broad "collapse all wrappers + composites into parameterized engines" vision
   as a default — wrapper-collapse is rejected wherever it would create a shallow module.

3. **Human-as-regression-oracle stays (reaffirms ADR-0016 pt 3).** Workflow/prompt skills
   resist deterministic/mechanical behavioral tests; a behavioral harness is NOT wired this
   phase. The human reviewer remains the named regression oracle for every skill
   prune/move/edit — the build's between-task review (and this very refactor's dogfood) is
   that oracle in action. ADR-0016's "wire a behavioral harness" remains the standing
   follow-on, deliberately deferred (not the right cost/benefit for prompt skills now).

4. **Guiding invariant — skills as distilled first-principle expression.** Each skill should
   be the **application and most-refined expression of the derived first-principle framework**
   (the two-pillar control axis, comparator-type-fixes-gate-ability, invariant-not-checklist,
   locality). A skill whose content does not trace to a first-principle is suspect (candidate
   for cut, fold, or re-derivation). This is the optimization target for the Phase-2.8
   refactor: not "fewer/smaller skills" mechanically, but "each skill a deep module that
   visibly embodies a first-principle."

5. **A substrate-neutral arch-evaluation rubric, three layers (this is keystone's general
   evaluation frame, not touchstone housekeeping).** keystone is a substrate-neutral skill
   (ADR-0019), so its evaluation instrument must be domain-agnostic — NOT filtered to what
   fits touchstone's own markdown substrate. The operational rubric lives in
   `skills/keystone/references/arch-rubric.md`; its structure:

   - **L1 — invariant (neutral):** minimize expected complexity (= change-cost + cognitive
     load; Ousterhout). Mentions no code/class/substrate. The root target; too abstract to
     score against directly.
   - **L2 — forces (neutral; the rubric's axes, stated as forces, NOT as named principles):**
     (a) *interface economy / information-hiding* — minimize what a consumer must know to use
     or change a unit; (b) *cohesion* — a unit serves one reason-to-change; (c) *coupling* —
     minimize and keep acyclic what must change together; (d) *speculative cost / YAGNI* —
     don't pay complexity for improbable futures.
   - **L3 — named canon, substrate-PLUGGABLE adapter (NOT neutral; selected by the artifact's
     substrate):** OOP → SOLID (ISP, DIP, LSP, OCP); component → CCP / ADP / CRP / SDP;
     distributed → CAP / failure-domain / idempotency; DB schema → normalization; doc /
     prompt-skill → deep-skill / locality (CCP) / cohesion. keystone names the L2 forces +
     invokes the L3 canon appropriate to the artifact's substrate; if it cannot (engine
     can't assess the substrate), it notes the gap (consistent with ADR-0019's honest
     engine-limit). SOLID etc. are NOT "rejected/stale" — they are the OOP adapter, simply
     not active when the substrate is markdown skills.

   **Derivation discipline (pt 4 at the rubric layer):** every L3 entry must either
   be external canon (cited) or trace to an L2 force; coined terms are L3 applications, never
   new L2 axes. Worked example — `deep-module` is L3 (Ousterhout's named principle), derived
   from the L2 force *interface economy*; touchstone's own `locality-first` = CCP + that force
   on doc-placement; `deep-module-over-merge` = the same force on the merge question. Three
   touchstone decisions (arch-review 179→79 slim, locality-first, no-composite-merge) all
   trace to the SINGLE L2 force *interface economy* — the rubric working as intended (few
   forces, many decisions tracing back). The rubric is a **judgment calibration** (score to
   inform the human bet + the critique engine), NOT a mandatory gate-checklist (keystone is
   judgment-comparator; ADR-0018).

## Consequences

- The Phase-2.8 refactor refocuses from "ABC incl. merge" to: **A** (each skill a deep module
  within the quality bar, subject to pt 3's human-oracle + 0016's provably-omittable
  constraint) + **B** (CONTEXT.md → glossary; pull single-consumer doctrine into its skill,
  rationale → ADR) + **locality-first doctrine** (pt 1). The **C/merge** track is largely
  dropped (pt 2) — kept only for any genuine same-substance artificial split found per-pair.
- A concept currently in CONTEXT.md with a single consumer (e.g. the arch invariant, consumed
  only by keystone) is a candidate to fold INTO that skill, deleting the CONTEXT section.
- Pruning still requires the human oracle (pt 3) — no "looks cleaner" cut without a reviewer
  confirming the skill still steers.

## Amendment (2026-07-20)

**Pt 2's composite-pair application superseded by ADR-0041** (P3 Batch 2 merge, miles-accepted
spec 2026-07-19): the pair's measured shared substance later crossed 0016 pt 4's own
flip-trigger, so the two Pattern-A composites ARE now merged (one composite, internal role
二值). The **general deep-module-over-merge rule in pt 2 stands** — only the pair ruling
flipped, by its own trigger.

## Amendment (2026-06-24)

**Reframing pt 1 as the no-single-host principle.**

The pt 1 decision text above names `≥2 real consumers` as *the* rule (the "consumer-count
test"). That framing inverts the direction of causation. The governing rule is:

> **No-single-host principle:** a fragment lives in a shared home ⟺ no single skill can
> be its authoritative owner — i.e., the fragment expresses genuinely cross-cutting
> doctrine that ≥2 skills depend on as ONE fact, where divergence would be a bug.

`≥2` is the **derived floor** — a cheap mechanical guard that falls out of the principle
(1 consumer ⇒ that consumer IS the authoritative host ⇒ never shared), NOT the rule
itself. Elevating the count to the primary rule produces a mis-applied rule-of-three:
setting the bar at 3+ (as ADR-0017's `skills/_shared/` line did) or leaving it at 2
both mislead, because the count is a necessary-but-not-sufficient condition. The
sufficient condition is **no-single-host**: the fragment would be wrong (divergent
if locally forked) under any hosting arrangement other than shared.

**Practical consequence:** when evaluating whether to extract a fragment, ask first
"is there a single skill that should own this?" — if yes, locality wins regardless of
consumer count. Ask "would forking this fragment create a bug?" — if yes, extract.
`≥2` surfaces the candidates; no-single-host makes the call.
