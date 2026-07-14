# Fixture: bypass-yaml-absent — routing-branches-removed (no yaml-based skip) + standalone-degenerate-form
# Harness contract: skills/<skill>/tests/step0-fixtures/ two-layer schema
#
# .claude/touchstone.yaml is absent; must NOT skip Foundation & facts intake.
# No facts source is supplied, so intake takes the standalone degenerate
# form: the fixed steering line, then pointwise elicitation. This fixture
# proves intake is REACHED regardless of yaml state.

```yaml
invocation: { skill: design-spec, args: "" }
setup:
  yaml:
    state: absent

# ── Layer 1 (deterministic) ──────────────────────────────────────────────
required-phrases:
  - "This subject has no qualified confirmed-facts source — the designed path is the crucible chain (assay interview); continuing standalone, I will elicit each missing fact pointwise."   # full exact steering line (intake reached)

# harness-wide guard (implicit per spec § Interfaces "Harness-wide
# premature-hand-off invariant"): this fixture is NOT aim-handoff.
forbidden-substrings:
  - "Sharpened the Foundation aim into testable acceptance criteria — confirm or edit."
forbidden-mode: literal
```
