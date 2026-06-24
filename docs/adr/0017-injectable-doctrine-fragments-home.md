---
kind: workflow
adr_id: 0017
status: Accepted
date: 2026-06-21
---

# ADR-0017: Injectable doctrine fragments live in `skills/_shared/inject/`, not in CONTEXT.md sections

## Status

Accepted.

## Context

Four doctrine fragments are injected verbatim into cold-dispatched reviewers and
architects that cannot read CONTEXT.md directly:

- **Bridge content gate — three principles** — the P1/P2/P3 rule for bridge content;
  injected by `design-spec`, `arch-review (now keystone)`, and `design-review`.
- **Standing vs transient bridge** — the scope-span axis (standing architecture docs vs
  transient specs); injected by `arch-review (now keystone)` and `design-review`.
- **live-bearing predicate** — the operational classification of ACs that require a live
  artifact; injected by `design-review` and `code-review` (its `batch` path).
- **AC-coverage-honesty principle** — the `claim ≤ evidence` spine rule for ACs; injected
  by `design-review` and `code-review` (its `batch` path).

These fragments previously lived as full-body sections inside CONTEXT.md, with skills
told to "Read CONTEXT.md § X and inject verbatim into the reviewer envelope." That
coupling had three problems:

1. **Inject sources were implicit.** Nothing in CONTEXT.md declared which sections were
   consumed by cold agents vs warm orchestrators. A reader could not tell from the file
   itself which sections were load-and-inject targets.
2. **Blast radius was invisible.** Editing a section gave no indication of which cold
   agents would receive different text. Frontmatter for inject consumers did not exist.
3. **CONTEXT.md grew monotonically.** Every new injected doctrine expanded the file.
   The file's scope drifted from "vocabulary the warm orchestrator reads" toward
   "a bundle of cold-agent payloads."

## Decision

Each injected fragment is its own file under `skills/_shared/inject/`, carrying:

- `injected-by: [skills]` — the skills that load-and-inject this file verbatim into a
  cold reviewer/architect envelope.
- `referenced-by: [skills]` — warm-orchestrator skills that cite this file as a
  definitional pointer (but do not inject it cold).

CONTEXT.md keeps a one-line glossary definition + a pointer to the fragment path for
each entry. The fragment file is the **single home** of the full rule text. Skills that
previously read `CONTEXT.md § "X"` now read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/<file>.md` directly.

`skills/_shared/inject/` is a **distinct category** from the generic `skills/_shared/`
shared instruction blocks:

- `skills/_shared/` — procedure or instruction blocks referenced by 3+ warm skills
  (e.g. `step0-resolver.md`, `foundation-gate.md`). Consumed by the warm orchestrator
  that runs the skill. (superseded by ADR-0020 pt1 amendment 2026-06-24: the rule is
  no-single-host; ≥2 is the derived floor — `3+` was a mis-applied rule-of-three.)
- `skills/_shared/inject/` — doctrine fragments consumed verbatim by COLD agents
  (reviewers, architects) that have no CONTEXT.md access. A fragment is a complete,
  self-contained unit; a warm skill loads it and forwards it in the agent envelope.

## Consequences

**Positive:**

- Inject sources are explicit and individually version-controlled. The `injected-by:`
  frontmatter makes blast radius visible — editing a fragment immediately shows which
  skills deliver different text to cold reviewers.
- CONTEXT.md stops growing as doctrine accretes. New injected doctrine gets its own
  fragment file, not a new section in the vocabulary file.
- Cold-reviewer self-containment is preserved. A fragment is a complete unit; a cold
  agent receives the full predicate/rule, not a pointer it cannot follow.
- `referenced-by:` frontmatter makes warm-orchestrator citation visible in the fragment
  itself, so a reader of the fragment knows which skills cite it without grepping.

**Negative / mitigations:**

- One more directory convention to learn. Mitigated by the `## Template co-location`
  section in CONTEXT.md, which now documents `skills/_shared/inject/` explicitly.
- A fragment's one-line glossary definition in CONTEXT.md and its full text in the
  fragment can drift. Mitigated by keeping CONTEXT.md to a strict 1-line def + pointer
  (no second copy of the rule text). The fragment is authoritative; the CONTEXT.md entry
  is only a navigation aid.

This ADR reverses the earlier implicit assumption — established when source-as-truth
shipped — that CONTEXT.md sections ARE the inject home. That assumption was never
explicit; this ADR makes the new home explicit.

## Addendum (2026-06-24, dual-use carve-out — `ground-and-sweep.md`)

Cold-ONLY doctrine fragments default to `skills/_shared/inject/`. A **warm-read +
cold-injected dual-use fragment** — one that is read warm by an orchestrator skill AND
injected verbatim into a cold reviewer, with both consumers declared in `referenced-by:`
+ `injected-by:` frontmatter — may live in `skills/_shared/` and be injected from
there. It is not required to relocate to `skills/_shared/inject/`. `ground-and-sweep.md`
is the first instance of this carve-out; its dual `referenced-by: [design-spec]` +
`injected-by: [design-review]` frontmatter makes both consumers visible.

## Related ADRs

- ADR-0016 (skill-suite structure convention) — establishes `skills/_shared/` as the
  home for cross-skill instruction blocks shared by 3+ skills; this ADR adds
  `skills/_shared/inject/` as a sub-home for the distinct cold-agent inject category.
- ADR-0011 (honesty spine as Constitution) — the `claim ≤ evidence` principle carried
  by `ac-coverage-honesty-principle.md` and the live-bearing predicate is grounded in
  the honesty spine.
