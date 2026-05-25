---
name: cross-provider-reviewer
description: Pattern A composite skill — reviews any artifact using CC `code-reviewer` + Codex `codex-reviewer` in parallel; synthesizes with explicit divergence labeling. Auto-falls back to CC-only when Codex unavailable. Used by `/m-workflow:design-review` (with doc-review `system_prompt` via envelope) and available for ad-hoc cross-provider review.
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
user-invocable: true
kind: workflow
---

# /m-workflow:cross-provider-reviewer — Pattern A Composite Skill

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
- `Agent(subagent_type: "m-workflow:codex-reviewer", description: "Codex review", prompt: <task envelope>)`

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

Compute the dispatch provenance per `references/provenance.md` (the sole canonical
home of the schema, the 5 operations, and both banner formats):

1. Set `providers_expected`: default `["cc","codex"]`; if a `with X` modifier was
   passed in the envelope, `["X"]` and `force_reviewer = true` (else false).
2. Set `providers_used`: the vendors that actually returned review content (`"cc"`
   if the ECC reviewer returned, `"codex"` if the codex leg returned). `builder_vendor`
   is null (Pattern A has no builder).
3. Extract `session_id` from `<task_dir>/raw_codex.jsonl` per provenance.md's
   session_id-extraction recipe (null if codex did not run or no id found).
4. Compute `quantity_correct`, `vendor_correct`, `degraded` (Operations 1–3).
   If `degraded`, build the DEGRADED banner (Operation 4).
5. If `status == "partial"` (codex leg unreliable, e.g. >5 malformed JSONL lines),
   build the PARTIAL banner (Operation 5). When both fire, DEGRADED first, PARTIAL second.
6. Prepend the banner(s) (if any) to the synthesis text AND to `review.md`,
   followed by a blank line, then the review body.

Write artifacts (if `task_dir` provided):
- `<task_dir>/raw_cc.md` — CC reviewer output verbatim
- `<task_dir>/raw_codex.jsonl` — Codex reviewer output (raw JSONL)
- `<task_dir>/review.md` — synthesized review (banner-prepended when degraded/partial)
- `<task_dir>/review.result.json` — the review-envelope/v1 artifact. Field list,
  types, and the no-derived-fields rule are defined SOLELY in `references/provenance.md`
  (this body restates none of it). Derived fields (`quantity_correct`, `vendor_correct`,
  `degraded`) are NEVER written.

### 5. Return synthesized review

Skill body's final assistant text: the synthesized review.md content. The orchestrator caller reads it from shared LLM working memory.

## Synthesis instruction (built-in)

> Merge findings; do not introduce new findings. Preserve provider attribution. Label divergence explicitly. Sort by severity (Critical, High, Medium, Low). Emit raw outputs alongside; never silently merge.

## Failure semantics

- Codex probe / dispatch fail → CC-only synthesis with `fallback_reason`; `providers_used = ["cc"]`; `status: ok`; DEGRADED banner (quantity+vendor incorrect).
- Both reviewers fail → `status: failed`, both errors in `risks[]`, `providers_used = []`, `providers_expected` still recorded, no synthesis, NO banner (compute_degraded's non-empty guard).
- Skill itself errors (framework) → propagate to caller.
- All correctness/banner rules are defined in `references/provenance.md`.

## Cost note

Pattern A — ~2× tokens per invocation. Only invoked at high-leverage gates: doc review (`/m-workflow:design-review`), arch consult (`/m-workflow:arch-review`), design spec (`/m-workflow:design-spec`), or ad-hoc opt-in for high-risk diffs.

## Dependencies

- `everything-claude-code:code-reviewer` (ECC, EXTERNAL) — CC review backend. Epic B vendors or makes optional.
- `m-workflow:codex-reviewer` (plugin-local) — Codex review backend.
- CC-only fallback: if ECC absent, run available provider(s) only + emit synthesis with a `fallback_reason` note; if BOTH absent → no synthesis, surfaced as failure. (Loud-degraded metadata deferred to E14.)
