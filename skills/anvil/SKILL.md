---
name: anvil
description: Use when an accepted contract (spec with status accepted) needs to be built — entry check → conductor orchestration-mode (commander decomposes under the AC-coverage floor) → final cross-vendor review → human final-accept. Stops before ship. Out of scope — a spec not yet `status: accepted`, or a PRD+seams light contract (built through the light loop directly).
allowed-tools: [Bash, Read, Skill, Agent, Edit, Write]
user-invocable: true
kind: workflow
---

# /touchstone:anvil — Back-End Contract Executor

Takes the accepted contract to a reviewed deliverable on a branch, framed by
exactly two human touch-points: the accept that let it start, and the
final-accept it ends on. Invocation: `/touchstone:anvil <spec-path>`. Prefer a
fresh session; the orchestrator carries stage state, not build history.

## Stage 1 — entry check

The spec's frontmatter says `status: accepted`, and:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" "$spec"
```

Non-zero exit → surface the output verbatim and halt; a stale or
structurally-unsound contract must never be industrialised. Zero → proceed.

## Stage 2 — build via conductor

Invoke `Skill(skill: "conductor:orchestration-mode")` with the spec as the
task. The commander (this session, under conductor's procedure) decomposes,
grades, dispatches, and harvests; per-task acceptance and scope-change
escalation are conductor's. A trivial contract resolves as conductor's
0-worker inline form — anvil adds no branch for it.

Anvil's two duties inside this stage:

1. **AC-coverage floor** — after the task contracts are written and BEFORE any
   dispatch: every AC id in the spec maps to ≥1 task contract (or one explicit
   deferred line naming the AC and why). An unmapped AC halts the run — never
   dispatch around it, never patch it in silently.
2. **Contract steering** — a bug-fix-shaped task's implementer contract names
   the failing test to write first; a parser/guard-shaped task's contract asks
   which admitted input shapes the suite feeds. Test-first is contract content,
   never a claimed-then-unverifiable process stamp: the enforced floor is that
   no AC is done without a test asserting its Then (Stage 3 checks it).

Conductor unavailable (skill absent) → fall back to the light loop: build
directly with dispatched workers, then continue at Stage 3; state the fallback
in the run report.

## Stage 3 — final cross-vendor review

Dispatch `touchstone:cross-provider-reviewer` on the whole deliverable against
the spec. Inject verbatim into its `system_prompt`:
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/design-soundness-honor-check.md`
(feedback duty — the deliverable vs the spec's structural commitments,
subsystem scope) — skip this one injection only if `/touchstone:code-review
batch` already ran CLEAN (C+H=0, no banner) on the same range this session.

Per-AC honesty is this stage's floor: every AC judged covered or forced to
`[unverified: reason]`; anvil never promotes an AC to verified — markers
survive intact to Evidence Reckoning. Convergence follows
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md`
(single home). Critical/High block; a ⚠️ DEGRADED / ⚠️ PARTIAL banner is
presented verbatim for explicit acknowledgement.

Gate stamp — when the review resolves, record its yield per
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/gate-stamp.md` (gate-id
`anvil-final-review`; target = the spec path).

## Terminal — reviewed deliverable on a branch

Present the branch, the review verdict, and any surviving `[unverified]` list
for the human's final-accept — an informed accept: the post-build pair
(buy-in explainer + comprehension quiz, home: `epic-driven-roadmap`
`references/phase-ship.md`) runs BEFORE the accept is acted on. **Anvil stops before ship** — never push, open a
PR, merge, or release, on any path including halts. A stuck gate escalates to
the human; it never retries forever or passes anyway.
