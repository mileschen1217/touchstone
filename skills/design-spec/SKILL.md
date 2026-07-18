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

# design-spec

Produce a requirement/AC design spec for a feature and write the Draft to the
project's specs directory. This skill emits only Draft — promotion (accept,
build) is downstream.

**Draft Mode may need a live responsive user** — with no qualified
confirmed-facts source supplied, pointwise elicitation prompts the human; with
a supplied source, no prompt fires.

**When to invoke** — the heuristic lives in the frontmatter description above.
Breadth alone does not qualify — a fixed-invariant multi-module sweep takes a
PRD+seams light contract instead. An explicit user request overrides the
heuristic either way.

**Load vocabulary** — follow
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`. When the resolved
bundle adopts `source-as-truth`, additionally load
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md`.

## Draft Mode

### 1. Foundation & facts intake (always runs)

Interface: **facts sources in → Draft spec out.** Sources are those the caller
or user supplies, or already in context — never glob or hunt for epic indexes
or interview records yourself.

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/confirmed-facts-source.md`
and follow it exactly for qualification and citation granularity. Delta: a
validation failure (any trigger class) is dispositioned by asking the human or
marking `[NEEDS CLARIFICATION]` — never a silent Scope/Invariants entry. The
AC / acceptance-seam layer is authored HERE — a source hands over confirmed
facts, never pre-drafted seams.

**Degenerate form** (no qualified source, facts unresolvable from context):
emit "This subject has no qualified confirmed-facts source — continuing
standalone, I will elicit each missing fact pointwise," then elicit pointwise.
No multi-round mini-interview.

**Reframe exit** (user reframes during intake, e.g. "this should be a fixture,
not a spec"): STOP, write no file, report "Scope reframed to [X] — a design
spec is not needed. Exiting Draft Mode."

**Record** the confirmed foundation under `## Foundation` (all three fields).

### 2. Want-layer (always-on)

This spec IS the canonical want-home — no separate PRD section. Authoring
conventions (US-N template, traces-to discipline):
`references/authoring.md § Want-layer authoring`.

**REQ-headline discipline.** A `### Requirement:` headline is ONE normative
SHALL sentence — write it, then stop (`traces-to:` is a separate line below).
Every disambiguation lives in the REQ/AC layer, not the headline: an error
path becomes an error-path AC, an invariant an unwanted-behavior REQ, an
interface a fenced block under its owning REQ. A clause already homed
downstream never repeats in the headline.

### 3. Acceptance criteria (feedforward ground-and-sweep)

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/ground-and-sweep.md` before
> generating ACs. Application: `requirement × current-repo-state` — ground
> each AC in concrete repo facts (file path, line, value); sweep the true
> subject set to saturation, not first-hit. Drafting conventions (index
> table, `[unverified]` marker, live-bearing line): `references/authoring.md`.

### 4. Challenge pass (independent, fresh-context)

Dispatch a fresh-context challenger agent (challenger ≠ this authoring
session) to pressure-test the want-layer + AC layer for missing behaviour
boundaries. Mechanics and technique catalogue: `references/authoring.md §
Challenge pass`. Place every gating finding (`coverage-gap` /
`real-defect`) inline as a `[NEEDS CLARIFICATION: <q>]` marker on its REQ or
AC line; a `refinement` finding never blocks. Resolve or defer per
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md`
§ "Challenge-pass loop".

When the round closes, stamp the frontmatter — the sole challenge attestation,
no separate result file: `challenged-by: <challenger's own session/transcript
id> / <YYYY-MM-DD> / <commit sha, or "uncommitted">`. The id MUST be the
challenger's own identity, never this session's — independence is
forcing-grade.

**5. Internal coverage audit** — for each US-N: if every requirement tracing
to it also traces to ≥1 other want, surface it as a demote-to-invariant
candidate for human judgment — never auto-demote. If none, emit "Coverage
audit: no demote-to-invariant candidates."

## Output

- One file at `<specs_dir>/YYYY-MM-DD-<feature-name>-design.md`
- Terminal summary: spec path, `Status: Draft`
- Next: crucible writes `accepted-candidate`, then `/touchstone:design-review`
  runs the consolidated gate before human accept
- Usage: `/touchstone:design-spec` (interactive) or
  `/touchstone:design-spec <feature-name>` (skip name prompt)

## Related

- Bundled template: `${CLAUDE_PLUGIN_ROOT}/skills/design-spec/template.md`;
  drafting inputs, want-layer authoring, challenge-pass mechanics:
  `references/authoring.md`.
- Structural floor (every US ≥1 requirement, every requirement ≥1 AC, zero
  unresolved clarification markers), checked downstream by
  `${CLAUDE_PLUGIN_ROOT}/scripts/check-spec-floor.sh` and
  `${CLAUDE_PLUGIN_ROOT}/scripts/check-live-bearing.sh`.
