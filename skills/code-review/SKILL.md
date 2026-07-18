---
name: code-review
description: |
  Use when a logical commit group needs review before merge — cross-vendor batch review: the reviewer is never the vendor that built the code. Out of scope — single-commit ad-hoc review (use Claude Code's built-in `/code-review`) and design-document review (specs / plans / ADRs → `/touchstone:design-review`).
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:code-review — Batch Review

Dispatches a cross-vendor reviewer over a logical commit group and applies its
findings before merge. Never review inline — spawn a separate agent whose
vendor never matches the code's builder.

## Usage

```
/touchstone:code-review [<range>]        # default <main>..HEAD (or <master>..HEAD)
/touchstone:code-review with <codex|cc>  # force reviewer vendor
```

## Phase 1 — Range, governing spec, builder, reviewer

Range: the given argument, else `$(git merge-base HEAD main)..HEAD` (project
CLAUDE.md may override the base branch).

Governing spec (needed for Phase 2's evidence-honesty criteria): resolve the
active epic from `touchstone.yaml` `epics_dir`, or from an `epic`/
`governing_specs` field the caller passed in. Unresolvable → skip to Phase 2's
no-governing-spec path. Otherwise read that epic index, enumerate its
`status: Accepted` specs, carry the path(s) forward as `governing_specs`.

Builder — always detect, even under a forced reviewer (`builder_vendor` must
still be set): `git log --format=%B <range> | grep -iE '^Co-Authored-By:.*(codex|gpt-?5|openai)'`.
Any hit → `builder = codex`; otherwise → `builder = cc` (default). Log the
result so misdetection is visible: "Builder detection: N/M commits tagged
Codex → builder = codex; reviewer swap = CC" (or the inverse). If a Codex agent
built without tagging commits, override with `with cc`.

Reviewer = the vendor opposite `builder` (`touchstone:codex-reviewer` when
`builder = cc`; `touchstone:code-reviewer` when `builder = codex`), unless
`with <vendor>` forces it — force also waives the vendor-correctness check,
never builder detection.

## Phase 2 — Dispatch

Dispatch the resolved reviewer `run_in_background: true` with
`{ task: <full diff>, role: "batch-reviewer", task_dir: <optional> }`.

No `governing_specs` from Phase 1 above → skip the evidence-honesty criteria below,
emit exactly one line, `no governing spec — coverage not audited` — never
silently pass. Otherwise read and inject the following **verbatim** into the
reviewer's `system_prompt` (`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/`,
unconditional, load-and-inject — never restate):

- `live-bearing-predicate.md` + `ac-coverage-honesty-principle.md` — also
  carry as `evidence_honesty_vocab`.
- `design-soundness-honor-check.md` — apply its feedback duty (subject = the
  whole deliverable against the governing spec's depth-stakes REQ set,
  subsystem scope, not per-diff).
- `ac-coverage-criteria.md`, then this delta: for each AC in the spec's
  `Live-bearing AC IDs` declaration, apply the live-bearing predicate's
  evidence rules (static-proxy disqualification, two-part provenance,
  producer ≠ judge) — a static-proxy-only or artifact-less claim blocks the
  same as silent false-green; you authenticate the artifact, never re-run
  the producer.

Diff touches test files → additionally inject the checklist and test-evidence
lens from `references/reviewer-prompts.md` (single canonical home).

## Phase 3 — Fallback and provenance

Single reviewer; no parallel dispatch, no pre-probe of vendor availability —
rely on the reviewer agent's own `status`/`fallback_reason`. Swapped reviewer
returns `status: failed` / a `fallback_reason` (e.g. Codex unavailable) → fall
back to the builder's own vendor. That fallback also fails → `status: failed`,
`providers_used: []`, no banner. `task_dir` supplied but the wrapper returns
with no `review.result.json` written → not accepted regardless of what was
reported; re-dispatch once restating the provenance requirement; still missing
→ the same total-failure terminal state.

Write provenance and any banners per
`skills/cross-provider-reviewer/references/provenance.md` (sole canonical
home — use the full plugin-relative path, not a bare `references/`):
`builder_vendor` = the Phase 1 detection (always set, including under `with`);
`providers_used`/`providers_expected` for this invocation; degraded or partial
→ prepend the banner(s) to the verdict text and to `<task_dir>/review.md`;
write `<task_dir>/review.result.json` (`review-envelope/v1`).

## Phase 4 — Converge, consent, report

Critical/High findings block merge. Convergence: read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md`
and apply it as this gate's stopping rule (single home — do not restate it).

Verdict carries a ⚠️ DEGRADED or ⚠️ PARTIAL banner → present it verbatim to the
user and get explicit acknowledgement (`AskUserQuestion` or an explicit
"proceed") BEFORE reporting the batch as ready to merge — applies even at
Critical+High == 0. A clean, no-banner review triggers nothing.

```markdown
## Batch Review: {range}
**Builder:** {cc|codex}  **Reviewer:** {codex-reviewer|code-reviewer}
| # | Issue | Severity | Action |
|---|---|---|---|
| 1 | ... | Critical | Fixed: ... |
Ready to merge: {yes/no}
```

**Gate stamp:** execute the stamp step in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/gate-stamp.md`, gate-id `code-review-batch`, target = the reviewed range.
