---
name: anvil
description: Use when an accepted contract (spec with status accepted) needs to be built — sequences entry-precondition → writing-plans → plan-review → SDD → final cross-vendor review, judging each dispatched stage through the fail-closed stage-return gate and stopping before ship. Out of scope — a spec not yet `status: accepted`, or a PRD+seams light contract (built through the light loop directly, not anvil).
allowed-tools: [Bash, Read, Skill, Agent, Edit, Write]
user-invocable: true
kind: workflow
---

# /touchstone:anvil — Back-End Contract Executor

Runs the accepted contract through the fixed back-end pipeline and stops at a
reviewed deliverable on a branch. **anvil** is a plain orchestrator skill
(sequential sub-skill invocation).

**Invocation:** `/touchstone:anvil <spec-path>` (frontmatter `status: accepted`).
Execution note: prefer a fresh session for an anvil run, and let context compact
between SDD tasks — the orchestrator carries only stage state, not build history.

Claim boundary: `CONTEXT.md § honest ceiling (anvil)` governs — this body never
claims past it.

## Stage sequence (un-skippable — each gate's DONE is the next's precondition)

```
entry-precondition → writing-plans → [boundary check] → plan-review → SDD
  → final cross-vendor review → reviewed deliverable on branch
```

**stage-return gate** — every dispatched stage's native output is judged by
`scripts/stage-return.sh <stage> <task_dir>`, which prints exactly one
`status=DONE|NEEDS_HUMAN|BLOCKED` line. Proceed ONLY from that line — never from
stage liveness; anything that is not a well-formed DONE is treated as not-done
(fail-closed, at every gate). Handling is identical at every gate:
- `status=DONE` → next stage.
- `status=BLOCKED` → surface the findings/BLOCK line; halt. No downstream stage runs.
- `status=NEEDS_HUMAN` → surface the reason; halt for explicit human ack.

Observability (never blocks — the scripts silently no-op on failure): at each
stage's start and end run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/metrics/stage-event.sh" <stage> <start|end>`.

Before any stage: verify `superpowers:writing-plans` and
`superpowers:subagent-driven-development` are in the available-skills list; if
either is absent, stop and name the missing skill and its source (official
Superpowers plugin).

## Stage 1 — entry-precondition (dispatched)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" "$spec" > "$task_dir/precheck.out" 2>&1
echo $? > "$task_dir/precheck.rc"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/stage-return.sh" entry-precondition "$task_dir"
```

On BLOCKED, surface `precheck.out` verbatim.

- [ ] `status=` line read; on non-DONE, halted with the reason surfaced.

## Stage 2 — writing-plans (in-session) + boundary check

Invoke `/superpowers:writing-plans` in-session (authoring independence comes from
the downstream plan-review dispatch). Then run the **boundary check**:
1. The plan file exists.
2. The file is non-empty.
3. It contains ≥1 task line (`- [ ]` or numbered).

Any failure → halt and surface; never dispatch plan-review on a degenerate plan.

- [ ] All three boundary conditions verified on the actual file.

## Stage 3 — plan-review (dispatched)

Dispatch `touchstone:cross-provider-reviewer` on the plan. The dispatch prompt MUST
require the sentinel `STAGE-REVIEW-SUMMARY: critical=<n> high=<n> degraded=<true|false>`
as the output's last line. Capture `$task_dir/review.result.json` (native result) and
`$task_dir/review.md` (synthesis + sentinel), then:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/stage-return.sh" plan-review "$task_dir"
```

- [ ] Both artifacts captured BEFORE running the gate; `status=` acted on. On
      BLOCKED: after the human resolves the findings, re-invoke anvil or this stage.

## Stage 4 — SDD (in-session)

Invoke `/superpowers:subagent-driven-development` in-session (continuous execution,
no routine human stops). Two orchestrator duties in the SDD prompts:
1. **Adversarial-input duty** — when a task builds or tests a parser / extractor /
   guard, carry this question into that task's prompt: which of the shapes the
   contract admits (empty input, zero-byte file, success-with-empty-output,
   multi-line records, legally-empty fields, half-open vs inclusive boundaries)
   does the suite feed? An unfed shape is unwitnessed behaviour.
2. **Final-reviewer suppression** — instruct SDD to skip its own end-of-run holistic
   review pass: anvil's final cross-vendor review (next stage) is the deliverable's
   final gate, and doubling it buys a second same-scope pass, not new coverage.
   (Per-task reviewers stay untouched.)

After SDD, read `.superpowers/sdd/progress.md`: all tasks complete → final review;
a BLOCKED task → surface directly to the human and resume after resolution.

SDD per-task token/cost is `[unverified: token capture]` (SDD's ledger records
commits, not tokens; observing it means re-owning the loop — Level-B deferred).

- [ ] `progress.md` read; terminal state acted on.

## Stage 5 — final cross-vendor review (dispatched)

**Design-soundness feedback arm:** dispatch
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/design-soundness-honor-check.md` (and its
injector-requirement `arch-rubric.md`) by **path+attestation** per
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/path-attestation-dispatch.md` (single home of the
dispatch form + shared fallback). Apply its feedback duty to the WHOLE deliverable vs the
governing spec's structural commitments (the **depth-stakes REQ set** for six-section
specs; the `## Architecture` section for pre-P2 specs; subsystem scope, not per-diff):
enumerate the spec's SHALL commitments and judge each honored / violated /
`[unverified: reason]`. Never restate the fragment body.
*Skip condition:* if `/touchstone:code-review batch` already ran CLEAN (C+H=0, no
banner) on this same range in this session, skip THIS fragment injection only — the
standard cross-vendor review below still runs in full.

Dispatch `touchstone:cross-provider-reviewer` on the deliverable; same
capture-then-gate two-step as plan-review:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/stage-return.sh" final-review "$task_dir"
```

Convergence: this review and the per-task reviewers converge under the
severity-tiered stopping rule
(`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md`,
single home — same tiers, same bounded re-verify budget, same blocked
escalation; do not restate it). The stage-return gate's BLOCKED is the rule's
blocked-line surfacing.

- [ ] Fragment injected (or skip condition explicitly noted in the run log);
      `status=` acted on — a BLOCKED result is never presented as a clean deliverable.

## Terminal — reviewed deliverable on a branch

Present the branch name and the final-review result for the human's accept, and
close this run's metrics window:
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/metrics/stamp-end.sh"`.
**anvil stops before ship**: never push, open a PR, merge, or release on any code
path — including BLOCKED and NEEDS_HUMAN halts.

Invariant carried through every stage: anvil never promotes an AC to verified —
`[unverified]` markers survive intact to Evidence Reckoning.

## Dogfood report (at run end)

| Column | Content |
|---|---|
| Stage / task | entry-precondition, plan-review, each SDD task (from `progress.md`), final-review |
| Wall-clock | start→end per stage (anvil records timestamps around each sub-skill call) |
| Tokens in/out | where capturable from the stage's result artifact; else `[unverified: token capture]` — honest degradation, never a silent omission |
| Cost | tokens × resolved model price; else `[unverified: token capture]` |

Plus: **catch-attribution** — `{finding_id → gate}` (plan-review vs final-review),
so per-gate ROI is observable; **rework_rate** — task-review send-backs vs
first-pass acceptances (from `progress.md`).

**Provenance floor** (authenticates the report as a real run): (1) the contract/spec
path, (2) the run date, (3) the commit hash via `git rev-parse HEAD` stamped by an
in-session Bash call — never hand-entered.
