---
name: design-spec
kind: workflow
description: |
  Generate a design spec for a non-trivial feature. Produces a structured spec
  document at the project's configured specs directory. Required trigger: the
  feature touches 3+ files across 2+ modules, OR introduces a new contract
  (API / CLI / IPC / skill). Smaller features skip this step and go straight to
  plan or implementation. On first invocation in a project, runs setup to record
  the specs directory. Always dispatches the `architect` agent for fresh-context
  review of the draft.
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

# m-design-spec

Produce an ATDD + TDD double-loop-aligned design spec for a feature, review it
in fresh context via the `architect` agent, and write the final draft to the
project's specs directory.

## When to Invoke

Required when any of these is true:
- Feature touches 3+ files across 2+ modules
- Introduces a new contract: public API, CLI command, IPC message format,
  Claude Code skill, or agent
- The user explicitly requests a design spec

Skip when:
- Feature is a single-file patch or bug fix
- Touches one module, preserves existing contracts
- Follows a pattern already specified elsewhere in the codebase

When a feature qualifies for skip (single-file / one-module / pattern-following),
NO Verification Strategy section is authored — there is no lighter PR-one-liner form
in Phase 1 (deferred to a later phase). The evidence-honesty contract attaches to
full specs only.

Naturally chained with exploration (Topic 2 routing) on the input side and
`/superpowers:writing-plans` on the output side:

```
Explore → /touchstone:design-spec → /superpowers:writing-plans → Build (ATDD+TDD)
```

## Step 0 — Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/step0-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, also read
`${CLAUDE_PLUGIN_ROOT}/CONTEXT.md` § "Bridge content gate" and load the
text into context for the envelope below.

When dispatching to `touchstone:cross-provider-architect` (Step N below), include in task envelope:

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

### Step 0 — Foundation elicitation (Baseline — always runs)

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

## Boundary — the Step-5 review is NOT the design-review gate

The architect dispatch in Step 5 is an **author-time, one-shot, non-gating** critique that improves the draft. It is a different thing from `/touchstone:design-review`, the Stage-0 **design-review gate** (the gate that runs before Build). Conflating the two is a recurring mistake — they share only the *shape* (both are a Pattern-A cross-provider review of the spec) but differ in **criteria/backend** (architect/structural vs reviewer/doc-checklist), cadence, enforcement, and what version they judge:

| | Step-5 review (this skill) | `/touchstone:design-review` (the gate) |
|---|---|---|
| Role | author-time critique, improve the draft | design-review gate, pass/fail before implementation |
| Backend / criteria | `architect` composite — structural validate + adversarial | `reviewer` composite + doc-review prompt (Problem/Scope/AC/Interfaces + **Verification-Strategy**) |
| Verdict | `approve\|revise\|block`, advisory — no enforced iterate-to-green | C+H tiered: C+H≥5 → mandatory 2nd pass, **blocks Build until C+H=0** |
| Skippable | yes (`quick`) | no — not on user discretion at C+H≥5 |
| Judges | the freshly-drafted version | the **final, human-accepted** version |

The human-accept step sits **between** them:

```
/touchstone:design-spec            →   Status: Draft   →   human reads / edits / accepts ★   →   /touchstone:design-review (blocking gate)
(draft + Step-5 critique)                          (lifecycle owned by the human)        (C+H gate, blocks Build)
```

Running this skill **never** discharges `/touchstone:design-review` — they are different reviews. Step-5 is the **architect** composite (structural, advisory); the gate is the **reviewer** composite with the doc-review prompt (incl. the Verification-Strategy / live-bearing declaration), C+H-tiered and Build-blocking. Step-5's `approve|revise|block` is not the gate's doc-review C+H currency, so passing Step-5 leaves the gate's checklist (notably Verification-Strategy) unaudited. Always run `/touchstone:design-review` on the **final, human-accepted** artifact; the seam is the human-in-the-loop accept step. (Rationale: ADR-0015.)

## Usage

```
/touchstone:design-spec                          # interactive draft
/touchstone:design-spec <feature-name>           # skip name prompt
/touchstone:design-spec <feature-name> quick     # skip architect dispatch (draft only — fast iteration)
/touchstone:design-spec <feature-name> with codex   # force Codex-only architect (no parallel CC)
/touchstone:design-spec <feature-name> with cc      # force CC-only architect (no parallel Codex)
```

The `quick` modifier skips Step 5 (architect dispatch) entirely. Useful for early sketches where structural review is premature; the user is expected to re-run without `quick` once the spec stabilizes. `Status: Draft` still applies, and the file is still written to `<specs_dir>/`.

The `with <vendor>` modifier overrides the architect routing — the default Pattern A composite (CC `architect` + Codex `codex-adversarial-reviewer` in parallel) is replaced with a single-vendor dispatch. Recognized vendors: `codex`, `cc`. Unrecognized values fail loudly: "unknown vendor in `with` modifier — expected `codex` or `cc`".

`quick` and `with <vendor>` are mutually exclusive — `quick` skips dispatch entirely, so vendor routing is moot. If both appear, `quick` wins and the `with` modifier is silently ignored.

### Argument parsing

Parse left-to-right:
1. Next non-keyword token (not `quick` / `with`) → `feature_name`.
3. If `quick` appears anywhere → `quick = true` (skip architect).
4. If `with <vendor>` appears, set `force_architect = <vendor>`. Validate against {`codex`, `cc`}; fail loudly otherwise.

## Status Lifecycle (intentionally minimal)

Specs are written as `Status: Draft`. Transitions to `Accepted` / `Superseded`
are manual edits when the user approves or replaces a spec. The skill does not
manage lifecycle — when a spec is ready to implement, the human changes the
status and hands off to `/superpowers:writing-plans`. The `Draft → human accept`
step is the seam between this skill's Step-5 critique and the `/touchstone:design-review`
gate (see Boundary above) — keep it human-owned.

## Related

- Template: `${CLAUDE_PLUGIN_ROOT}/skills/design-spec/template.md` (bundled)
- Exploration routing (upstream): Topic 2 in global CLAUDE.md
- Architecture consult (upstream, conditional): `/touchstone:arch-review` — for
  resolving architectural questions before drafting the spec
- ATDD chain (downstream): `ATDD — spec and test development` in global CLAUDE.md
- design-review gate (downstream, distinct from Step-5 review): `/touchstone:design-review` — see Boundary section
- Plan generation (downstream): `/superpowers:writing-plans`
- ADR workflow: `${CLAUDE_PLUGIN_ROOT}/skills/arch-review/adr-authoring.md`
- Example spec matching the template:
  `docs/superpowers/specs/2026-04-16-m-extract-knowledge-design.md` (Obsidian repo)
