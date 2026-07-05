# ADR Authoring (integration with ECC skill)

Referenced by `/touchstone:assay` (structural-fork case) and `/touchstone:design-spec`. Not a standalone skill.

The authoring procedure and template are owned by ECC's
`architecture-decision-records` skill. This file documents how to invoke it
from our skills, plus the extra header fields we want beyond Nygard's
standard format.

## When to create an ADR

A decision has been made (not "considering"), alternatives were weighed, and
the decision affects future work. Skip ADRs for:
- Forced choices (only one viable option)
- Local-scope decisions that won't affect future work
- Patterns already captured in a prior ADR (reference the prior instead)

## Invocation

When `/touchstone:assay` or `/touchstone:design-spec` concludes with a decision worth
recording:

1. Invoke ECC's ADR skill:
   ```
   Skill: everything-claude-code:architecture-decision-records
   ```
   This skill:
   - Initializes `docs/adr/` + `README.md` index on first use (with user consent)
   - Assigns next number by scanning `docs/adr/`
   - Uses Nygard ADR format (Context, Decision, Alternatives Considered,
     Consequences)
   - Writes `docs/adr/NNNN-{title-slug}.md`
   - Appends to `docs/adr/README.md` index

2. After ECC writes the ADR, add two custom header fields we use by convention:

   - **`Triggered by:`** — `/touchstone:assay` or `/touchstone:design-spec (spec filename)`.
     Makes the skill origin visible.
   - **`Related ADRs:`** — comma-separated list of prior ADR numbers this
     builds on (grep the `docs/adr/` directory for related topics).

   Add these as an additional header section between "Deciders" and "Context".

   When the ADR records a structural-fork bet (assay's readiness-fork case), add
   three more fields in the same header section:

   - **`Flip-trigger:`** — the observable signal that reopens the decision, plus
     the revisit point (who/where looks when it fires).
   - **`Bet-owner:`** — the human owning the bet (never the AI).
   - **`Assumptions:`** — the decision bets this ADR rests on (bets, not
     implementation facts).

3. Back-link:
   - `/touchstone:design-spec` → add the new ADR to the spec's `Related` section
   - `/touchstone:assay` → the assay record's flip-trigger registry references the ADR

## Graceful degradation

If ECC is not installed, fall back to manual ADR writing:
- Use the template at `docs/adr/template.md` (created by ECC's skill) or
  `docs/adr/0000-template.md` (existing in `claude_code_config`)
- Apply the Nygard format directly
- Still add `Triggered by:` and `Related ADRs:` headers

## What NOT to duplicate

Do not copy the ADR template, workflow, or detection signals here — they live
in `everything-claude-code:architecture-decision-records`. This file is only
the integration contract for our two skills.
