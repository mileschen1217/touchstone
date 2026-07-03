---
name: design-review
kind: workflow
description: Reviews authored design documents (spec, plan, ADR) before Build using dual cross-provider review (Pattern A). Dispatches `touchstone:cross-provider-reviewer` composite skill with a doc-review system prompt set via task envelope. Out of scope — anything that is not a contract-bearing design document (spec / plan / ADR).
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
user-invocable: true
---

# /touchstone:design-review — Design Document Review

Reviews captured design artifacts before Build. The Stage 0 gate of the Review Gate.

## Input scope

Required when any of:
- A spec is at `status: accepted-candidate` (crucible pre-accept path) or `status: accepted` (standalone re-review)
- A plan is authored by `/superpowers:writing-plans` and ready for review
- An ADR is authored and introduces a new contract
Out of scope — return "not in scope; this skill reviews specs / plans / ADRs only" and exit:
- Anything that is not a contract-bearing design document (spec / plan / ADR) (e.g. a research note)

## When to Invoke (lifecycle)

This skill reviews an **`accepted-candidate`** before crucible's accept (an already-`accepted` artifact stays valid for standalone re-review). crucible writes `status: accepted-candidate` on the spec, then invokes this gate; the terminal human-accept step in crucible promotes `accepted-candidate → accepted` only after a clean design-review (C+H = 0). A `draft` spec is not gated here (the pre-check skips it).

## Relationship to /touchstone:design-spec — this is the only design gate

`design-spec` is **pure authoring**: it emits a `Draft` and runs no review of its own (there is no separate author-time architect critique). This skill is the **single consolidated design-review gate** — it reviews an **`accepted-candidate`** before crucible's terminal human-accept, dispatches the `reviewer` composite with the doc-review prompt applying BOTH lens-sets (**design-soundness ∪ verification-honesty** — the union; passing one lens never discharges the other), and is C+H-tiered — at C+H ≥ 1 the caller withholds Build per § Apply findings (an instruction the caller follows, not a hook-enforced stop). Never treat "design-spec was run" as "this gate passed".

## Procedure

### Load vocabulary

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
("Doc-review prompt" below) AND carry as `evidence_honesty_vocab`. This is spine, not a discipline: it
fires regardless of which disciplines are adopted (do NOT gate it on `source-as-truth`).
Item 7 of the doc-review prompt applies this injected doctrine as its feedforward
(declaration) stage. Also inject `ground-and-sweep.md` per the feedback arm section below.

**Design-soundness fragment (unconditional — FF arm).** Read and inject verbatim
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/design-soundness-honor-check.md`
into the doc-review `system_prompt` (prepend before the doc-review prompt block below).
This is the **feedforward arm** of the design-soundness lens: the cold reviewer applies
the feedforward duty (depth-stakes test + descriptive-only detection on the spec document),
not the feedback duty (code vs spec, which lives at the deliverable-review surfaces).
Single home: load by path, never restate the body inline.

### Validate input scope

Read the target file(s). Check frontmatter `type:` field if present, or path:
- `type: spec` OR path matches `**/specs/**` → in scope (use spec/plan/ADR system prompt)
- `type: plan` OR path matches `**/plans/**` → in scope (use spec/plan/ADR system prompt)
- `type: adr` OR path matches `**/adr/**` → in scope (use spec/plan/ADR system prompt)
- Anything else → out of scope; exit gracefully.

### Pre-check (specs only — deterministic structural + challenge-result gate)

For `type: spec` targets (path matches `**/specs/**` or frontmatter `type: spec`), run the deterministic pre-check before dispatching reviewers if it exists:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
```

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>` if it exists; if the script is absent, skip this step and proceed to "Dispatch the reviewer" (degrade gracefully — do not hard-block when the script is not present).

Also run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-design-soundness-refs.sh" <spec-path>` if it exists; if absent, skip (degrade gracefully). A non-zero exit means the spec declares an Architecture commitment but a named consumer file lacks the required inject-fragment reference — surface the `BLOCK:` line verbatim and do not dispatch reviewers until the consumer wires the fragment.

Interpret the result:

- **Exit non-zero** (`BLOCK:` line in output) — surface the full BLOCK output verbatim to the user and **do not dispatch reviewers**. Build does not proceed until the human resolves the block (fixes the structural violation, runs the challenge-pass, resolves stale digests, etc.).
- **Exit zero** (`PRE-CHECK OK → dispatch` or `PRE-CHECK skipped: draft`) — proceed to "Dispatch the reviewer" below.

For non-spec targets (`type: plan`, `type: adr`), skip this step and proceed directly to "Dispatch the reviewer".

### Dispatch the reviewer

```
Skill(skill: "touchstone:cross-provider-reviewer", args: {
  "task": "<full text of the doc being reviewed>",
  "system_prompt": "<doc-review prompt below>",
  "role": "design-reviewer",
  "task_dir": "<optional: from caller context>"
})
```

### Doc-review prompt

**For spec / plan / ADR:**

> You are reviewing an authored design document (spec, plan, or ADR). Apply TWO lens-sets (UNION, not substitution): **(i) design-soundness** and **(ii) verification-honesty**. Passing one lens **NEVER** discharges the other.
>
> **Design-soundness lens — feedforward arm (FF):** apply the feedforward duty from
> the design-soundness fragment injected verbatim above (subject = the spec document,
> not code). Additionally assess structural validity, unhandled failure modes, and
> missed edge cases against the architecture rubric.
>
> Check (verification-honesty lens):
> 1. Problem / Scope / Non-goals are concrete and falsifiable
> 2. Requirement→AC completeness (a dedicated pass on coverage DIRECTION): for
>    EACH requirement, enumerate the behaviours a user would recognize as "this
>    requirement working" — happy path, error paths, boundaries — and check each
>    behaviour has an AC witnessing it. Flag every requirement whose AC set
>    witnesses only the happy path. This pass hunts ACs that do NOT exist;
>    critiquing the ACs that do exist is the other checks' job.
> 3. Interfaces / Contracts are specific (field names, types, error returns)
> 4. Error Handling rows map to scenarios
> 5. Invariants are cross-cutting rules
> 6. Risks / Open Questions are not hidden
> 7. Verification Strategy declaration (evidence-honesty gate, Stage 0). This is the
>    **feedforward / DECLARATION** application of the injected evidence-honesty doctrine
>    (the **live-bearing predicate** + **AC-coverage-honesty principle**, loaded from
>    `skills/_shared/inject/live-bearing-predicate.md` + `skills/_shared/inject/ac-coverage-honesty-principle.md`
>    and injected in the Load-vocabulary phase). No test source
>    exists yet, so this is a DECLARATION check, never a coverage read: confirm the spec
>    has a non-empty `## Verification Strategy` section, and that every live-bearing AC id
>    (per the injected predicate) appears in its `Live-bearing AC IDs`. Surface a
>    missing/empty section or an omitted live-bearing AC as a finding. Spec-internal
>    judgment only — do NOT read test source or judge per-AC coverage (those belong to
>    code-review batch / epic-close).
>
> Tag each finding `[lens: design-soundness]` or `[lens: verification-honesty]` so an auditor can count per-lens without re-running (a zero-finding lens must be visibly stated as zero, not hidden).
>
> Return findings sorted by severity (Critical, High, Medium, Low). Each finding cites the section and a concrete fix. End with verdict: approve | revise | block.
>
> End your output with the machine-readable sentinel line:
> `STAGE-REVIEW-SUMMARY: critical=<n> high=<n> degraded=<true|false>`
> (`degraded` computed per `cross-provider-reviewer/references/provenance.md` Operation 3 — anvil's `normalize-stage-return.sh` greps it.)

### Apply findings

Quality gate (sums findings across reviewers):

- **C+H ≥ 5** → mandatory second-pass review. After applying fixes inline, re-invoke `/touchstone:design-review <path>`. Do not proceed to Build until a subsequent run returns **C+H = 0** (or only Medium/Low remain). The caller MUST run the second pass; do not skip on user discretion.
- **1 ≤ C+H < 5** → surface findings; do not proceed to Build until Critical+High are resolved. Single-pass fix is sufficient; second pass optional.
- **C+H = 0, only Medium / Low** → surface findings; allow Build to proceed at user's discretion.

**Informed-consent checkpoint (orthogonal to the C+H gate):** if the composite's
returned synthesis carries a ⚠️ DEGRADED or ⚠️ PARTIAL banner, present the banner
text to the user VERBATIM and obtain explicit acknowledgement (an `AskUserQuestion`
choice, or an explicit user "proceed") BEFORE allowing Build to proceed. This applies
even when C+H == 0 — the banner is informational, not a hard block, but you (the
caller) MUST NOT advance past it without the human knowingly acknowledging. A clean
review (no banner) does not trigger this checkpoint. The banner's meaning is defined
in `${CLAUDE_PLUGIN_ROOT}/skills/cross-provider-reviewer/references/provenance.md`.

In all cases: do not auto-promote spec status; the user (or caller skill) decides when to proceed.

## Ground-and-Sweep (feedback arm — review / feedback path only)

**Injection scope:** this block fires on the review / feedback path only (INV-NO-SILENT-PATH).
It does NOT apply to the design-spec feedforward arm or any other path.

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/ground-and-sweep.md` and inject it verbatim into the reviewer
envelope (append to `system_prompt`, alongside the injected `live-bearing-predicate.md` content)
so the cold reviewer applies sweep-to-dry over the AC's true subject. The injected fragment
carries the shared saturation definition and scope-resolution rule — do not restate them here.

**feedback wrapper (per-arm delta only):**
- **feedback unit identity:** when **reviewing**, each *emitted finding* (not each AC) is the unit; it must be grounded in concrete
  repo facts: file path, line number, field value, or AC-id. A generic assertion
  ("the code has issues") fails ground-before-assert.
- **feedback saturation delta:** when **reviewing**, saturation = a full review pass over the AC's
  true subject surfaces nothing new. The verbatim-injected `ground-and-sweep.md` defines
  the shared saturation criterion and scope-resolution rule; apply them here.

## Related

- Pattern + maintainer notes (invocation, history): `README.md`.
