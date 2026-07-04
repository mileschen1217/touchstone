---
name: design-spec
kind: workflow
description: |
  Generate a design spec for a non-trivial feature. Produces a structured spec
  document at the project's configured specs directory. Invoke when the change
  is cross-cutting or risky enough that the spec's cost is repaid by catching
  scope/AC errors before build; skip when it is contained enough that the contract
  costs more than it saves. Heuristic: the change spans multiple modules, or
  introduces a new contract (API / CLI / IPC / skill). On first invocation in a project, runs
  setup to record the specs directory.
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

Produce an ATDD + TDD double-loop-aligned design spec for a feature and write
the Draft to the project's specs directory. design-spec emits only Draft;
crucible writes accepted-candidate, runs the consolidated design-review gate,
then human accept promotes to accepted.

## When to Invoke

Author a design spec when the change is cross-cutting or risky enough that the
contract's cost is repaid by catching scope/AC errors before build. Skip when
it is contained enough that the contract costs more than it saves.

Derived heuristic: the change spans multiple modules, or introduces a new contract
(public API, CLI command, IPC message format, Claude Code skill, or agent).

The user may always explicitly request a design spec — that overrides the heuristic.

When the expected-value test says skip (contained change, no new contract),
NO Verification Strategy section is authored. The evidence-honesty contract
attaches to full specs only.

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
with parent-epic inheritance + a reframe exit. Note: a FRESH invocation whose
parent epic already has a populated `## Foundation` takes branch a
(inheritance), NOT a reuse hit — the gate's reuse check applies only within the
same invocation.

**Want-layer (always-on).** This spec IS the canonical want-home — author the want-layer here, always, with no separate PRD section, in three existing sections:
- `## Foundation` Intention carries the why.
- `## User Stories` carries US-N entries.
- `## Foundation` out-of-scope carries the boundary.

Want vocabulary, conventions (As-a/so-that template, Spec-Kit WHAT/WHY-not-HOW, INVEST), and terminology live in `CONTEXT.md § Requirement-layer vocabulary` — point there, do not restate. Detailed authoring guidance: `references/draft-workflow.md § Want-layer authoring`.

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

## Status Lifecycle (intentionally minimal)

Specs are written as `Status: Draft`. Crucible then writes `accepted-candidate`
before the consolidated `/touchstone:design-review` gate runs. Transition to
`accepted` is the human-governed terminal accept after a clean design-review.
The skill does not manage lifecycle beyond producing the Draft.

## Related

- Bundled template: `${CLAUDE_PLUGIN_ROOT}/skills/design-spec/template.md`.
- design-review gate (downstream, consolidated): `/touchstone:design-review` — runs after crucible writes `accepted-candidate`.
- Workflow chain, other upstream/downstream skills, ADR workflow, example spec: `README.md`.
