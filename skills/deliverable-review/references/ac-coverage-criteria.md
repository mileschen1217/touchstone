---
referenced-by: [lens-manifest.yaml]
kind: bridge
---

# AC-coverage criteria (single home — gates that read test source)

The evidence-honesty coverage core, injected where test source exists. A
consumer loads this and carries only its own site delta.

## AC-coverage evidence rules

- Read the governing spec's ACs and the test source. For each AC, judge whether a test
  asserts that AC's Then-clause (AC coverage, semantic — not code-coverage %, not
  tool-measured).
- A test that mocks the very boundary a boundary-crossing AC claims does NOT discharge
  that claim (proxy, not coverage).
- A **vacuous test** does not discharge: an assertion that cannot fail (asserts a
  constant, its own mock, or nothing), or one that pins incidental implementation
  behaviour rather than the AC's Then. The judging question: would this test go red
  if the Then behaviour broke? No → the AC is uncovered.
- An AC claimed done with no test asserting its Then-clause and no `[unverified]` blocks
  the done claim (the silent false-green the sibling principle defines).

## Conformance output format

Conformance output, one line per AC and per invariant: `<AC-n|INV-n> | covered <test/artifact ref> | unverified <reason or proxy> | violated <finding>` — the covered lines become `coverage[]` rows at merge, only unverified / violated lines become findings.

## Live-bearing evidence delta

An AC with `live_bearing: true` is judged by the predicate's evidence rules; what they disqualify is recorded `unverified` naming the proxy, and the arm authenticates the artifact, never re-runs the producer.
