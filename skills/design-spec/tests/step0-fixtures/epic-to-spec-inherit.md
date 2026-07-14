# Fixture: epic-to-spec-inherit — citation-granularity-two-level (field-level consume)
# Harness contract: skills/<skill>/tests/step0-fixtures/ two-layer schema
#
# Parent epic `## Foundation` is a qualified confirmed-facts source at
# field-level granularity: it feeds Foundation fields with a section-level
# citation. No re-elicitation prompt fires and the retired branch-a
# question ("Does this spec's scope differ?") is gone.

```yaml
invocation: { skill: design-spec, args: "" }
setup:
  parent_epic: { foundation: present }

# ── Layer 1 (deterministic) ──────────────────────────────────────────────
forbidden-substrings:
  - "Does this spec's scope differ?"                          # retired branch-a prompt
  - "This subject has no qualified confirmed-facts source"    # standalone path must NOT fire — a qualified source is supplied
  - "describe the intended work in your own words"            # from-scratch opener must NOT fire
  # harness-wide guard (implicit per spec § Interfaces "Harness-wide
  # premature-hand-off invariant"): this fixture is NOT aim-handoff.
  - "Sharpened the Foundation aim into testable acceptance criteria — confirm or edit."
forbidden-mode: literal

expected-foundation:                 # field-level citation: Foundation fields
  intention: "<fixture-fixed phase intention>"   # populated straight from the
  aim: "<fixture-fixed phase aim>"               # epic's ## Foundation section
  out-of-scope: ["<fixture-fixed route>"]        # (section-level citation), no re-elicitation prompt
```
