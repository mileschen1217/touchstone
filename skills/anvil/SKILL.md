---
name: anvil
description: >-
  Use when an accepted contract (spec.yaml with status accepted) needs to be
  built; stops before ship and hands off to phase-ship. Out of scope — a spec
  not yet at status accepted.
allowed-tools: [Bash, Read, Skill, Agent, Edit, Write]
user-invocable: true
kind: workflow
---

# /touchstone:anvil — Back-End Contract Executor

Apply `../.shared/harness-runtime.md` before any host-dependent operation.

Invocation: `/touchstone:anvil <spec-path>`. Run in a fresh session.

## Stage 1 — entry check

The spec's `status` is `accepted`, and:

```bash
bash "<plugin-root>/scripts/design-review-precheck.sh" "$spec" --attest
```

Non-zero exit → surface the output verbatim and halt. Zero → proceed.

## Stage 2 — build via conductor

Run `invoke_skill(conductor:orchestration-mode, <spec path>)` with the spec as the
task. The commander (this session, under conductor's procedure) decomposes,
grades, dispatches, and harvests; per-task acceptance and scope-change
escalation are conductor's. A trivial contract resolves as conductor's
0-worker inline form — anvil adds no branch for it.

Anvil's three duties inside this stage:

1. **AC-coverage floor** — after the task contracts are written and BEFORE any
   dispatch: every AC id in the spec maps to ≥1 task contract (or one explicit
   deferred line naming the AC and why). An unmapped AC halts the run — never
   dispatch around it, never patch it in silently.
2. **Contract steering** — a bug-fix-shaped task's implementer contract names
   the failing test to write first; a parser/guard-shaped task's contract asks
   which admitted input shapes the suite feeds. Every task contract points
   worker scratch output at the session scratchpad, never inside the epic
   directory.
3. **Deviation log** — a build-time gap against the spec is a `D-n` entry in the
   epic's `deviation.yaml` the moment it is found, never a note in the run
   report. Field set: `<plugin-root>/skills/.shared/schemas/deviation.schema.yaml`;
   the judgment-authored fields are yours to write (the schema's authoring
   notes say which).

Conductor unavailable (skill absent) → build under
`<plugin-root>/skills/.shared/light-loop.md` (read it; the same three
duties apply), then continue at Stage 3; state the fallback in the run report.

## Stage 3 — deliverable-review

Run `invoke_skill(deliverable-review, <branch range>)` with
the spec as the governing spec. Anvil never promotes an AC to verified — an
`unverified` status in review.yaml survives intact to Evidence Reckoning.
Convergence and what blocks: the stopping rule the gate injects,
`<plugin-root>/skills/.shared/inject/severity-tiered-stopping-rule.md`
— anvil reads its outcome and never re-runs the gate past its budget.

## Terminal — reviewed deliverable on a branch, handed to phase-ship

Hand the branch, the review.yaml verdict, and any surviving `unverified` list to
phase-ship (`epic-driven-roadmap` `references/phase-ship.md`) — they are inputs
to the ship informed-accept there, the second of a unit of work's two human
accepts; anvil asks for no accept of its own. **Anvil stops before ship** — never
push, open a PR, merge, or release, on any path including halts.
