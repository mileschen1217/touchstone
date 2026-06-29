---
name: cross-provider-reviewer
description: Pattern A composite skill — reviews any artifact using CC `code-reviewer` + Codex `codex-reviewer` in parallel; synthesizes with explicit divergence labeling. Auto-falls back to CC-only when Codex unavailable. Used by `/touchstone:design-review` (with doc-review `system_prompt` via envelope) and available for ad-hoc cross-provider review.
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:cross-provider-reviewer — Pattern A Composite Skill

Skill body executes in main-thread context where `Agent` tool is available. Orchestrates parallel CC + Codex review and synthesizes with divergence labeling.

## Inputs (JSON envelope as `args`)

```json
{
  "task": "<diff, doc, or artifact text>",
  "task_dir": "<optional: absolute path for artifact write>",
  "system_prompt": "<optional: domain-specific reviewer prompt; default = code-review>",
  "role": "reviewer",
  "timeout_seconds": 900
}
```

## Procedure

### 1. Probe Codex

```bash
codex --version >/dev/null 2>&1 && echo "codex_healthy=1" || echo "codex_healthy=0"
```

### 2. Parallel dispatch (single assistant message, two Agent tool calls)

If `codex_healthy=1`, in ONE message issue BOTH:

- `Agent(subagent_type: "everything-claude-code:code-reviewer", description: "CC review", prompt: <task envelope with system_prompt prefix>, model: "sonnet")`  <!-- # EXTERNAL DEP — everything-claude-code (Epic B vendors this) -->

  The `model: "sonnet"` is explicit, not inherited from ECC's default — m-* family routes review through Sonnet by policy.
- `Agent(subagent_type: "touchstone:codex-reviewer", description: "Codex review", prompt: <task envelope>)`

Wait for both to return before synthesizing.

If `codex_healthy=0`, call only `everything-claude-code:code-reviewer` and proceed to synthesis with `fallback_reason: "codex unavailable"`.

### 3. Synthesis (deterministic)

Sort raw inputs by provider name (`cc` then `codex`).

Merge findings:
- Same file:line + same category → keep one, attribute to both.
- Disagreement on severity → list both verdicts inline; keep higher severity.
- Unique to one provider → include with attribution.

Always emit a `## Divergence` section when verdicts disagree. Never silently merge.

### 4. Compute provenance, prepend banners, write artifacts

All field definitions, the correctness operations, the banner formats/ordering, and
the no-derived-fields rule live SOLELY in `references/provenance.md`. This body gives
only the ACTIONS; it restates none of those definitions.

1. Record `providers_expected` and `providers_used` for THIS invocation per
   provenance.md. `builder_vendor` is null (Pattern A has no builder).
2. Extract `session_id` from `<task_dir>/raw_codex.jsonl` per provenance.md.
3. Determine degraded/partial and, if either holds, build and prepend the banner(s)
   to the synthesis text AND to `review.md`, per provenance.md (which defines the
   banner content and ordering).

Write artifacts (if `task_dir` provided):
- `<task_dir>/raw_cc.md` — CC reviewer output verbatim
- `<task_dir>/raw_codex.jsonl` — Codex reviewer output (raw JSONL)
- `<task_dir>/review.md` — synthesized review (banner-prepended when degraded/partial)
- `<task_dir>/review.result.json` — the review-envelope/v1 artifact, written per
  `references/provenance.md` (sole definition of its fields and the no-derived-fields rule).

### 5. Return synthesized review

Skill body's final assistant text: the synthesized review.md content. The orchestrator caller reads it from shared LLM working memory.

## Synthesis instruction (built-in)

> Merge findings; do not introduce new findings. Preserve provider attribution. Label divergence explicitly. Sort by severity (Critical, High, Medium, Low). Emit raw outputs alongside; never silently merge.

## Failure semantics

- Codex probe / dispatch fail → CC-only synthesis; record provenance + prepend the banner if applicable, per `references/provenance.md`.
- Both reviewers fail → no synthesis; surface as failure and record provenance per `references/provenance.md`.
- Skill itself errors (framework) → propagate to caller.

## Cost note

Pattern A — ~2× tokens per invocation. Only invoked at high-leverage gates: doc review (`/touchstone:design-review`), structural commitment (`/touchstone:keystone`), design spec (`/touchstone:design-spec`), or ad-hoc opt-in for high-risk diffs.

## Metrics capture (owned writer)

Bracket the dispatch and persist it so `scripts/metrics-report.sh` can attribute its cost.
Set `stage` to the ACTUAL calling gate's name (this composite serves several — `design-review`, `keystone`, `design-spec`, or `code-review`) so the by-stage rollup is not misattributed.
Immediately before the parallel Agent calls, capture `started_at`; immediately after all legs return, capture `ended_at`; then call the writer and forward its printed `collection_dir` to the report tool:

stage="<the calling gate: design-review | keystone | design-spec | code-review>"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
...issue the parallel CC + Codex Agent calls, await all legs...
ended_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
collection_dir="/tmp/metrics-${CLAUDE_SESSION_ID:-$$}"
scripts/metrics/persist-dispatch.sh "$raw_codex_path" "$collection_dir" "$stage" "$model" "$started_at" "$ended_at"
# On CC-only fallback (codex_healthy=0): use the --no-codex form:
# scripts/metrics/persist-dispatch.sh --no-codex --fallback-reason "<reason>" "$collection_dir" "$stage" "$model" "$started_at" "$ended_at"

Honest ceiling: SKILL.md is AI-dispatch instruction, not an executable; the static guard proves the wired line is present and uncommented — the strongest offline evidence. Whether the dispatching agent runs it at runtime is an instruction-following property, discharged separately by the writer's own AC-16/17/18 tests.

## Dependencies

- `everything-claude-code:code-reviewer` (ECC, EXTERNAL) — CC review backend. Epic B vendors or makes optional.
- `touchstone:codex-reviewer` (plugin-local) — Codex review backend.
- CC-only fallback: if a provider is absent, run the available provider(s), write `review.result.json` with the resulting `providers_used` / `fallback_reason`, and prepend the DEGRADED banner per `references/provenance.md`; if BOTH absent → no synthesis, surfaced as failure (envelope still written per provenance.md).
