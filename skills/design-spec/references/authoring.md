---
kind: bridge
kill-on: skill-ceiling
---

# design-spec — authoring reference

Drafting conventions for `spec.yaml`. The field set is the spec schema
(`check-artifact.sh` validates it).

## Want-layer authoring

The spec is the canonical want-home.

- **Why** → the epic index's Foundation (inherited; `foundation: inherit`).
- **US-N entries** → `user_stories[]`: `as` / `want` / `so_that`. Each names one
  actor-facing want, deliberately under-specified for verification.
- **Boundary** → the epic index's out-of-scope list; spec-level exclusions →
  `non_goals[]`.

Every requirement `traces_to` ≥1 US-N. US-N ids are stable for the spec's
lifecycle. A requirement that only rewords its story collapses into it — it
must add a partitionable rule-domain the story lacks.

## When drafting `requirements[].acs`

Treat the inherited aim as a provisional direction, not a settled target.
Derive testable, observable criteria from it; where the Foundation phase set a
placeholder value (a latency, a recall threshold), pressure-test and adjust it
against what the design can actually achieve. Surface the result with this
exact phrase: "Sharpened the Foundation aim into testable acceptance
criteria — confirm or edit," present the sharpened aim/criteria, and wait for
confirmation. If design work reveals the original direction was wrong, that is
a scope signal — surface it, never quietly substitute a new goal.

Assign `AC-N` 1-based at draft; never reuse within a spec. `live_bearing` follows
the live-bearing predicate (design-review's verification-honesty lens — an AC
whose Then depends on a real dispatch or an un-owned boundary is `true`). The spec carries no per-AC
red/green state and no `[unverified]` marker. A question the draft cannot settle is
a `waiting_on_human[]` entry, never a bracketed marker in a field.

**Line width.** Block scalars (`>` / `|`) wrap at the width the neighbouring
fields use.
