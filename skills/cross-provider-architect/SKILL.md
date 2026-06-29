---
name: cross-provider-architect
description: Pattern A composite skill — architecture critique using CC `architect` + Codex `codex-adversarial-reviewer` in parallel. CC validates the design; Codex pressure-tests it. Synthesis labels divergence. Auto-falls back to CC-only when Codex unavailable. Used by `/touchstone:keystone` and `/touchstone:design-spec`.
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:cross-provider-architect — Pattern A Composite Skill

Same skill-form Pattern A shape as `touchstone:cross-provider-reviewer`, but pairs CC `architect` with Codex `codex-adversarial-reviewer`. The asymmetry is intentional: CC validates, Codex critiques — different roles within Pattern A.

## Inputs (JSON envelope as `args`)

```json
{
  "task": "<arch proposal, design spec, or tradeoff question>",
  "task_dir": "<optional: absolute path for artifact write>",
  "role": "architect",
  "timeout_seconds": 900
}
```

## Procedure

### 1. Probe Codex (same as touchstone:cross-provider-reviewer)

```bash
codex --version >/dev/null 2>&1 && echo "codex_healthy=1" || echo "codex_healthy=0"
```

### 2. Parallel dispatch (single assistant message, two Agent tool calls)

If `codex_healthy=1`, in ONE message issue BOTH:

- `Agent(subagent_type: "everything-claude-code:architect", description: "CC architect", prompt: <task envelope>, model: "sonnet")`  <!-- # EXTERNAL DEP — everything-claude-code (Epic B vendors this) -->
- `Agent(subagent_type: "touchstone:codex-adversarial-reviewer", description: "Codex adversarial critique", prompt: <task envelope>)`

Wait for both to return before synthesizing.

If `codex_healthy=0`, call only `everything-claude-code:architect` (with `model: "sonnet"`) and proceed to synthesis with `fallback_reason: "codex unavailable"`.

The `model: "sonnet"` override on the CC architect dispatch supersedes the agent's `model: opus` frontmatter — m-* family routes architecture work through Sonnet, not Opus, by policy.

### 3. Synthesis

The two outputs are intentionally different in tone. Synthesis must:
- List the validated design (CC architect) up top
- Append adversarial findings (Codex) as "pressure-test results"
- Cross-reference: when an adversarial finding contradicts a validated decision, flag explicitly
- End with a unified verdict: approve | revise | block — choose the more conservative across both

### 4. Compute provenance, prepend banners, write artifacts

All actions here follow the sole canonical
`skills/cross-provider-reviewer/references/provenance.md` (this composite reads that SAME
reference directly — no copy, no indirection through another skill). `builder_vendor` is
null (Pattern A). Record provenance (`providers_expected`/`providers_used`), extract
`session_id` from `raw_codex.jsonl`, and prepend the banner(s) if degraded/partial — all
per that reference, which holds every field/operation/banner definition.

Write artifacts (if `task_dir` provided):
- `<task_dir>/raw_cc.md` — architect output
- `<task_dir>/raw_codex.jsonl` — adversarial reviewer output (raw JSONL)
- `<task_dir>/review.md` — synthesis (banner-prepended when degraded/partial)
- `<task_dir>/review.result.json` — review-envelope/v1, written per `skills/cross-provider-reviewer/references/provenance.md` (sole definition of its fields and the no-derived-fields rule)

### 5. Return synthesis to caller

Skill body's final assistant text: the synthesized review.md content.

## Failure semantics

- Codex probe / dispatch fail → CC-only synthesis; record provenance + prepend the banner if applicable, per `skills/cross-provider-reviewer/references/provenance.md`.
- Both reviewers fail → no synthesis; surface as failure and record provenance per that reference.
- Skill itself errors (framework) → propagate to caller.
- The review-envelope is written as `review.result.json`, per `skills/cross-provider-reviewer/references/provenance.md` (sole definition of its fields and rules).

## Cost note

Pattern A — ~2× tokens. Reserved for highest-leverage gates: `/touchstone:keystone` and `/touchstone:design-spec` (architect-review stage).

## Metrics capture (owned writer)

Bracket the dispatch and persist it so `scripts/metrics-report.sh` can attribute its cost.
Set `stage` to the ACTUAL calling gate's name (this composite serves `keystone` and `design-spec`) so the by-stage rollup is not misattributed.
Immediately before the parallel Agent calls, capture `started_at`; immediately after all legs return, capture `ended_at`; then call the writer and forward its printed `collection_dir` to the report tool:

stage="<the calling gate: keystone | design-spec>"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
...issue the parallel CC + Codex Agent calls, await all legs...
ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
collection_dir="/tmp/metrics-${CLAUDE_SESSION_ID:-$$}"
scripts/metrics/persist-dispatch.sh "$raw_codex_path" "$collection_dir" "$stage" "$model" "$started_at" "$ended_at"
# On CC-only fallback (codex_healthy=0): use the --no-codex form:
# scripts/metrics/persist-dispatch.sh --no-codex --fallback-reason "<reason>" "$collection_dir" "$stage" "$model" "$started_at" "$ended_at"

Honest ceiling: SKILL.md is AI-dispatch instruction, not an executable; the static guard proves the wired line is present and uncommented — the strongest offline evidence. Whether the dispatching agent runs it at runtime is an instruction-following property, discharged separately by the writer's own end-to-end writer tests.

## Dependencies

- `everything-claude-code:architect` (ECC, EXTERNAL) — CC validation backend. Epic B vendors or makes optional.
- `touchstone:codex-adversarial-reviewer` (plugin-local) — Codex adversarial-critique backend.
- CC-only fallback: if a provider is absent, run the available provider(s), write `review.result.json` with the resulting `providers_used` / `fallback_reason`, and prepend the DEGRADED banner per `skills/cross-provider-reviewer/references/provenance.md`; if BOTH absent → no synthesis, surfaced as failure (envelope still written per that reference).
