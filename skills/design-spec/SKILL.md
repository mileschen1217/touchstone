---
name: design-spec
kind: workflow
description: |
  Generate a design spec for a non-trivial feature. Produces a structured spec
  document at the project's configured specs directory. Invoke when the change
  is cross-cutting or risky enough that the spec's cost is repaid by catching
  scope/AC errors before build; skip when it is contained enough that the contract
  costs more than it saves. Heuristic: the change introduces a new contract
  (API / CLI / IPC / skill / agent) or its design decisions are expensive to get wrong
  across modules. On first invocation in a project, runs setup to record the specs directory.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Skill
---

# touchstone:design-spec

Produce an ATDD + TDD double-loop-aligned design spec for a feature and write the Draft to the project's specs directory. design-spec emits only Draft — promotion is downstream (see Output).

**Draft Mode may need a live responsive user** — standalone, Foundation elicitation prompts the human; inside crucible it consumes the assay record's consensus section, so no prompt fires.

## When to Invoke

The invoke/skip heuristic lives in the frontmatter description. Rulings it does not settle:

- Breadth alone does not qualify — a mechanical multi-module sweep with fixed invariants takes the PRD+seams light contract (crucible's other fork), not a full spec.
- The user may always explicitly request a design spec — that overrides the heuristic.
- When the expected-value test says skip (contained change, no new contract), NO Verification Strategy section is authored — the evidence-honesty contract attaches to full specs only.

## Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, also read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` and load the
text into context.

## Draft Mode

### Foundation elicitation (Baseline — always runs)

Before collecting design inputs or reading implementation source files,
locate and read the parent epic index if one is in context, then run the
elicitation gate per
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/foundation-gate.md` — read it and
follow it exactly (reuse check, from-scratch opener, sharpening, synthesise,
confirm; all canonical emit strings live there). design-spec wraps that gate
with an assay consume-or-elicit branch, parent-epic inheritance + a reframe
exit. Note: a FRESH invocation whose parent epic already has a populated
`## Foundation` takes branch a (inheritance), NOT a reuse hit — the gate's
reuse check applies only within the same invocation.

**Consume-or-elicit (checked FIRST, before branches a/b):** when an assay
record exists for this subject (the crucible chain hands it over; standalone,
look for `<epics-dir>/<slug>/assay-*-<subject>.md`), consume the record's
`## Consensus` section as the confirmed foundation — intention ← the record's
`subject:` frontmatter line; aim ← the Consensus Scope subsection, condensed
to the observable outcome; out-of-scope ← the Consensus Out-of-scope
subsection — and record it per step g. The Consensus Invariants and Contract
facts subsections are contract-body content: pour them into this spec's
Invariants / Scope sections carrying each row's `[trace: ...]` tag. The AC /
acceptance-seam layer is authored HERE, by design-spec — the record hands
over confirmed facts, never pre-drafted seams. **Never-silent rule:** a
load-bearing fact needed at spec time that is absent from the Consensus
section, contradicts a confirmed Consensus row, or rests on an entry whose
trace tag is missing or unparseable enters the spec ONLY as a question to
the human or a `[NEEDS CLARIFICATION]` marker — never as an untraced
Scope/Invariants entry, never as a silent overwrite of a row the human
confirmed. Terms do not propagate: every term this spec uses carries its own
self-contained definition (the record keeps session-coined terms' source of
truth). Do NOT run the shared gate: assay is the chain's single
human-elicitation surface, and its readiness ruling already carries the
human's confirm. No assay record → elicit via branches a/b below.

**Want-layer (always-on).** This spec IS the canonical want-home — author the want-layer here, always, with no separate PRD section. Section mapping + authoring conventions: `references/draft-workflow.md § Want-layer authoring` (single home); vocabulary: `CONTEXT.md § Requirement-layer vocabulary` — point there, do not restate.

**feedforward ground-and-sweep arm.** Before generating Acceptance Criteria, load the shared doctrine:
> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/ground-and-sweep.md`

feedforward application delta (AC generation): `requirement × current-repo-state` — ground each AC in concrete repo facts (file path, line number, value); sweep the AC's true subject set to saturation, not first-hit. When **generating** acceptance criteria, each generated AC is the unit; saturation = every subject element has ≥1 AC.

a. **Inherit** — if the parent epic index has a populated `## Foundation`:
   pre-fill from it, restate the epic's intention / aim / out-of-scope, then
   ask with this EXACT phrase verbatim (fixed emit string — do not paraphrase,
   do not substitute your own questions):
   "Does this spec's scope differ? If so, sharpen each field for this phase."
   Do NOT run the shared gate's from-scratch opener.

b. **No inheritable `## Foundation`** — run the shared gate from its
   from-scratch opener. Two sub-cases:
   - b1. No parent epic at all: run the gate; do NOT emit the legacy note.
   - b2. Parent epic uses the legacy `## Intention` format (not `## Foundation`):
     FIRST emit this EXACT note: "Parent epic uses legacy Intention format —
     consider updating it.", THEN run the gate. (The legacy note fires in b2
     ONLY; it must be absent in b1.)

f. **Reframe exit** — if the user reframes during sharpening (e.g. "this
   should be a fixture, not a spec"), STOP. Do not draft a spec and do not
   write any file under specs_dir. Report:
   "Scope reframed to [X] — a design spec is not needed. Exiting Draft Mode."

g. **Record** — write the confirmed foundation into the spec under
   `## Foundation` (all three fields — the spec has no tracker headline).

### Draft inputs & workflow

Inputs to collect + the drafting workflow (template read, AC-sharpening from Foundation.aim, mandatory line-width policy, write steps) → [`references/draft-workflow.md`](references/draft-workflow.md).

### Output

- One file at `<specs_dir>/YYYY-MM-DD-<feature-name>-design.md`
- Terminal summary with: spec path, `Status: Draft`
- Next step: crucible writes `accepted-candidate`, then `/touchstone:design-review` runs the consolidated gate before human accept

## Usage

```
/touchstone:design-spec                          # interactive draft
/touchstone:design-spec <feature-name>           # skip name prompt
```

## Related

- Bundled template: `${CLAUDE_PLUGIN_ROOT}/skills/design-spec/template.md`.
- Workflow chain, upstream/downstream skills, ADR workflow, example spec: `README.md`.
