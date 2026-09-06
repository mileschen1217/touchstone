---
template: integration-gate
template_version: "1.0"
scope: "{{SCOPE_NAME}}"
rendered: "{{RENDERED_TS}}"
---

# Integration gate — {{SCOPE_NAME}}

<!-- Always instantiated, even for a module with zero cross-unit residuals
     (DS-10): an empty section says `none` explicitly — absence and emptiness
     are different states. Machine consumers: scripts/reconcile.py leg 4
     (mutation-list completeness), scripts/report.py (per-AC mutation cost). -->

_Requirements: {{AC_LIST}}

## Cross-unit invariant checks
<!-- Residual ACs (residual:true) and invariants no single unit can carry. -->
{{INVARIANT_CHECKS}}

## Bridge removal
<!-- Every seam-convention bridge (per idiom-registry entry cited by the
     units) is removed or replaced by the real delivery, then the full suite
     re-runs. -->
{{BRIDGES}}

## Per-AC mutation
<!-- One line per expanded AC — ALL of them, no narrowing to load-bearing-only
     (AC-11); records with no_expansion_needed:true are exempt (nothing to
     mutate). Mutant ids mut:<ac_id>:<n> map 1:1 to that record's
     violating_behaviors; each mutant's dispatch appends a ledger row. -->
{{MUTATION_LIST}}

## Residual units
<!-- Units whose top tier failed: verdict FAIL rows routed here for human
     ruling (DS-2). -->
{{RESIDUAL_UNITS}}

## Report
{{REPORT_SEED}}
