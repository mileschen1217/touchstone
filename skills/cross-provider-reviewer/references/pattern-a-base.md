# Pattern-A composite base procedure

The common dispatch/provenance procedure of `cross-provider-reviewer`'s two
internal roles (`review`, `architecture-critique`).

- **Probe outcome:** `codex_healthy=0` → dispatch the CC arm only and proceed
  to synthesis with `degraded_reason: "codex unavailable"` (per-role degraded
  semantics: SKILL.md fallback table).
- **Parallel dispatch:** when healthy, issue BOTH `Agent` calls in ONE
  assistant message; wait for both to return before synthesizing.
- **Provenance:** fields and the presentation duty per
  `skills/cross-provider-reviewer/references/provenance.md` (sole source).
- **Artifacts (when `task_dir` given):**
  - `<task_dir>/raw_cc.md` — CC arm output verbatim
  - `<task_dir>/raw_codex.jsonl` — Codex arm event stream (raw JSONL)
  - `<task_dir>/last-message.txt` — Codex arm `-o` result file (success-path content)
  - `<task_dir>/review.yaml` — the synthesis as fields (`skills/_shared/schemas/review.schema.yaml`); an ad-hoc invocation with no gate uses `gate: deliverable-review`
- **Framework error:** propagate to caller.
- **Return:** the composite's final assistant text is the verdict line, the
  counts, and the findings of `review.yaml`.
