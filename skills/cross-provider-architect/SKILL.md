---
name: cross-provider-architect
description: Pattern A composite skill — architecture critique using CC `architect` + Codex `codex-adversarial-reviewer` in parallel. CC validates the design; Codex pressure-tests it. Synthesis labels divergence. Auto-falls back to CC-only when Codex unavailable. Used by `/touchstone:assay` (structural-fork case) and `/touchstone:design-spec`.
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:cross-provider-architect — Pattern A Composite Skill

Same skill-form Pattern A shape as `touchstone:cross-provider-reviewer`, but pairs CC `architect` with Codex `codex-adversarial-reviewer`. The asymmetry is intentional: CC validates, Codex critiques — different roles within Pattern A. Reserved for high-leverage architecture gates (assay's structural-fork case, design-spec) — skip for routine code review (use `/touchstone:code-review`) or single-provider checks. Common procedure (dispatch discipline, provenance, banners, artifacts, failure semantics, return): read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/pattern-a-base.md` at start and follow it — single home, not restated here.

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

### 1. Probe Codex

```bash
codex --version >/dev/null 2>&1 && echo "codex_healthy=1" || echo "codex_healthy=0"
```

### 2. Dispatch targets (per the base procedure's parallel-dispatch rule)

- `Agent(subagent_type: "touchstone:architect", description: "CC architect", prompt: <task envelope>)`
- `Agent(subagent_type: "touchstone:codex-adversarial-reviewer", description: "Codex adversarial critique", prompt: <task envelope>)`

### 3. Synthesis

The two outputs are intentionally different in tone. Synthesis must:
- List the validated design (CC architect) up top
- Append adversarial findings (Codex) as "pressure-test results"
- Cross-reference: when an adversarial finding contradicts a validated decision, flag explicitly
- End with a unified verdict: approve | revise | block — choose the more conservative across both

### 4. Provenance, banners, artifacts, return

Per `skills/_shared/pattern-a-base.md`. Architect-specific artifact naming: `raw_cc.md` carries the architect output; `raw_codex.jsonl` the adversarial critique.

## Dependencies

- `touchstone:architect` (plugin-local, vendored) — CC validation backend; reserved for the highest-leverage gates (`/touchstone:assay` structural-fork case, `/touchstone:design-spec`).
- `touchstone:codex-adversarial-reviewer` (plugin-local) — Codex adversarial-critique backend.
