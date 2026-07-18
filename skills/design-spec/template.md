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

> Six sections: Foundation / Source-level Deposit (conditional) / User Stories /
> Acceptance Criteria / Risks-Open Questions / Related. All normative content is
> homed in the REQ/AC layer — there is no Problem / Scope / Architecture /
> Interfaces / Error Handling / Invariants / Verification Strategy section. In a
> project without the source-as-truth discipline, Source-level Deposit is absent
> and the five-section spec is compliant.

## Foundation

> All three fields, self-contained — interpretable without reading the parent epic.
> Foundation.aim is a provisional direction set at the Foundation-elicitation phase; the acceptance criteria below sharpen it into a testable form, confirmed with the user during drafting — never silently inherited. The former Problem section merges here (state the pain without jumping to a solution); implementation-level touched-files detail belongs in a plan, not the spec.

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

## User Stories

> One entry per user-story. Authoring rules + the traces-to discipline: `references/draft-workflow.md § Want-layer authoring`.

- US-1 — As a/an <actor>, I want <capability>, so that <outcome>

## Acceptance Criteria

Given/When/Then scenarios — the **outer ATDD loop's contract**. Cover happy path, error paths, boundary values; every error path and boundary named here maps to ≥1 acceptance scenario.

- **Live-bearing AC IDs:** <AC-N, AC-M | none>   ← these may NOT be carried as `[unverified]`. This line (+ the Index Live-bearing column) is the normative home of the live-bearing declaration; classification predicate + live-artifact evidence rules: `skills/_shared/inject/live-bearing-predicate.md` (single home — do not restate here).
- **Risk layers this feature needs:** <unit? integration? contract? e2e? live? perf?; power-on-able? live means required?> — one coarse, risk-scaled line, not per-AC.

AC-N id + index rules, derived coverage, and the `[unverified]` marker: `references/draft-workflow.md` § "When drafting ## Acceptance Criteria" (single home). The verification layer/mechanism never appears in an AC's Name or Given-When-Then.

Each `### Requirement: REQ-N — <EARS SHALL statement>` heading adds rule-altitude precision over its parent story (a requirement that merely rewords its story fails the anti-redundancy tests in `references/methodology.md`). An unresolved `[NEEDS CLARIFICATION: <q>]` marker on any requirement or AC line blocks the design-review gate. The normative content the former standalone sections carried relocates INTO requirements:

- **Error paths** → error-path ACs under the owning REQ (one per specific failure mode; each feeds a unit test).
- **Invariants** (cross-cutting correctness rules) → EARS unwanted-behavior REQs ("the <system> SHALL NOT <forbidden behavior>"); every such REQ names its provenance (governing ADR / requirement / carried finding) via a traces-to ADR-ref or carried-finding-ref.
- **Interfaces / contracts** (signatures, schemas, message formats) → a fenced block under the owning REQ; a shared schema is homed under ONE REQ and pointed to from the others.
- **Depth-stakes structural commitments** → a `depth-stakes:` marker line directly under the REQ heading, plus a SHALL commitment in the REQ. A component has **depth-stakes** — and REQUIRES the marker + SHALL — if it hides a non-trivial implementation decision, holds or mutates state, or sequences operations a caller could mis-order (e.g. "Module M SHALL hide X; it SHALL NOT leak its orchestration sequence to callers"). Grade against `skills/assay/references/arch-rubric.md` (load it; do not restate the force text). A purely additive component needs no marker. A Mermaid diagram for a non-trivial flow is optional, non-normative, and outside the digest.

### Index

| Req | AC | Name | Live-bearing |
|---|---|---|---|
| REQ-1 | AC-1 | <short-name> | | <!-- local-ref-ok -->

---

### Requirement: REQ-1 — the <system> SHALL <response> [EARS template — replace this text]

traces-to: US-1
depth-stakes: <one line — ONLY when this REQ carries a structural commitment; omit the line entirely for additive REQs>

#### AC-1 — <full-name>

```
Given <context>
When <action>
Then <observable outcome>
```

## Risks / Open Questions

Unknowns that need resolution before or during build — name them so the plan step can sequence around them.

## Related

- Exploration notes, prior specs, ADRs, external references
