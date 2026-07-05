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

- `Agent(subagent_type: "touchstone:codex-reviewer", description: "Codex review", prompt: <task envelope>)`

Wait for both to return before synthesizing.

If `codex_healthy=0`, call only `everything-claude-code:code-reviewer` and proceed to synthesis with `fallback_reason: "codex unavailable"`.

### 3. Synthesis (deterministic)

Sort raw inputs by provider name (`cc` then `codex`).

Merge findings — do not introduce new findings:
- Same file:line + same category → keep one, attribute to both.
- Disagreement on severity → list both verdicts inline; keep higher severity.
- Unique to one provider → include with attribution.
- Sort merged findings by severity (Critical, High, Medium, Low).

Always emit a `## Divergence` section when verdicts disagree; emit raw outputs
alongside. Never silently merge.

### 4. Compute provenance, prepend banners, write artifacts

Field definitions, correctness operations, banner formats/ordering, and the
no-derived-fields rule: `references/provenance.md` (sole source).

1. Record `providers_expected` and `providers_used` for THIS invocation per
   provenance.md. `builder_vendor` is null (Pattern A has no builder).
2. Determine degraded/partial and, if either holds, build and prepend the banner(s)
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

## Failure semantics

- Codex probe / dispatch fail → CC-only synthesis; record provenance + prepend the banner if applicable, per `references/provenance.md`.
- Both reviewers fail → no synthesis; surface as failure and record provenance per `references/provenance.md`.
- Skill itself errors (framework) → propagate to caller.

## Dependencies

- `everything-claude-code:code-reviewer` (ECC, EXTERNAL) — CC review backend; invoked at the high-leverage gates only (design-review / structural commitment (`/touchstone:assay` fork case) / design-spec).
- `touchstone:codex-reviewer` (plugin-local) — Codex review backend.
