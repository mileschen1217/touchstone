---
name: arch-review
description: |
  Standalone architecture consult. Invoke BEFORE writing a design spec when
  exploration surfaced 2+ viable approaches with real tradeoffs, OR the
  feature crosses an architectural boundary (new integration, stack layer
  change, migration). Dispatches the `architect` agent in fresh context,
  returns a tradeoff memo with recommendation, and optionally captures the
  decision as an ADR via ECC's architecture-decision-records skill. Not a
  replacement for `/touchstone:design-spec` — this is the pre-spec consult that
  settles architectural questions so the spec can assume them.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Skill
kind: workflow
---

## Step 0 — Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/step0-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, also read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` AND
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/standing-vs-transient-bridge.md`
and include the loaded text verbatim in the envelope below.

When dispatching to `touchstone:cross-provider-architect`, set envelope:
```json
{
  "task": "<existing task text>",
  "system_prompt": "<existing + loaded CONTEXT.md sections verbatim>",
  "discipline_mode": "source-as-truth",
  "source_as_truth_vocab": "<verbatim loaded text>",
  "role": "architect"
}
```

If not adopted: skip Read; envelope `discipline_mode: "none"`; omit `source_as_truth_vocab`.

# m-arch-review

Pre-code architect consult — for "which approach?", before the spec.

## When to Invoke

Invoke when ALL are true:

1. Exploration has produced findings (Topic 2 routing), or you have enough
   context to frame the question
2. Two or more viable approaches exist with real tradeoffs (not cosmetic)
3. No design spec has been written yet (or the spec is blocked by this
   question)

Typical triggers:
- Choosing between two integration patterns (e.g., webhook vs polling,
  event-driven vs request-response)
- Evaluating a migration (current stack vs proposed stack)
- Refactor direction ("consolidate modules" vs "extract shared kernel")
- Contract-level choice that will propagate through the design spec

Skip when:
- The direction is clear from exploration — go straight to `/touchstone:design-spec`
- The question is about code that already exists → that's `/touchstone:code-review batch`
- It's a tactical implementation choice, not architectural → resolve inline

## Inputs

If not provided in the invocation:

1. **Question / proposal** — one or two sentences framing what needs to be
   decided
2. **Context references** — one or more of:
   - File paths to exploration notes
   - File paths to current code being evaluated (for refactor / migration
     questions)
   - Inline summary of prior research
   - "None — frame from question statement"
3. **Candidate approaches (optional)** — if you've already sketched 2+
   options, list them. The architect will still verify exhaustiveness.

## Consult Workflow

### 1. Frame the question

Produce a one-paragraph framing:
- The problem
- Constraints (performance, compat, team, time)
- What "good" looks like (success criteria)

### 2. Dispatch touchstone:cross-provider-architect composite skill (Pattern A — fresh context)

```
Skill(skill: "touchstone:cross-provider-architect", args: {
  "task": "<the framing + context refs + candidate approaches as a single text>",
  "role": "architect",
  "task_dir": "<optional>"
})
```

The composite skill orchestrates two backends in parallel:
- `everything-claude-code:architect` — validates the design, produces tradeoff memo
- `codex-adversarial-reviewer` — pressure-tests the proposal, surfaces failure modes

Pattern A — dual parallel; auto-falls back to CC `architect` only if Codex unavailable. The dispatched skill (`touchstone:cross-provider-architect`) owns its procedure end-to-end.

Compose the task envelope from:
> Architecture consult. Read the framing and context references below.
> Return a tradeoff memo with:
>
> 1. **Options** — list the viable approaches (enumerate; add any missed)
> 2. **Tradeoffs** — for each option: pros, cons, risks, cost (build + operate), reversibility
> 3. **Recommendation** — which option and why, or "need more info on X"
> 4. **Decision trigger** — what would flip your recommendation
>
> Framing: <1-paragraph framing from step 1>
> Context references: <paths or inline summary>
> Candidate approaches: <user's list or "none — propose from scratch">

Fresh context — the composite skill orchestrates fresh subagent contexts; no drafting context bleeds through.

### 2.5 Informed-consent checkpoint

**Informed-consent checkpoint (orthogonal to the decision in Step 3):** if the composite's
returned synthesis (`<task_dir>/review.md`) carries a ⚠️ DEGRADED or ⚠️ PARTIAL banner,
present the banner text to the user VERBATIM and obtain explicit acknowledgement (an
`AskUserQuestion` choice, or an explicit user "proceed") BEFORE presenting the memo in
Step 3. The banner is informational, not a hard block, but the workflow MUST NOT
auto-advance past it without the human knowingly acknowledging that the architect memo
was produced by a single provider rather than the dual-parallel Pattern A pair. A clean
synthesis (no banner) does not trigger this checkpoint. The banner's meaning is defined
in `skills/cross-provider-reviewer/references/provenance.md`.

### 3. Review + decide

Present the architect's memo to the user. The user:
- **Accepts the recommendation** → proceed to step 4 (ADR)
- **Picks a different option** → note the rationale, proceed to step 4
- **Asks for more info** → narrow the question, re-dispatch if needed
- **Defers** → save the memo, exit without an ADR

### 4. Capture as ADR (conditional)

Skip this step entirely if invoked with `--defer-adr` (run the consult, capture no ADR).

If a decision was made (step 3 "accepts" or "picks"), invoke the ADR workflow
documented in `adr-authoring.md`:

- Call ECC's `architecture-decision-records` skill
- Add `Triggered by: /touchstone:arch-review` and `Related ADRs: ...` headers
- Confirm filename and approve before write

If the user deferred, skip this step and save the memo to a scratch location
(e.g., project's working notes) for later. Do not write the memo to `docs/adr/`
unless a decision was made — memos without a decision go to scratch, not the ADR
dir. If ECC's `architecture-decision-records` skill is not installed, fall back to
manual ADR writing per `adr-authoring.md`.

### 5. Hand off to design spec (optional)

If the decision unblocks a feature design:

```
Next: /touchstone:design-spec <feature-name>
  — reference ADR-NNNN in the Related section
  — the Architecture section can now assume <chosen approach>
```

## Related

- Downstream: `/touchstone:design-spec` (spec drafting), `/superpowers:writing-plans` (sequencing).
- ADR workflow: `adr-authoring.md` (this skill's directory).
- Maintainer notes (invocation table, dependencies): `README.md`.
