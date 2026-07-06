# Pattern-A composite base procedure

The common procedure of the two Pattern-A composites (`cross-provider-reviewer`,
`cross-provider-architect`). The composite's own SKILL.md defines its inputs
envelope, its two dispatch targets, its synthesis rule, and keeps the Codex
probe inline (drift-guarded by `check-foundation-gate-structure.sh`); you — the
session executing the composite — read this file at composite start and follow
everything below.

- **Probe outcome:** `codex_healthy=0` → dispatch the CC arm only and proceed
  to synthesis with `fallback_reason: "codex unavailable"`.
- **Parallel dispatch:** when healthy, issue BOTH `Agent` calls in ONE
  assistant message; wait for both to return before synthesizing.
- **Provenance + banners:** all per
  `skills/cross-provider-reviewer/references/provenance.md` (sole source of
  every field, operation, and banner definition — both composites read that
  SAME reference directly). `builder_vendor` is null (Pattern A has no
  builder). Record `providers_expected`/`providers_used` for this invocation;
  if degraded/partial, build and prepend the banner(s) to the synthesis text
  AND to `review.md`.
- **Artifacts (when `task_dir` given):**
  - `<task_dir>/raw_cc.md` — CC arm output verbatim
  - `<task_dir>/raw_codex.jsonl` — Codex arm output (raw JSONL)
  - `<task_dir>/review.md` — synthesis (banner-prepended when degraded/partial)
  - `<task_dir>/review.result.json` — review-envelope/v1 per provenance.md
- **Failure semantics:** Codex probe/dispatch fail → CC-only synthesis with
  provenance + banner; both arms fail → no synthesis, surface the failure and
  record provenance; skill/framework error → propagate to caller.
- **Return:** the composite's final assistant text is the synthesized
  `review.md` content.
