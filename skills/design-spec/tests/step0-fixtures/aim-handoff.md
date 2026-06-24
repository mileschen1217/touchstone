# Fixture: aim-handoff — AC-13 (Provisional aim handed off to AC-authoring for confirmation)
# Harness contract: skills/<skill>/tests/step0-fixtures/ two-layer schema
# Spec authority: intention-first epic § AC-13
#
# SOLE FIXTURE EXEMPT from the harness-wide premature-hand-off guard.
# This fixture intentionally scripts the session THROUGH the Foundation-elicitation phase and INTO
# ## Acceptance Criteria drafting so the hand-off phrase is deterministically
# reachable. All other fixtures forbid the AC-13 phrase; only this one asserts it.
#
# A parent epic foundation is present so the Foundation-elicitation phase takes the inheritance path,
# and the run proceeds past it into AC drafting with Foundation.aim set
# as a direction ("the parser returns in <50ms at p95").

```yaml
invocation: { skill: design-spec, args: "" }
setup: { parent_epic: { foundation: present } }
turns:   # user inputs that drive the run THROUGH the Foundation-elicitation phase and INTO
         # ## Acceptance Criteria drafting, so the Layer-1 hand-off phrase
         # is deterministically reachable — NOT left to chance at the end
         # of the Foundation-elicitation phase. A fixture asserting a phrase emitted later in the
         # drafting workflow MUST script the session to that point.
  - { role: user, text: "Port the stats config to the new schema." }
  - { role: user, text: "Same scope as the epic; aim: parser returns in <50ms at p95." }
  - { role: user, text: "confirmed" }                  # accept Foundation-elicitation foundation
  - { role: user, text: "proceed to the acceptance criteria" }

# ── Layer 1 ──────────────────────────────────────────────────────────────
required-phrases:
  - "Sharpened the Foundation aim into testable acceptance criteria — confirm or edit."
forbidden-mode: literal

# ── Layer 2 (each item single-clause, yes/no, per ADR-0005) ──────────────
runs: 5
min-pass: 4
rubric:
  - "Before finalising the acceptance criteria, did the agent present the
     sharpened/testable aim for the user to confirm or edit (rather than
     silently inheriting the Foundation-elicitation value)? (Y=pass | N=fail)"
  - "Did the agent restate or quote the Foundation-elicitation aim when
     presenting the sharpened criteria? (Y=pass | N=fail)"
  - "Does the sharpened aim address the same observable surface (same
     user / system / test owner) named in the Foundation-elicitation aim, rather than a
     different observable outcome? (Y=pass | N=fail)"
```
