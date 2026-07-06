# ADR Authoring

Referenced by `/touchstone:assay` (structural-fork case) and `/touchstone:design-spec`. Not a standalone skill. The template is `docs/adr/template.md` (single home — do not restate its format here; copy it into the project on first use).

## When to create an ADR

A decision has been made (not "considering"), alternatives were weighed, and
the decision affects future work. Skip ADRs for:
- Forced choices (only one viable option)
- Local-scope decisions that won't affect future work
- Patterns already captured in a prior ADR (reference the prior instead)

## Procedure

When `/touchstone:assay` or `/touchstone:design-spec` concludes with a decision worth
recording:

0. **Local-first draft routing (check first):** when the project routes
   in-flight ADRs to a local draft dir (e.g. a `CLAUDE.local.md` Doc-Routing
   row such as `.touchstone/docs/adr/`), author the draft THERE — the public
   ledger is a promote-at-ship decision, not a draft-time one (re-check the
   number against the public `docs/adr/` when promoting).

1. Otherwise author directly into the public ledger:
   - Initialize `docs/adr/` on first use (with user consent), copying
     `docs/adr/template.md` from this plugin's repo if the project lacks one.
   - Assign the next number by scanning `docs/adr/` for the highest `NNNN-` prefix.
   - Fill the template (Nygard format — Context, Decision, Alternatives
     Considered, Consequences) and write `docs/adr/NNNN-<title-slug>.md`.
   - If the project keeps an ADR index (a `docs/adr/README.md`, or an authority
     table in `CONTEXT.md`), append the new entry there.

2. Fill the convention header fields the template carries: `Triggered by:`
   (which skill/spec produced this) and `Related ADRs:` (grep `docs/adr/` for
   related topics). When the ADR records a structural-fork bet (assay's
   readiness-fork case), also fill `Flip-trigger:`, `Bet-owner:`, and
   `Assumptions:` (uncomment the template block).

3. Back-link:
   - `/touchstone:design-spec` → add the new ADR to the spec's `Related` section
   - `/touchstone:assay` → the assay record's flip-trigger registry references the ADR
