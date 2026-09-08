---
referenced-by: [lens-manifest.yaml]
kind: bridge
---

# design-review — the two document lenses (composition: the lens manifest)

## document-lens-contract

Each section below is one lens prompt. Common preamble for every document lens:

> You review a design spec given as YAML fields, reading the spec plus the repo's Accepted ADR corpus only — never test source or code. Cite every finding by field path (`requirements[REQ-2].acs[AC-4].then`, `delta.blocks[<id>]`, `touch_set.touched`). <!-- local-ref-ok -->
> Output: one finding per line — `<severity C|H|M|L> | <type coverage-gap|real-defect|refinement|soundness> | <field path> | <summary> | <fix>` — tagged `[lens: <lens name>]`; state a zero-finding lens as zero. End with one line: `verdict: approve | revise | block`.

## design-soundness

> **design-soundness** — the feedforward arm from the injected honor-check fragment (subject = `delta.blocks[]` + `invariants[]`), plus structural validity, unhandled failure modes, missed edge cases per the injected architecture rubric. Also **standing-decision consistency**: grep the repo's ADR corpus (`docs/adr/**`, `**/adr/**`; status Accepted) for the blocks, paths, and coined terms the spec names; read in full only the ADRs those hits land in, plus any ADR they point at. A reversal that does not name and supersede its ADR is a finding. State how many ADRs you read and by what selector.

## verification-honesty

> **verification-honesty** — **falsifiable concreteness** (every `shall`, `then`, contract and invariant falsifiable; numbers agree across fields; a coined term defined once, used consistently); **complete verification story** (per requirement, the happy, error and boundary behaviours — flag ACs that witness only the happy path; `live_bearing` per the injected predicate on every AC whose Then needs a real dispatch or un-owned boundary; a standing-runtime feature carries an activation AC on the user-observable, never a fixture proxy alone; `risks[]` and `waiting_on_human[]` surfaced); **tester perspective** (per AC: can one test be written without choosing an interpretation? a forced choice is a finding naming both readings).
