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

**Draft Mode may need a live responsive user** — with no qualified facts
source supplied, pointwise elicitation prompts the human; with a supplied
confirmed-facts source, no prompt fires.

## When to Invoke

The invoke/skip heuristic lives in the frontmatter description. Rulings it does not settle:

- Breadth alone does not qualify — a mechanical multi-module sweep with fixed invariants takes the PRD+seams light contract (crucible's other fork), not a full spec.
- The user may always explicitly request a design spec — that overrides the heuristic.
- When the expected-value test says skip (contained change, no new contract), NO Live-bearing declaration is authored (no AC-section intro Live-bearing line, no Index Live-bearing column) — the evidence-honesty contract attaches to full specs only.

## Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, also read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` and load the
text into context.

## Draft Mode

### Foundation & facts intake (always runs)

design-spec's whole intake interface is: **facts sources in → Draft spec
out**. Sources are those the caller or user supplies, or already in
context — never glob or hunt for epic indexes or assay records yourself.

Source qualification, citation granularity, and the validation-failure
trigger classes live in the confirmed-facts source contract — read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/confirmed-facts-source.md`
with the Read tool and follow it exactly. design-spec's own delta on that
contract: a validation failure (any trigger class) is dispositioned by
asking the human in-session or marking `[NEEDS CLARIFICATION]` — a failed
fact never lands as an untraced Scope/Invariants entry.

Per-fact principle (the only disposition — never branch on whether a source
exists or which producer made it): for each fact the spec needs, find its
confirmation evidence in the supplied sources and cite it at the granularity
the confirmed-facts source contract requires for that fact's target section,
each contract-body fact carrying its `[trace: <id>]` — else ask or mark. The AC / acceptance-seam
layer is authored HERE, by design-spec — a source hands over confirmed
facts, never pre-drafted seams. Terms do not propagate: every term this
spec uses carries its own self-contained definition (a session-coined
term's source of truth stays in its source).

Degenerate form — when no qualified source is supplied and Foundation facts
are unresolvable from context, emit ONE steering line: "This subject has
no qualified confirmed-facts source — the designed path is the crucible
chain (assay interview); continuing standalone, I will elicit each missing
fact pointwise." Then elicit each missing fact pointwise (the human's
in-session confirmation is field-level evidence for Foundation fields). No
multi-round mini-interview.

**Reframe exit** — if the user reframes during intake (e.g. "this should be
a fixture, not a spec"), STOP. Do not draft a spec and do not write any
file under specs_dir. Report: "Scope reframed to [X] — a design spec is not
needed. Exiting Draft Mode."

**Record** — write the confirmed foundation into the spec under
`## Foundation` (all three fields — the spec has no tracker headline).

**Want-layer (always-on).** This spec IS the canonical want-home — author the want-layer here, always, with no separate PRD section. Section mapping + authoring conventions: `references/draft-workflow.md § Want-layer authoring` (single home); vocabulary: `CONTEXT.md § Requirement-layer vocabulary` — point there, do not restate.

**REQ-headline discipline.** A `### Requirement:` headline is ONE normative SHALL sentence — write it, then stop (the `traces-to:` line below the heading is a separate line, not part of the sentence).
Every disambiguation or overflow clause lives in its own section (Interfaces / Error Handling / Invariants) — re-home any clause the headline absorbed during review churn.
Delete duplicates: a clause already homed in a downstream section never repeats in the headline.

**feedforward ground-and-sweep arm.** Before generating Acceptance Criteria, load the shared doctrine:
> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/ground-and-sweep.md`

feedforward application delta (AC generation): `requirement × current-repo-state` — ground each AC in concrete repo facts (file path, line number, value); sweep the AC's true subject set to saturation, not first-hit. When **generating** acceptance criteria, each generated AC is the unit; saturation = every subject element has ≥1 AC.

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
