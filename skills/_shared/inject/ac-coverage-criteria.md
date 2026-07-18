---
injected-by: [code-review, epic-driven-roadmap]
kind: bridge
---

# AC-coverage criteria (single home — gates that read test source)

The evidence-honesty coverage core, injected at the gates where test source exists
(`code-review batch`, epic-close). A sibling of `ac-coverage-honesty-principle.md` —
NOT that fragment — because this core names an act (reading test source) that the
design-review gate must not perform. A consumer loads this and carries only its own
site delta.

- Read the governing spec's ACs and the test source. For each AC, judge whether a test
  asserts that AC's Then-clause (AC coverage, semantic — not code-coverage %, not
  tool-measured).
- A test that mocks the very boundary a boundary-crossing AC claims does NOT discharge
  that claim (proxy, not coverage).
- An AC claimed done with no test asserting its Then-clause and no `[unverified]` is a
  **silent false-green** — it blocks the done claim.
