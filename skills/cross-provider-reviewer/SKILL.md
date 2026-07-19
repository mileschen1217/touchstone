---
name: cross-provider-reviewer
description: Pattern A composite skill — one composite, two internal roles. `review` runs CC `code-reviewer` + Codex `codex-reviewer` in parallel and synthesizes with explicit divergence labeling; `architecture-critique` sends the same two arms a validation rubric (CC) and an adversarial pressure-test lens (Codex). Auto-falls back to CC-only when Codex unavailable. Callers — `/touchstone:design-review` (doc-review `system_prompt`, internal role `review`), `/touchstone:assay` structural-fork case (internal role `architecture-critique`), and ad-hoc cross-provider review.
allowed-tools:
  - Bash
  - Read
  - Write
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:cross-provider-reviewer — Pattern A Composite Skill

Skill body executes in main-thread context where `Agent` tool is available. Orchestrates parallel CC + Codex scrutiny under one of two internal roles and synthesizes per role. For a routine single-commit review `/touchstone:code-review` is lighter; reach here for a cross-provider gate (design-review), an architecture-critique dispatch (assay structural-fork case), or an ad-hoc cross-provider pass — skip when CC-only suffices. Common procedure (dispatch discipline, provenance, banners, artifacts, failure semantics, return): read `${CLAUDE_PLUGIN_ROOT}/skills/cross-provider-reviewer/references/pattern-a-base.md` at start and follow it — single home, not restated here.

## Dispatch matrix (caller role → internal role)

| Caller-side dispatch | Internal role |
|---|---|
| domain review roles (`design-reviewer`, `batch-reviewer`, `reviewer`, ad-hoc review) | `review` |
| architecture dispatch (assay structural-fork case, tradeoff/design critique) | `architecture-critique` |

## Inputs (JSON envelope as `args`)

```json
{
  "task": "<diff, doc, arch proposal, or artifact text>",
  "task_dir": "<optional: absolute path for artifact write>",
  "system_prompt": "<optional, review role only: domain reviewer lens; default = code review>",
  "role": "<caller role — mapped per the matrix above>",
  "timeout_seconds": 900
}
```

Timeout chain (explicit and single): envelope `timeout_seconds` > the Codex arm's built-in `TIMEOUT` default > that agent file's frontmatter `timeout_seconds` (trailing metadata — never overrides the first two).

## Procedure

### 1. Probe Codex

```bash
codex --version >/dev/null 2>&1 && echo "codex_healthy=1" || echo "codex_healthy=0"
```

### 2. Dispatch targets (per the base procedure's parallel-dispatch rule)

- `Agent(subagent_type: "touchstone:code-reviewer", description: "CC arm", prompt: <task envelope incl. system_prompt>)`
- `Agent(subagent_type: "touchstone:codex-reviewer", description: "Codex arm", prompt: <task envelope incl. system_prompt>)`

**Lens injection — the envelope `system_prompt` is the carrier.** The CC arm accepts a `system_prompt` override by its own agent contract; the Codex arm substitutes the envelope `system_prompt` for its built-in role prompt. Internal role `review` forwards the caller's `system_prompt` (absent → each arm's default reviewer behavior). Internal role `architecture-critique` sends the CC arm the validation rubric below and the Codex arm the adversarial pressure-test prompt below — never the reverse.

The CC arm's `tools` are a static frontmatter union that includes Bash; the critique role's "Bash limited to read-only git inspection" bound is a prompt-level constraint — a per-role capability boundary is mechanically unavailable here, an explicitly accepted residual risk (critique work is read-only by nature; a stray write surfaces in git).

#### CC lens for `architecture-critique` — validation rubric

> You are a software architecture validator. Read-only — never edit files; use Bash only for read-only git inspection. Where the proposal references real code, ground your judgment in it (`file:line`); where it doesn't, judge the proposal's own text. Evaluate the proposal in the envelope (`task`) against:
>
> 1. **Fitness to the stated problem** — does the structure solve the named problem; is any component solving an unstated one?
> 2. **Interface economy and depth** — deep modules behind small interfaces; flag leaked orchestration sequences and state a caller could mis-order.
> 3. **Coupling and cohesion** — name each cross-module dependency the design adds; flag cycles and shared mutable state.
> 4. **Failure modes and operational risk** — what breaks first under load or partial failure, and is that failure observable?
> 5. **Speculative generality** — flag a layer or abstraction with a single caller and no concrete second consumer.
>
> Your role in the composite is validation: state plainly what holds and why, then findings. Return, in order: a validated-design summary; findings sorted by severity (Critical, High, Medium — no style nits), each grounded in the proposal's sections or `file:line`; a one-line verdict: approve | revise | block.

#### Codex lens for `architecture-critique` — adversarial pressure-test

> You are an adversarial architecture / design reviewer. Your job is to pressure-test the proposal: surface failure modes, edge cases, hidden assumptions, scaling cliffs, security exposure, operational risks, and concrete scenarios where the design breaks. Do NOT validate the design — that's the other reviewer's job. Be skeptical, specific, and constructive. Return findings sorted by severity (Critical, High, Medium). For each: scenario, why the design fails, suggested mitigation. End with a one-line verdict: approve | revise | block.

### 3. Synthesis (role-conditional)

**Internal role `review` — deterministic merge.** Sort raw inputs by provider name (`cc` then `codex`). Merge findings — do not introduce new findings:

- Same file:line + same category → keep one, attribute to both.
- Disagreement on severity → list both verdicts inline; keep higher severity.
- Unique to one provider → include with attribution.
- Sort merged findings by severity (Critical, High, Medium, Low).

Always emit a `## Divergence` section when verdicts disagree; emit raw outputs alongside. Never silently merge.

**Internal role `architecture-critique` — validated design first.** The two outputs are intentionally different in tone. Synthesis must:

- List the validated design (CC arm) up top
- Append adversarial findings (Codex arm) as "pressure-test results"
- Cross-reference: when an adversarial finding contradicts a validated decision, flag explicitly
- End with a unified verdict: approve | revise | block — choose the more conservative across both

### 4. Fallback semantics (per role)

| Failure | Internal role `review` | Internal role `architecture-critique` |
|---|---|---|
| Codex probe fails | CC-only review + ⚠️ DEGRADED banner | CC validation-only + ⚠️ DEGRADED — CC SHALL NOT stand in to produce the adversarial critique |
| Codex dispatch fails | CC-only review; DEGRADED banner prepended | CC validation-only; DEGRADED; no CC-authored critique |
| Codex timeout after green probe | falls back to CC-only review under a DEGRADED banner | CC validation-only, DEGRADED; the adversarial half stays absent |
| Codex partial output | synthesize both arms; prepend ⚠️ PARTIAL banner (`status: partial`) | synthesize; pressure-test section under ⚠️ PARTIAL banner (`status: partial`) |
| Both arms fail | `status: failed`, `providers_used: []`, no banner varnish (total-failure semantics, as code-review Phase 3) | `status: failed`, `providers_used: []`, no banner varnish |

### 5. Provenance, banners, artifacts, return

Per the base procedure file read at start (which defers field/banner definitions to `${CLAUDE_PLUGIN_ROOT}/skills/cross-provider-reviewer/references/provenance.md`, the sole source).

## Dependencies

- `touchstone:code-reviewer` (plugin-local, vendored) — CC arm, both internal roles.
- `touchstone:codex-reviewer` (plugin-local) — Codex arm, both internal roles.
