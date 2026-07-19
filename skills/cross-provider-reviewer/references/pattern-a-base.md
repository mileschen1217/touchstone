# Pattern-A composite base procedure

The common dispatch/provenance procedure of `cross-provider-reviewer`'s two
internal roles (`review`, `architecture-critique`). The SKILL.md defines the
inputs envelope, the dispatch matrix, the two dispatch targets, the per-role
lenses, synthesis rules, and fallback table, and keeps the Codex probe inline;
you — the session executing the composite — read this file at composite start
and follow everything below.

- **Probe outcome:** `codex_healthy=0` → dispatch the CC arm only and proceed
  to synthesis with `fallback_reason: "codex unavailable"` (per-role degraded
  semantics: SKILL.md fallback table).
- **Parallel dispatch:** when healthy, issue BOTH `Agent` calls in ONE
  assistant message; wait for both to return before synthesizing.
- **Provenance + banners:** all per
  `skills/cross-provider-reviewer/references/provenance.md` (sole source of
  every field, operation, and banner definition). `builder_vendor` is null
  (Pattern A has no builder). Record `providers_expected`/`providers_used` for
  this invocation; if degraded/partial, build and prepend the banner(s) to the
  synthesis text AND to `review.md`.
- **Artifacts (when `task_dir` given):**
  - `<task_dir>/raw_cc.md` — CC arm output verbatim
  - `<task_dir>/raw_codex.jsonl` — Codex arm event stream (raw JSONL)
  - `<task_dir>/last-message.txt` — Codex arm `-o` result file (success-path content)
  - `<task_dir>/review.md` — synthesis (banner-prepended when degraded/partial)
  - `<task_dir>/review.result.json` — review-envelope/v1 per provenance.md
- **Failure semantics:** Codex probe/dispatch fail → CC-only synthesis with
  provenance + banner; both arms fail → no synthesis, surface the failure and
  record provenance; skill/framework error → propagate to caller.
- **Return:** the composite's final assistant text is the synthesized
  `review.md` content.
