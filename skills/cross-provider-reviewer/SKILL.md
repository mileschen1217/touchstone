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

Skill body executes in main-thread context where `Agent` tool is available. Orchestrates parallel CC + Codex review and synthesizes with divergence labeling. For a routine single-commit review `/touchstone:code-review` is lighter; reach here for a cross-provider gate (design-review) or an ad-hoc cross-provider pass, and skip when CC-only suffices. Common procedure (dispatch discipline, provenance, banners, artifacts, failure semantics, return): read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/pattern-a-base.md` at start and follow it — single home, not restated here.

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

### 2. Dispatch targets (per the base procedure's parallel-dispatch rule)

- `Agent(subagent_type: "touchstone:code-reviewer", description: "CC review", prompt: <task envelope with system_prompt prefix>)`
- `Agent(subagent_type: "touchstone:codex-reviewer", description: "Codex review", prompt: <task envelope>)`

**Witness requirement (both dispatches inherit it — design-review and anvil route
through here).** Read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/reviewer-witness-lines.md` and inject
it into the reviewer envelope (append to `system_prompt`): the verdict MUST carry
the fragment's READ/RUN witness lines. At intake, reject a verdict lacking them
before acting on its findings — run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-witness-lines.sh" <verdict-file>`
(presence + format; ≥1 READ floor). A fabricated witness voids the verdict per the
fragment's fabrication-consequence clause (one re-dispatch, incident logged;
second fabrication → the stopping rule's blocked path).

### 3. Synthesis (deterministic)

Sort raw inputs by provider name (`cc` then `codex`).

Merge findings — do not introduce new findings:
- Same file:line + same category → keep one, attribute to both.
- Disagreement on severity → list both verdicts inline; keep higher severity.
- Unique to one provider → include with attribution.
- Sort merged findings by severity (Critical, High, Medium, Low).

Always emit a `## Divergence` section when verdicts disagree; emit raw outputs
alongside. Never silently merge.

### 4. Provenance, banners, artifacts, return

Per `skills/_shared/pattern-a-base.md` (which defers field/banner definitions to
`references/provenance.md`, the sole source).

## Dependencies

- `touchstone:code-reviewer` (plugin-local, vendored) — CC review backend; invoked at the high-leverage gates only (design-review / structural commitment (`/touchstone:assay` fork case) / design-spec).
- `touchstone:codex-reviewer` (plugin-local) — Codex review backend.
