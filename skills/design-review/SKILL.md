---
name: design-review
kind: workflow
description: Reviews authored design documents (spec, plan, ADR) before Build using Pattern A (dual parallel). Dispatches `touchstone:cross-provider-reviewer` composite skill with a doc-review system prompt set via task envelope. Out of scope — research notes, READMEs, retros, daily notes.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
user-invocable: true
---

# /touchstone:design-review — Design Document Review (Pattern A)

Reviews captured design artifacts before Build. The Stage 0 gate of the Review Gate.

## When to Invoke

Required when any of:
- A spec is authored by `/touchstone:design-spec` and ready for review
- A plan is authored by `/superpowers:writing-plans` and ready for review
- An ADR is authored and introduces a new contract
Out of scope — return "not in scope; this skill reviews specs / plans / ADRs only" and exit:
- Research notes, daily notes, MOCs, retros, READMEs, kb articles

## Relationship to /touchstone:design-spec (this is the gate; its Step-5 review is not)

`/touchstone:design-spec` runs its own architect critique while drafting (its "Step-5 review"). That is **not** this gate — it is an author-time, advisory, skippable (`quick`) pass that judges the freshly-drafted spec. **This skill is the design-review gate**: C+H tiered (see §4), it blocks Build, and it judges the **final, human-accepted** artifact. The two are separated by the human accept step:

```
/touchstone:design-spec  →  Status: Draft  →  human edits / accepts ★  →  /touchstone:design-review (here)
```

`/touchstone:design-spec`'s Step-5 review **never discharges this gate** — they are different reviews with different criteria. Step-5 dispatches the **architect** composite (`cross-provider-architect`: CC `architect` + Codex adversarial) for a *structural, advisory* critique; this gate dispatches the **reviewer** composite (`cross-provider-reviewer`) with the **doc-review prompt** (Problem/Scope/AC/Interfaces + the Verification-Strategy / live-bearing declaration), C+H-tiered and Build-blocking. Step-5's `approve|revise|block` is **not** the gate's doc-review C+H currency, so a spec can pass the architect critique while its Verification-Strategy is never audited — claiming "gate passed" from a Step-5 verdict asserts a property a different check produced. Always run this gate on the **final, human-accepted** artifact; never treat "design-spec was run" as "the gate passed". (Rationale: ADR-0015.)

## Procedure

### 0. Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, also read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` AND
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/standing-vs-transient-bridge.md`
and load both into context for the envelope below.

When dispatching to `touchstone:cross-provider-reviewer`, include in envelope:

```json
{
  "task": "<existing>",
  "system_prompt": "<existing + loaded CONTEXT.md sections verbatim>",
  "discipline_mode": "source-as-truth",
  "source_as_truth_vocab": "<verbatim loaded text>",
  "role": "design-reviewer"
}
```

If not adopted: skip Read; envelope `discipline_mode: "none"`; omit `source_as_truth_vocab`.

The Bridge content audit (P1/P2/P3 application) and Standing vs transient classification procedures stay in this skill — they are the actions; the inject fragments provide the vocabulary they reference.

**Always (Baseline/spine — unconditional).** Independently of `source-as-truth`, read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/live-bearing-predicate.md` AND
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/ac-coverage-honesty-principle.md`
and inject them into the reviewer envelope: append to the doc-review `system_prompt`
(§3 below) AND carry as `evidence_honesty_vocab`. This is spine, not a discipline: it
fires regardless of which disciplines are adopted (do NOT gate it on `source-as-truth`).
Item 7 of the doc-review prompt applies this injected doctrine as its feedforward
(declaration) stage. Also inject `ground-and-sweep.md` per the feedback arm section below.

### 1. Validate input scope

Read the target file(s). Check frontmatter `type:` field if present, or path:
- `type: spec` OR path matches `**/specs/**` → in scope (use spec/plan/ADR system prompt)
- `type: plan` OR path matches `**/plans/**` → in scope (use spec/plan/ADR system prompt)
- `type: adr` OR path matches `**/adr/**` → in scope (use spec/plan/ADR system prompt)
- Anything else → out of scope; exit gracefully.

### 1.5. Pre-check (specs only — deterministic structural + challenge-result gate)

For `type: spec` targets (path matches `**/specs/**` or frontmatter `type: spec`), run the deterministic pre-check before dispatching reviewers if it exists:

```bash
bash scripts/design-review-precheck.sh <spec-path>
```

Run `bash scripts/design-review-precheck.sh <spec-path>` if it exists; if the script is absent, skip this step and proceed to Step 2 (degrade gracefully — do not hard-block when the script is not present in the consumer project).

Interpret the result:

- **Exit non-zero** (`BLOCK:` line in output) — surface the full BLOCK output verbatim to the user and **do not dispatch reviewers**. Build does not proceed until the human resolves the block (fixes the structural violation, runs the challenge-pass, resolves stale digests, etc.).
- **Exit zero** (`PRE-CHECK OK → dispatch` or `PRE-CHECK skipped: draft`) — proceed to Step 2 below.

For non-spec targets (`type: plan`, `type: adr`), skip this step and proceed directly to Step 2.

### 2. Dispatch touchstone:cross-provider-reviewer (Pattern A)

```
Skill(skill: "touchstone:cross-provider-reviewer", args: {
  "task": "<full text of the doc being reviewed>",
  "system_prompt": "<doc-review prompt below>",
  "role": "design-reviewer",
  "task_dir": "<optional: from caller context>"
})
```

### 3. Doc-review system prompt

**For spec / plan / ADR:**

> You are reviewing an authored design document (spec, plan, or ADR). Check:
> 1. Problem / Scope / Non-goals are concrete and falsifiable
> 2. Acceptance Criteria cover happy path, error paths, boundaries
> 3. Interfaces / Contracts are specific (field names, types, error returns)
> 4. Error Handling rows map to scenarios
> 5. Invariants are cross-cutting rules
> 6. Risks / Open Questions are not hidden
> 7. Verification Strategy declaration (evidence-honesty gate, Stage 0). This is the
>    **feedforward / DECLARATION** application of the injected evidence-honesty doctrine
>    (the **live-bearing predicate** + **AC-coverage-honesty principle**, loaded from
>    `skills/_shared/inject/live-bearing-predicate.md` + `skills/_shared/inject/ac-coverage-honesty-principle.md`
>    and injected per Step 0). No test source
>    exists yet, so this is a DECLARATION check, never a coverage read: confirm the spec
>    has a non-empty `## Verification Strategy` section, and that every live-bearing AC id
>    (per the injected predicate) appears in its `Live-bearing AC IDs`. Surface a
>    missing/empty section or an omitted live-bearing AC as a finding. Spec-internal
>    judgment only — do NOT read test source or judge per-AC coverage (those belong to
>    code-review batch / epic-close).
>
> Return findings sorted by severity (Critical, High, Medium, Low). Each finding cites the section and a concrete fix. End with verdict: approve | revise | block.

### 4. Apply findings

Quality gate (sums findings across reviewers):

- **C+H ≥ 5** → mandatory second-pass review. After applying fixes inline, re-invoke `/touchstone:design-review <path>`. Build is blocked until a subsequent run returns **C+H = 0** (or only Medium/Low remain). The caller MUST run the second pass; do not skip on user discretion.
- **1 ≤ C+H < 5** → surface findings; block Build until Critical+High are resolved. Single-pass fix is sufficient; second pass optional.
- **C+H = 0, only Medium / Low** → surface findings; allow Build to proceed at user's discretion.

**Informed-consent checkpoint (orthogonal to the C+H gate):** if the composite's
returned synthesis carries a ⚠️ DEGRADED or ⚠️ PARTIAL banner, present the banner
text to the user VERBATIM and obtain explicit acknowledgement (an `AskUserQuestion`
choice, or an explicit user "proceed") BEFORE allowing Build to proceed. This applies
even when C+H == 0 — the banner is informational, not a hard block, but the workflow
MUST NOT auto-advance past it without the human knowingly acknowledging. A clean
review (no banner) does not trigger this checkpoint. The banner's meaning is defined
in `skills/cross-provider-reviewer/references/provenance.md`.

In all cases: do not auto-promote spec status; the user (or caller skill) decides when to proceed.

## Ground-and-Sweep (feedback arm — review / feedback path only)

**Injection scope:** this block fires on the review / feedback path only (INV-NO-SILENT-PATH).
It does NOT apply to the design-spec feedforward arm or any other path.

Read `skills/_shared/ground-and-sweep.md` and inject it verbatim into the reviewer
envelope (append to `system_prompt`, alongside the injected `live-bearing-predicate.md` content)
so the cold reviewer applies sweep-to-dry over the AC's true subject. The injected fragment
carries the shared saturation definition and scope-resolution rule — do not restate them here.

**feedback wrapper (per-arm delta only):**
- **feedback unit identity:** each *emitted finding* (not each AC) must be grounded in concrete
  repo facts: file path, line number, field value, or AC-id. A generic assertion
  ("the code has issues") fails ground-before-assert.
- **feedback saturation delta:** saturation on the feedback arm = a full review pass over the AC's
  true subject surfaces nothing new. The verbatim-injected `ground-and-sweep.md` defines
  the shared saturation criterion and scope-resolution rule; apply them here.

## Related

- Pattern + maintainer notes (invocation, history): `README.md`.
