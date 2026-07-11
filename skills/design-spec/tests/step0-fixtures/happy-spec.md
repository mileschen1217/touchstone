# Fixture: happy-spec — AC-2 (standalone-degenerate-form, elicitation happy path)
# Harness contract: skills/<skill>/tests/step0-fixtures/ two-layer schema
# Spec authority: 2026-07-11-design-spec-deep-module.md § AC-2
#
# No parent epic, no facts source: intake takes the standalone degenerate
# form (one steering line, then pointwise elicitation, no multi-round
# mini-interview).

```yaml
invocation: { skill: design-spec, args: "" }

# ── Layer 1 ──────────────────────────────────────────────────────────────
required-phrases:
  - "This subject has no qualified confirmed-facts source — the designed path is the crucible chain (assay interview); continuing standalone, I will elicit each missing fact pointwise."   # full exact steering line (AC-2)

forbidden-substrings:
  # harness-wide guard (implicit per spec § Interfaces "Harness-wide
  # premature-hand-off invariant"): this fixture is NOT aim-handoff.
  - "Sharpened the Foundation aim into testable acceptance criteria — confirm or edit."
forbidden-mode: literal

expected-foundation:
  intention: "<fixture-fixed>"
  aim: "<fixture-fixed>"
  out-of-scope: ["<fixture-fixed route>"]

# No within-document Foundation/Scope duplication — pre-existing behavior,
# untouched by this refactor (not itself a P2 AC; kept as a live witness).
expected-artifacts:
  specs_dir_delta: 1
  files:
    - path: "*.md"                 # the produced spec under $SPECS_DIR
      section: "## Scope"
      # impl-level lines only, fixed verbatim; NON-framing label (no "In scope:")
      exact: |
        **Touched files/modules:**
        - skills/design-spec/template.md
      not-contains: ["In scope:", "Non-goals:"]   # legacy framing labels
    - path: "*.md"
      section: "## Foundation"
      contains: ["**Out of scope:**"]   # boundary routes live ONLY here
      awk-shape: out-of-scope-subbullets # AC-11 awk: 1-3 children, none nested

# ── Layer 2 ──────────────────────────────────────────────────────────────
runs: 5
min-pass: 4
rubric:
  - "Before synthesising, did the agent ask ≥1 clarifying question?
     (Y=pass | N=fail)"
  - "Did the agent present the draft for confirmation before writing it?
     (Y=pass | N=fail)"
```
