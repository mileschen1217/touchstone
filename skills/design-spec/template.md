---
type: spec
kind: bridge
date: YYYY-MM-DD
status: draft
epics: []
related: []
kill-on: <epic-slug>
---

# {{feature-name}} — Design Spec

## Foundation

> All three fields, self-contained — interpretable without reading the parent epic.
> Foundation.aim is a provisional direction set at the Foundation-elicitation phase; the acceptance criteria below sharpen it into a testable form, confirmed with the user during drafting — never silently inherited.

- **Intention (why):** <what hurts, why this work is worth doing now>
- **Aim:** <observable goal for THIS spec's scope; name the surface that observes success (user message, test pass, grep result, REST response)>
- **Out of scope:**
  - <a route this spec will NOT take, even if related — a route, not a category>
  - <up to three sub-bullets total; flat list, never nested>

## Source-level Deposit

> Skip this entire section (heading included) in projects that have NOT adopted the `source-as-truth` discipline.

- **Lever this spec advances:** `<lever-slug>` from the project's lever menu (see project ROADMAP), or `none` — justified in one sentence.
- **Bridge docs this spec creates (if any):** paths with the `kill-on:` lever each declares; a doc with no `kill-on:` is justified here by kind (navigation / workflow / diagnostic — never bridge).
- **Bridge docs this spec will retire on landing:** paths the lever's land deletes.
- **Three-principle audit (per new bridge doc):** answer P1 non-duplication / P2 falsifiable / P3 no-single-host per the loaded `skills/_shared/inject/bridge-content-gate.md`, naming the source path(s) checked; a missing or weak answer → fix the bridge content (delete duplicates / sharpen vague claims / move to rung 2-3) before submitting the spec.

## Problem

What hurts today? Concrete, scoped, falsifiable — state the pain without jumping to a solution.

## Scope

(Optional) Implementation-level detail only — files, modules, repos. Boundary statements live in Foundation.out-of-scope.

**Touched files/modules:**
- <file or module path>

## User Stories

> One entry per user-story. Authoring rules + the traces-to discipline: `references/draft-workflow.md § Want-layer authoring`.

- US-1 — As a/an <actor>, I want <capability>, so that <outcome>

## Acceptance Criteria

Given/When/Then scenarios — the **outer ATDD loop's contract**. Cover happy path, error paths, boundary values; every error path and boundary named here maps to ≥1 acceptance scenario.

AC-N id + index rules, derived coverage, and the `[unverified]` marker: `references/draft-workflow.md` § "When drafting ## Acceptance Criteria" (single home). The verification layer/mechanism never appears in an AC's Name or Given-When-Then.

Each `### Requirement: REQ-N — <EARS SHALL statement>` heading adds rule-altitude precision over its parent story (a requirement that merely rewords its story fails the anti-redundancy tests in `references/methodology.md`). An unresolved `[NEEDS CLARIFICATION: <q>]` marker on any requirement or AC line blocks the design-review gate.

### Index

| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | <short-name> |

---

### Requirement: REQ-1 — the <system> SHALL <response> [EARS template — replace this text]

traces-to: US-1

#### AC-1 — <full-name>

```
Given <context>
When <action>
Then <observable outcome>
```

## Verification Strategy

> Coarse, risk-scaled — NOT per-AC; ~4–7 lines. Read at design-review and at epic-close.

- **Risk layers this feature needs:** <unit? integration? contract? e2e? live? perf?>
- **Power-on-able?** <can the design be exercised at the needed layer; if not, why / what's needed>
- **Live means required:** <fixture / target / device / none>
- **Live-bearing AC IDs:** <AC-N, AC-M | none>   ← these may NOT be carried as `[unverified]`
  > Classification predicate + live-artifact evidence rules: `skills/_shared/inject/live-bearing-predicate.md` — single home, read it, do not restate here. The deterministic floor only checks a claimed artifact exists and is referenced by its AC; the reviewer authenticates it.

## Architecture

> Grade against `skills/assay/references/arch-rubric.md` (load it; do not restate the force text). A component has **depth-stakes** — and REQUIRES a SHALL-form commitment here — if it hides a non-trivial implementation decision, holds or mutates state, or sequences operations a caller could mis-order (e.g. "Module M SHALL hide X; it SHALL NOT leak its orchestration sequence to callers"). Answer the depth-stakes question for EVERY component: purely additive ones state exactly `no structural commitment — additive within existing module` — a deliberate answer, never a silent skip. Include a Mermaid diagram for non-trivial flows.

## Interfaces / Contracts

Function signatures, API shapes, message formats, config schemas — specific (field names, types, optionality; vagueness leaves the inner loop nothing to assert against). Each contract feeds the inner TDD loop as unit tests covering happy path, ≥1 error path, boundary values, and write-then-readback for mutations.

## Error Handling

One row per specific failure mode; each row maps to a unit test in the inner TDD loop.

| Scenario | Trigger | Behavior |
|---|---|---|
| ... | ... | ... |

## Invariants

Cross-cutting correctness rules that must hold across every code path — they become property tests or assertion sweeps. Every invariant SHALL name its provenance: a governing ADR / inherited standing decision, the requirement(s) that necessitate it, or a carried finding / prior-phase constraint.

Example: "No operation modifies source files if the write phase fails." [source: REQ-3 + ADR-0009]

## Risks / Open Questions

Unknowns that need resolution before or during build — name them so the plan step can sequence around them.

## Related

- Exploration notes, prior specs, ADRs, external references
