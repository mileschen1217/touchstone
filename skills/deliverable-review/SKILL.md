---
name: deliverable-review
description: |
  Use when a finished build (a branch or logical commit group) needs its one review before the human accept — two agents in two contexts: spec conformance (AC evidence under the live-bearing predicate, invariant checks executed) and cross-vendor code quality (the reviewer is never the vendor that built the code); one review.yaml, one human accept. Out of scope — single-commit ad-hoc review (Claude Code's built-in `/code-review`) and design-document review (`/touchstone:design-review`).
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:deliverable-review

```
/touchstone:deliverable-review [<range>] [with <codex|cc>]   # default <main>..HEAD
```

## Phase 1 — Range, governing spec, builder, reviewer

Range: the given argument, else `$(git merge-base HEAD main)..HEAD` (project
CLAUDE.md may override the base branch).

Governing spec: the caller's `spec` argument, else the active epic's
`status: accepted` `*.spec.yaml` (epic dir per `touchstone.yaml` `epics_dir`).
Unresolvable → the conformance agent is not dispatched; emit exactly one line,
`no governing spec — conformance not audited`, and run the quality agent alone.

Builder — always detect, even under a forced reviewer:
`git log --format=%B <range> | grep -iE '^Co-Authored-By:.*(codex|gpt-?5|openai)'`.
Any hit → `builder = codex`; otherwise `builder = cc`. Log it: "Builder detection:
N/M commits tagged Codex → builder = codex; quality reviewer = cc" (or the inverse).
If a Codex agent built without tagging commits, override with `with cc`.

Quality reviewer = the vendor opposite `builder` (`touchstone:codex-reviewer` when
`builder = cc`; `touchstone:code-reviewer` when `builder = codex`) unless `with <vendor>`
forces it — force waives the vendor rule, never builder detection.

## Phase 2 — Inject (once, verbatim, from `${CLAUDE_PLUGIN_ROOT}`)

Conformance context:
- the two evidence-honesty fragments under `skills/_shared/inject/` (`live-bearing-predicate.md`, `ac-coverage-honesty-principle.md`), also carried as `evidence_honesty_vocab`.
- `skills/deliverable-review/references/ac-coverage-criteria.md` (sole injector), then this delta: for each AC with `live_bearing: true`, apply the predicate's evidence rules (static-proxy disqualification, two-part provenance, producer ≠ judge) — a static-proxy-only or artifact-less claim is recorded `unverified` naming the proxy; you authenticate the artifact, never re-run the producer.
- `design-soundness-honor-check.md` (same dir) with `skills/assay/references/arch-rubric.md` injected as content — **feedback arm**: execute every `invariants[].check` against the delivered tree.
- Diff touches test files → `skills/deliverable-review/references/reviewer-prompts.md` (sole injector).

Quality context:
- `skills/_shared/inject/severity-tiered-stopping-rule.md`; the reviewer's default lens is the agent's own.

## Phase 3 — Dispatch: two agents, two contexts, one message

- **Conformance** — `Agent(subagent_type: "touchstone:code-reviewer", description: "conformance", prompt: <conformance injections> + the spec text + the diff)`. Output, one line per AC and per invariant: `<AC-n|INV-n> | covered <test/artifact ref> | unverified <reason or proxy> | violated <finding>`.
- **Quality** — the Phase-1 reviewer, `description: "quality"`, envelope `{task: <full diff>, task_dir: <round dir>, role: "batch-reviewer"}`.

Quality arm fails (`status: failed` / a `fallback_reason`) → fall back to the builder's own vendor with `degraded: true`, `degraded_reason: "vendor: builder=<v> reviewer=<v>"`; that also fails → no review.yaml, surface the failure, stop.

## Phase 4 — Merge into review.yaml, converge, report

Write `<epic-dir>/deliverable-review-<date>/review.yaml` (`gate: deliverable-review`, `target` = the range, `sha` = HEAD; field set `${CLAUDE_PLUGIN_ROOT}/skills/_shared/schemas/review.schema.yaml`): every quality finding with `file` + `line`; every uncovered AC or violated / undecidable invariant as a finding on its field path (`requirements[REQ-n].acs[AC-n]`, `invariants[INV-n]`) with `status: unverified` where the conformance agent could not decide. Provenance fields per `${CLAUDE_PLUGIN_ROOT}/skills/cross-provider-reviewer/references/provenance.md`. Validate with `check-artifact.sh review` (`--root <epic-dir>`; exit 0 required). Raw arm outputs beside it (the artifact list in `pattern-a-base.md`); no other review file.

Critical/High block. Convergence: the injected stopping rule. `degraded: true` → the presentation duty in `provenance.md` (path above), before reporting ready.

Report:

```markdown
## Deliverable review: {range}
**Builder:** {cc|codex}  **Quality reviewer:** {codex|cc}  **Conformance:** cc
verdict: {approve|revise|block} · C={n} H={n} M={n} L={n} · unverified ACs: {list or none}
review.yaml: {path}
```

The human accept that follows this report is the deliverable's one accept.
