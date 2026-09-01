---
name: deliverable-review
description: |
  Use when a finished build (a branch or logical commit group) needs its one review before phase-ship — three lenses each dispatched to its arms: spec conformance (AC evidence under the live-bearing predicate), the honor-check feedback arm (invariant checks executed), and code quality whose arm set always holds the vendor opposite the builder; one review.yaml, fed to the ship informed-accept. Out of scope — single-commit ad-hoc review (Claude Code's built-in `/code-review`) and design-document review (`/touchstone:design-review`).
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - Agent
user-invocable: false
kind: workflow
---

# /touchstone:deliverable-review

```
/touchstone:deliverable-review [<range>] [with <codex|cc>]   # default <main>..HEAD
```

## Phase 1 — Range, governing spec, builder, arms

Vocabulary (**lens**, **arm**) and every review.yaml provenance field this gate writes: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/provenance.md`, read once at start.

Range: the given argument, else `$(git merge-base HEAD main)..HEAD` (project
CLAUDE.md may override the base branch).

Governing spec: the caller's `spec` argument, else the active epic's
`status: accepted` `*.spec.yaml`; the epic dir is `bundle.epics` of
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` (follow it).
Unresolvable (a direct invocation only — anvil always passes the spec, so its hand-off
to phase-ship always carries a review.yaml) → the conformance and honor-check lenses are
not dispatched; emit exactly one line, `no governing spec — conformance not audited`, run
the quality lens alone, and report its findings in the run message — no review.yaml is
written (the record needs a `target`).

Builder — always detect, even under a forced arm:
`git log --format=%B <range> | grep -iE '^Co-Authored-By:.*(codex|gpt-?5|openai)'`.
Any hit → `builder = codex`; otherwise `builder = cc`. Log it: "Builder detection:
N/M commits tagged Codex → builder = codex; quality arm = cc" (or the inverse).
If a Codex agent built without tagging commits, override with `with cc`.

The declared lens set (arms column = default configuration; the quality lens's arm set MUST include the vendor opposite `builder` — that is the independence rule, reviewer ≠ builder):

```yaml
lenses:
  - {name: conformance, arms: [cc],                       prompt_home: skills/deliverable-review/references/ac-coverage-criteria.md}
  - {name: honor-check, arms: [cc],                       prompt_home: skills/_shared/inject/design-soundness-honor-check.md}
  - {name: quality,     arms: [<vendor opposite builder>], prompt_home: the arm agent's own default lens}
```

`with <vendor>` replaces the quality arm set with `[<vendor>]`, never builder detection. When that leaves only the builder's vendor, the round is `degraded: true`, `degraded_reason: "vendor rule waived by \`with <vendor>\`"`.

## Phase 2 — Inject (once, verbatim, from `${CLAUDE_PLUGIN_ROOT}`)

Conformance lens:
- the two evidence-honesty fragments under `skills/_shared/inject/` (`live-bearing-predicate.md`, `ac-coverage-honesty-principle.md`), also carried as `evidence_honesty_vocab`.
- `skills/deliverable-review/references/ac-coverage-criteria.md` (sole injector), then this delta: an AC with `live_bearing: true` is judged by the predicate's evidence rules; what they disqualify is recorded `unverified` naming the proxy, and the arm authenticates the artifact, never re-runs the producer.
- `skills/deliverable-review/references/reviewer-prompts.md` (sole injector) — always; its rules state their own applicability.

Honor-check lens:
- `skills/_shared/inject/design-soundness-honor-check.md` with `skills/assay/references/arch-rubric.md` injected as content — **feedback arm**: execute every `invariants[].check` against the delivered tree.

Quality lens:
- `skills/_shared/inject/severity-qualification.md`; the arm agent's default lens governs. (The round budget stays host-side — see Phase 4.)

## Phase 3 — Dispatch: one call per arm, all in one message

One `Agent` call per arm, carrying every lens assigned to it (findings tagged `[lens: …]`), all calls in ONE assistant message:

- **cc arm (conformance + honor-check)** — `Agent(subagent_type: "touchstone:code-reviewer", description: "conformance, honor-check", prompt: <both lenses' injections> + the spec text + the diff)`. Conformance output, one line per AC and per invariant: `<AC-n|INV-n> | covered <test/artifact ref> | unverified <reason or proxy> | violated <finding>` — the covered lines become `coverage[]` rows at merge, only unverified / violated lines become findings.
- **quality arm** — `touchstone:codex-reviewer` when the arm is `codex`, `touchstone:code-reviewer` (a fresh context, never the conformance one) when `cc`; `description: "quality"`, envelope `{task: <full diff>, task_dir: <round dir>, role: "batch-reviewer"}`.

The quality arm returns without `raw_codex.jsonl` + `last-message.txt` in the round dir → it was not Codex: record it as a `cc` arm under the liveness rule in `provenance.md`, or re-dispatch once. A quality arm that fails (`status: failed` / a `fallback_reason`) → re-dispatch the lens to the builder's own vendor, record that arm in `providers`, and set `degraded: true`, `degraded_reason: "lens quality: independence lost — arm <vendor> = builder (<original arm> failed: <reason>)"`; that also fails → no review.yaml, surface the failure, stop.

## Phase 4 — Merge into review.yaml, converge, report

Write `<epic-dir>/deliverable-review-<date>/review.yaml` — `gate: deliverable-review`, `target` = the governing spec file, `range` = the reviewed range, `sha` = HEAD. Field set: `review.schema.yaml` under `${CLAUDE_PLUGIN_ROOT}/skills/_shared/schemas/`; field meanings AND the shared merge rules: `provenance.md` (Phase 1). This gate's one merge delta: a conformance line reported `covered` becomes a `coverage[]` row, never a finding; every uncovered AC and every violated / undecidable invariant is a finding on its field path, `status: unverified` where the arm could not decide (naming the proxy).

Validate with `check-artifact.sh review` (`--root <epic-dir>`; exit 0 required). The raw arm outputs sit in the round dir (`raw_cc.md`; a Codex arm's `raw_codex.jsonl` + `last-message.txt`); no other review file.

Critical/High block. Convergence: read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md` yourself — that budget stays with this merging session; arms saw only the severity segment. `degraded: true` → the presentation duty in `provenance.md`, before reporting ready.

Report:

```markdown
## Deliverable review: {range}
**Builder:** {cc|codex}  **Quality arms:** {codex|cc|codex, cc}  **Conformance / honor-check arm:** cc
verdict: {approve|revise|block} · C={n} H={n} M={n} L={n} · covered: {n} · unverified ACs: {list or none}
review.yaml: {path}
```

The report is an input to phase-ship's informed accept, never an accept of its own.
