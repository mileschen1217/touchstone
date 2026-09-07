---
name: deliverable-review
description: |
  Use when a finished build (a branch or logical commit group) needs its one review before
  phase-ship; the result feeds the ship informed-accept. Out of scope — single-commit ad-hoc
  review (Claude Code's built-in `/code-review`) and design-document review
  (`/touchstone:design-review`).
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

Apply `../.shared/harness-runtime.md` before any host-dependent operation.

```
/touchstone:deliverable-review [<range>] [with <codex|claude-code>]   # default <main>..HEAD
```

## Phase 1 — Range, governing spec, builder, arms

Vocabulary (**lens**, **arm**) and every review.yaml provenance field this gate writes: `<plugin-root>/skills/.shared/provenance.md`, read once at start. Which fragments compose each lens is declared once in the lens manifest — the assembler (Phase 2) reads it in a subprocess; this session never reads the manifest or the fragments themselves.

Range: the given argument, else `$(git merge-base HEAD main)..HEAD` (project
CLAUDE.md may override the base branch).

Governing spec: the caller's `spec` argument, else the active epic's
`status: accepted` `*.spec.yaml`; the epic dir is `bundle.epics` of
`<plugin-root>/skills/.shared/config-resolver.md` (follow it).
Unresolvable (a direct invocation only — anvil always passes the spec, so its hand-off
to phase-ship always carries a review.yaml) → the conformance and honor-check lenses are
not dispatched; emit exactly one line, `no governing spec — conformance not audited`, run
the quality lens alone, and report its findings in the run message — no review.yaml is
written (the record needs a `target`).

Builder — always detect, even under a forced arm:
`git log --format=%B <range> | grep -iE '^Co-Authored-By:.*(codex|gpt-?5|openai)'`.
Any hit → `builder = codex`; otherwise `builder = claude-code`. Log it:
"Builder detection: N/M commits tagged Codex → builder = codex; quality arm =
claude-code" (or the inverse). If a Codex agent built without tagging commits,
override with `with claude-code`.

The declared lens set (arms column = default configuration; the quality lens's arm set MUST include the vendor opposite `builder` — that is the independence rule, reviewer ≠ builder):

```yaml
lenses:
  - {name: conformance, arms: [claude-code]}
  - {name: honor-check, arms: [claude-code]}
  - {name: quality,     arms: [<vendor opposite builder>]}
```

`with <vendor>` replaces the quality arm set with `[<vendor>]`, never builder detection. When that leaves only the builder's vendor, the round is `degraded: true`, `degraded_reason: "vendor rule waived by \`with <vendor>\`"`.

## Phase 2 — Dispatch: one call per arm, all in one message

Dispatch every arm per the arm-dispatch mechanics in `provenance.md` (Phase 1 read). This gate's deltas: arm labels `conformance-claude-code` / `honor-check-claude-code` / `quality-codex` (or `quality-claude-code` when the builder is codex); round dir = `<epic-dir>/deliverable-review-<date>/`; conformance and honor-check take the spec AND the diff as one subject — `--subject-cmd "cat <spec-path>; git diff <range>"` — while the quality lens's subject is `--subject-cmd "git diff <range>"` alone; role = `batch-reviewer`; findings tagged `[lens: …]`. The conformance arm's output-line format is declared in its assembled lens file, not here.

An external quality arm without its adapter-defined liveness artifacts did not run: omit it and re-dispatch once. If it still fails, re-dispatch through the active harness, record that arm, and set `degraded: true` with `lens quality: independence lost — arm <harness> = builder (<original arm> failed: <reason>)`; that also fails → write no review artifact, surface the failure, and stop.

## Phase 3 — Merge into review.yaml, converge, report

Write `<epic-dir>/deliverable-review-<date>/review.yaml` — `gate: deliverable-review`, `target` = the governing spec file, `range` = the reviewed range, `sha` = HEAD. Field set: `review.schema.yaml` under `<plugin-root>/skills/.shared/schemas/`; field meanings AND the shared merge rules: `provenance.md` (Phase 1). This gate's one merge delta: a conformance line reported `covered` becomes a `coverage[]` row, never a finding; every uncovered AC and every violated / undecidable invariant is a finding on its field path, `status: unverified` where the arm could not decide (naming the proxy).

**Read-back check**: apply `provenance.md` before merging. Missing or partial
read-back writes a degraded round; an unknown fragment id fails the merge and
writes no `review.yaml`.

Validate with `check-artifact.sh review` (`--root <epic-dir>`; exit 0 required). The raw arm outputs sit in the round dir (`raw_cc.md`; a Codex arm's `raw_codex.jsonl` + `last-message.txt`); no other review file.

Critical/High block. Convergence: read `<plugin-root>/skills/.shared/inject/severity-tiered-stopping-rule.md` yourself — that budget stays with this merging session; arms saw only the severity segment. `degraded: true` → the presentation duty in `provenance.md`, before reporting ready.

Report:

```markdown
## Deliverable review: {range}
**Builder:** {claude-code|codex}  **Quality arms:** {codex|claude-code|codex, claude-code}  **Conformance / honor-check arm:** claude-code
verdict: {approve|revise|block} · C={n} H={n} M={n} L={n} · covered: {n} · unverified ACs: {list or none}
review.yaml: {path}
```

The report is an input to phase-ship's informed accept, never an accept of its own.
