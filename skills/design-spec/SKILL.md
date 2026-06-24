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
  setup to record the specs directory. Always dispatches the `architect` agent
  for fresh-context review of the draft.
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

Produce an ATDD + TDD double-loop-aligned design spec for a feature, review it
in fresh context via the `architect` agent, and write the final draft to the
project's specs directory.

## When to Invoke

Author a design spec when the change is cross-cutting or risky enough that the
contract's cost is repaid by catching scope/AC errors before build. Skip when
it is contained enough that the contract costs more than it saves.

Derived heuristic: the change spans multiple modules, or introduces a new contract
(public API, CLI command, IPC message format, Claude Code skill, or agent).

The user may always explicitly request a design spec — that overrides the heuristic.

When the expected-value test says skip (contained change, no new contract),
NO Verification Strategy section is authored — there is no lighter PR-one-liner form
in Phase 1 (deferred to a later phase). The evidence-honesty contract attaches to
full specs only.

## Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, also read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` and load the
text into context for the envelope below.

When dispatching to `touchstone:cross-provider-architect` (see Architect dispatch below), include in task envelope:

```json
{
  "task": "<existing task>",
  "system_prompt": "<existing system_prompt + loaded CONTEXT.md vocabulary verbatim>",
  "discipline_mode": "source-as-truth",
  "source_as_truth_vocab": "<loaded CONTEXT.md section text>",
  "role": "architect"
}
```

If `source-as-truth` is NOT adopted (yaml absent OR `adopted_disciplines` lacks it):
  Skip the CONTEXT.md Read. When dispatching, set:

```json
{
  "task": "<existing task>",
  "system_prompt": "<existing>",
  "discipline_mode": "none",
  "role": "architect"
}
```

(Omit `source_as_truth_vocab` field entirely; do not pass empty string.)

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
> Read `skills/_shared/ground-and-sweep.md`

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

Inputs to collect + the drafting workflow (template read, AC-sharpening from Foundation.aim, mandatory line-width policy, write → dispatch → rewrite steps) → [`references/draft-workflow.md`](references/draft-workflow.md).

### Architect dispatch (default: Pattern A composite — fresh context)

Dispatch-target resolution (`cc` / `codex` / default Pattern A composite) + the structural-review task envelope → [`references/architect-dispatch.md`](references/architect-dispatch.md).

### Output

- One file at `<specs_dir>/YYYY-MM-DD-<feature-name>-design.md`
- Terminal summary with: spec path, architect-identified issues addressed,
  architect-identified issues surfaced to Open Questions
- Next step: `/superpowers:writing-plans` takes the spec as input for plan
  generation

## Boundary — the architect critique is NOT the design-review gate

**The architect critique never discharges the `/touchstone:design-review` gate — different reviews, different criteria (rationale: ADR-0015).**

The architect critique is an author-time adversarial pressure-test that improves the draft before human-accept. It dispatches the `architect` composite (structural validate + adversarial), is advisory (`approve|revise|block`), and is skippable (`quick`). Its verdict is not the gate's doc-review C+H currency — passing it leaves the gate's Verification-Strategy check unaudited.

The human-accept step sits between them:

```
/touchstone:design-spec (architect critique)  →  Status: Draft  →  human reads/edits/accepts ★  →  /touchstone:design-review (gate)
```

Always run `/touchstone:design-review` on the **final, human-accepted** artifact; never treat "design-spec was run" as "the gate passed".

## Usage

```
/touchstone:design-spec                          # interactive draft
/touchstone:design-spec <feature-name>           # skip name prompt
/touchstone:design-spec <feature-name> quick     # skip architect dispatch (draft only — fast iteration)
/touchstone:design-spec <feature-name> with codex   # force Codex-only architect (no parallel CC)
/touchstone:design-spec <feature-name> with cc      # force CC-only architect (no parallel Codex)
```

The `quick` modifier skips the architect critique entirely. Useful for early sketches where structural review is premature; the user is expected to re-run without `quick` once the spec stabilizes. `Status: Draft` still applies, and the file is still written to `<specs_dir>/`.

The `with <vendor>` modifier overrides the architect routing — the default Pattern A composite (CC `architect` + Codex `codex-adversarial-reviewer` in parallel) is replaced with a single-vendor dispatch. Recognized vendors: `codex`, `cc`. Unrecognized values fail loudly: "unknown vendor in `with` modifier — expected `codex` or `cc`".

`quick` and `with <vendor>` are mutually exclusive — `quick` skips dispatch entirely, so vendor routing is moot. If both appear, `quick` wins and the `with` modifier is silently ignored.

The architect critique runs by the same expected-value principle: run it when the
draft is substantial enough to warrant the pressure-test; skip (`quick`) when
structural review is premature for the sketch at hand. The user may override in
plain language ("skip the architect" or "force codex only"). Note: `with <vendor>`
routing is entangled with the cross-provider architecture and is not resolved here
— see `references/architect-dispatch.md` for current routing logic.

## Status Lifecycle (intentionally minimal)

Specs are written as `Status: Draft`. Transitions to `Accepted` / `Superseded`
are manual edits when the user approves or replaces a spec. The skill does not
manage lifecycle — when a spec is ready to implement, the human changes the
status and hands off to `/superpowers:writing-plans`. The `Draft → human accept`
step is the seam between this skill's architect critique and the `/touchstone:design-review`
gate (see Boundary above) — keep it human-owned.

## Related

- Bundled template: `${CLAUDE_PLUGIN_ROOT}/skills/design-spec/template.md`.
- design-review gate (downstream, distinct from the architect critique): `/touchstone:design-review` — see the Boundary section.
- Workflow chain, other upstream/downstream skills, ADR workflow, example spec: `README.md`.
