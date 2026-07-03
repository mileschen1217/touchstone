---
name: anvil
description: Back-end contract executor — sequences entry-precondition → writing-plans → plan-review → SDD → final cross-vendor review, consuming a typed stage-return envelope at each dispatched stage and stopping before ship.
allowed-tools: [Bash, Read, Skill, Agent, Edit, Write]
user-invocable: true
kind: workflow
---

# /touchstone:anvil — Back-End Contract Executor

**anvil** is a plain orchestrator skill (the crucible precedent — sequential sub-skill invocation, NOT a Workflow-tool JS script). It takes an accepted contract from crucible's front-end and runs the full back-end pipeline, stopping at a reviewed deliverable on a branch. The human governs ship (Stage 7: push / PR / merge / release) — anvil never crosses that boundary.

**Invocation:** `/touchstone:anvil <spec-path>` where `<spec-path>` is an accepted spec (frontmatter `status: accepted`).

---

## Stage sequence (un-skippable — each gate's DONE is the next's precondition)

```
entry-precondition → writing-plans → [boundary check] → plan-review → SDD → final cross-vendor review → reviewed deliverable on branch
```

Each dispatched stage produces a `stage-return/v1` artifact via `normalize-stage-return.sh`. anvil proceeds only from the validator's `status=` — never from liveness.

---

## Entry precondition (dispatched; structured-return required)

Run the Phase-3.1 spine-integrity gate on the accepted contract. Capture native output FIRST, then normalize:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" "$spec" > "$task_dir/precheck.out" 2>&1
echo $? > "$task_dir/precheck.rc"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/normalize-stage-return.sh" entry-precondition "$task_dir"
```

**Structured-return handling:**
- `status=DONE` → proceed to writing-plans.
- `status=BLOCKED` → surface the BLOCK line to the human; halt. Run **no downstream stage**.
- `status=NEEDS_HUMAN` → surface the reason; halt for ack before any downstream stage.

Stale digest, unmet structural floor, or script non-zero → adapter emits `BLOCKED` (fail-closed).

---

## writing-plans (in-session)

Invoke `/superpowers:writing-plans` in-session (inherits session context; authoring independence is supplied by the downstream `plan-review` dispatch). Output: a plan file at a known path.

### Boundary check (before dispatching plan-review)

After `writing-plans` completes, verify:
1. The plan file exists.
2. The file is non-empty.
3. The file contains ≥1 task (at least one `- [ ]` or numbered task line).

If any check fails: halt and surface to the human. Do NOT dispatch plan-review on a degenerate plan.

---

## plan-review (dispatched; structured-return required)

Dispatch `touchstone:cross-provider-reviewer` on the plan. The dispatch prompt MUST ask the reviewer to end its output with the sentinel:

```
STAGE-REVIEW-SUMMARY: critical=<n> high=<n> degraded=<true|false>
```

Capture into `$task_dir/review.result.json` (the composite's native result) and `$task_dir/review.md` (free-text synthesis + sentinel), then normalize:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/normalize-stage-return.sh" plan-review "$task_dir"
```

**Structured-return handling:**
- `status=DONE` → proceed to SDD.
- `status=BLOCKED` → surface findings; halt. Human resolves; re-invoke anvil or this stage.
- `status=NEEDS_HUMAN` → surface degraded/partial provenance reason; halt for explicit ack.

---

## SDD (in-session)

Invoke `/superpowers:subagent-driven-development` in-session. SDD is designed for continuous in-session execution (no routine human stops). After SDD's run, read `.superpowers/sdd/progress.md` for terminal state:

- All tasks complete → proceed to the final review.
- A task is BLOCKED → surface directly to the present human (SDD runs in-session; no envelope needed — REQ-7 scope is dispatched stages only). Resume after resolution.

SDD per-task token/cost is `[unverified: token capture]` for v1 (SDD's ledger records commits, not model/token — observing it requires re-owning the loop, which is Level-B deferred).

---

## Final cross-vendor review (dispatched; structured-return required)

**Design-soundness feedback arm (FB).** Before dispatching the reviewer, read and inject
verbatim `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/design-soundness-honor-check.md`
into the reviewer prompt (append to `system_prompt`). This is the **feedback arm** applied
to the **whole deliverable** vs the **whole ## Architecture** section of the governing spec
(subsystem scope, not per-diff). The cold reviewer applies the honor-judgment rule: enumerate
the spec's SHALL commitments and judge each as honored, violated, or `[unverified: reason]`.
Single home: load by path; never restate the body inline.

Dispatch `touchstone:cross-provider-reviewer` on the deliverable. Same capture-then-normalize two-step as plan-review (write `review.result.json` + `review.md` into `$task_dir`):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/normalize-stage-return.sh" final-review "$task_dir"
```

**Structured-return handling:**
- `status=DONE` (C+H=0, not degraded) → proceed to terminal.
- `status=BLOCKED` (C+H≥1) → surface findings; halt. Human resolves; do NOT present clean deliverable.
- `status=NEEDS_HUMAN` (degraded provenance) → surface reason; halt for ack.

---

## Terminal — reviewed deliverable on a branch

Present the branch name and the final-review result to the human for their final-accept.

**anvil stops here.** It never push, open a PR, merge, or release on any code path — including BLOCKED and NEEDS_HUMAN halts. Ship stays the human-governed Stage 7.

---

## Invariants

1. **Never promote AC to verified** — anvil does not mark any AC verified; `[unverified]` markers survive intact to Evidence Reckoning.
2. **Stop before ship** — no git push / PR creation / merge / release under any path.
3. **Fail-closed** — anything not a well-formed DONE is treated as not-done. anvil proceeds only from the validator's `status=`, never from stage liveness.
4. **Escalate, never decide** — NEEDS_HUMAN and BLOCKED surface + halt; no silent auto-resolution of a human-gate.

---

## Honest ceiling

anvil claims exactly:
- **Deterministic stage sequencing** — the procedure specifies a fixed order; no stage may be skipped to reach a later one.
- **Independent cross-vendor FINAL review** — the final review is cross-vendor staffed (CC builds, Codex reviews or vice-versa).

Per-task builder≠reviewer swap remains SDD's soft internal loop (Level-B deferred — re-owning SDD's loop requires the Workflow-tool substrate anvil deliberately avoids). anvil does NOT claim: sweep-verification, per-task program-enforced independence, or anything stronger than the two buys above.

---

## Dogfood instrumentation

At run end, anvil emits a dogfood report. Fields:

| Column | Content |
|---|---|
| Stage / task | entry-precondition, plan-review, each SDD task (from `progress.md`), final-review |
| Wall-clock | start→end time for each stage (anvil records timestamps before/after each sub-skill call) |
| Tokens in / out | where capturable from the stage's result artifact; else `[unverified: token capture]` (wall-clock + model-mix retained — honest degradation, never a silent omission) |
| Cost | tokens × resolved model price; else `[unverified: token capture]` |

Additional report fields:
- **catch-attribution** — a map `{finding_id → gate}` listing which gate (plan-review vs final-review) caught each finding, so per-gate ROI is observable.
- **rework_rate** — task-review send-backs vs first-pass acceptances (from `progress.md`).

**Provenance floor** (so a reviewer can authenticate this as a real run, not a fabricated table): the report names:
1. The contract/spec path it ran against.
2. The run date.
3. The commit hash at run time: `git rev-parse HEAD` (anvil stamps this via a Bash call in-session — not hand-entered).

No crypto-attestation (over-spec for a markdown plugin whose close has a human in the loop) — these three marks suffice.
