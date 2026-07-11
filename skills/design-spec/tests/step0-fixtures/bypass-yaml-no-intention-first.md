# Fixture: bypass-yaml-no-intention-first — AC-1 (routing-branches-removed: no yaml-based skip) + AC-2 (standalone-degenerate-form)
# Harness contract: skills/<skill>/tests/step0-fixtures/ two-layer schema
# Spec authority: 2026-07-11-design-spec-deep-module.md § AC-1, AC-2
#
# .claude/touchstone.yaml is present but adopted_disciplines is empty
# (intention-first not listed); must NOT skip Foundation & facts intake.
# No facts source is supplied, so intake takes the standalone degenerate
# form: the fixed steering line, then pointwise elicitation. This fixture
# proves intake is REACHED regardless of adopted_disciplines.

```yaml
invocation: { skill: design-spec, args: "" }
setup:
  design_spec_yaml: present   # DRAFT MODE precondition (NOT Setup Mode) —
                              # MUST be pinned: this fixture stresses
                              # touchstone.yaml's empty adopted_disciplines,
                              # and without pinning design-spec.yaml present
                              # the agent may mis-route to Setup Mode
                              # (observed 3/5 in pass@5 when unpinned).
  yaml: { state: present, adopted_disciplines: [] }   # touchstone.yaml

# ── Layer 1 (deterministic) ──────────────────────────────────────────────
required-phrases:
  - "This subject has no qualified confirmed-facts source — the designed path is the crucible chain (assay interview); continuing standalone, I will elicit each missing fact pointwise."   # full exact steering line (intake reached)

forbidden-substrings:
  # Setup-Mode mis-route guard: the specs-dir question must NOT appear
  # (design-spec.yaml is present → Draft Mode, not Setup Mode):
  - "Where should design specs live"
  # harness-wide premature-hand-off guard (this fixture is NOT aim-handoff):
  - "Sharpened the Foundation aim into testable acceptance criteria — confirm or edit."
forbidden-mode: literal
```
