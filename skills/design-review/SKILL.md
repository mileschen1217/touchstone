---
name: design-review
kind: workflow
description: Use when a design document (spec, plan, ADR) needs its pre-Build review — the consolidated design-review gate. Out of scope — anything that is not a contract-bearing design document.
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

Reviews one authored design artifact before Build by dispatching the cross-provider
reviewer with the doc-review prompt below. This is the **single consolidated design
gate**: it applies **design-soundness ∪ verification-honesty** (the union — passing
one lens never discharges the other). `design-spec` is pure authoring and runs no
review of its own; never treat "design-spec was run" as "this gate passed".

## Scope and lifecycle

Classify the target by frontmatter `type:` (or path):
- `type: spec` OR path matches `**/specs/**` → in scope
- `type: plan` OR path matches `**/plans/**` → in scope
- `type: adr` OR path matches `**/adr/**` → in scope
- Anything else → reply "not in scope; this skill reviews specs / plans / ADRs only" and exit.

The normal subject is a spec at `status: accepted-candidate` (crucible invokes this
gate pre-accept; the human's accept promotes it only after a clean pass). An
already-`accepted` artifact is valid for standalone re-review. A `draft` spec is not
gated here (the pre-check skips it).

## Phase 1 — Load and inject vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
> with the Read tool and follow it exactly.

**Spine injections (unconditional — never gated on a discipline):**
1. Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/live-bearing-predicate.md` AND
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/ac-coverage-honesty-principle.md`;
   append both verbatim to the doc-review `system_prompt` AND carry as
   `evidence_honesty_vocab`. Check 7 below applies them as its declaration stage.
2. Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/design-soundness-honor-check.md`;
   prepend it verbatim to the doc-review `system_prompt`. The cold reviewer applies its
   **feedforward duty** (subject = the document: depth-stakes test + descriptive-only
   detection), not the feedback duty (code vs spec — that lives at deliverable review).
3. Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/ground-and-sweep.md` and inject it verbatim into
   the reviewer envelope (append to `system_prompt`) so the cold reviewer applies
   sweep-to-dry over each finding's true subject. The fragment carries the saturation
   definition and scope-resolution rule — do not restate them. **INV-NO-SILENT-PATH** —
   this fragment fires on the review/feedback path only, and its injection must be
   stated here, in the path that fires it, never assumed from another path's wiring.
   Feedback deltas the reviewer applies with it: the unit is each *emitted finding*
   (grounded in file path / line / field / AC-id — a generic assertion fails
   ground-before-assert); saturation = a full pass over the finding's subject
   surfaces nothing new.

**Conditional (only if `source-as-truth` is in `bundle.disciplines`):** read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` AND
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/standing-vs-transient-bridge.md`; set
envelope `discipline_mode: "source-as-truth"` and `source_as_truth_vocab: <verbatim
loaded text>`. If not adopted: `discipline_mode: "none"`, omit the field. The Bridge
content audit and standing-vs-transient classification remain THIS skill's actions;
the fragments supply only the vocabulary.

- [ ] Every fragment named above was Read and placed in the envelope verbatim (equal
      depth — no lens named without its full text).

## Phase 2 — Deterministic pre-check (specs only)

For `type: spec` targets, run each script that exists (absent script → skip, degrade
gracefully; plan/ADR targets skip this phase):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-design-soundness-refs.sh" <spec-path>
```

Non-zero exit → surface the full `BLOCK:` output verbatim and **do not dispatch**
reviewers; the human resolves the block first. Exit zero → proceed.

- [ ] Pre-check exit code read and acted on (BLOCK surfaced verbatim, or OK).

## Phase 3 — Dispatch

```
Skill(skill: "touchstone:cross-provider-reviewer", args: {
  "task": "<full text of the doc being reviewed>",
  "system_prompt": "<doc-review prompt below + Phase-1 injections>",
  "discipline_mode": "<per Phase 1>",
  "role": "design-reviewer",
  "task_dir": "<optional: from caller context>"
})
```

### Doc-review prompt (cold-inject — keep inline)

> You are reviewing an authored design document (spec, plan, or ADR). Apply TWO
> lens-sets (UNION, not substitution): **(i) design-soundness** and
> **(ii) verification-honesty**. Passing one lens NEVER discharges the other.
>
> **Design-soundness lens — feedforward arm:** apply the feedforward duty from the
> design-soundness fragment injected above (subject = the document, not code).
> Additionally assess structural validity, unhandled failure modes, and missed edge
> cases against the architecture rubric.
>
> **Verification-honesty lens — check:**
> 1. Problem / Scope / Non-goals are concrete and falsifiable.
> 2. Requirement→AC completeness (coverage DIRECTION): for EACH requirement,
>    enumerate the behaviours a user would recognize as "this requirement working" —
>    happy path, error paths, boundaries — and check each behaviour has an AC
>    witnessing it. Flag every requirement whose AC set witnesses only the happy
>    path. This pass hunts ACs that do NOT exist; critiquing the ACs that do
>    exist is the other checks' job.
> 3. Interfaces / Contracts are specific (field names, types, error returns).
> 4. Error Handling rows map to scenarios.
> 5. Invariants are cross-cutting rules.
> 6. Risks / Open Questions are not hidden.
> 7. Verification Strategy declaration: apply the injected live-bearing predicate +
>    AC-coverage-honesty principle as a DECLARATION check (no test source exists yet
>    — never a coverage read): the doc has a non-empty `## Verification Strategy`
>    section and every live-bearing AC id appears in its `Live-bearing AC IDs`.
>    Surface a missing/empty section or an omitted live-bearing AC as a finding. Do
>    NOT read test source or judge per-AC coverage (code-review batch / epic-close
>    own those).
>
> Tag each finding `[lens: design-soundness]` or `[lens: verification-honesty]`; a
> zero-finding lens must be visibly stated as zero, not hidden. Return findings
> sorted by severity (Critical, High, Medium, Low), each citing the section and a
> concrete fix. End with verdict: approve | revise | block, then the sentinel line:
> `STAGE-REVIEW-SUMMARY: critical=<n> high=<n> degraded=<true|false>`
> (`degraded` per `cross-provider-reviewer/references/provenance.md` Operation 3).

## Phase 4 — Apply findings

Sum Critical+High across reviewers:
- **C+H ≥ 5** → apply fixes inline, then re-invoke `/touchstone:design-review <path>`
  — the second pass is mandatory, never skipped on user discretion. Build waits for a
  run with C+H = 0.
- **1 ≤ C+H < 5** → surface findings; Build waits until Critical+High are resolved.
  Second pass optional.
- **C+H = 0** → surface Medium/Low; Build may proceed at user's discretion.

**Informed-consent checkpoint (orthogonal to C+H):** if the synthesis carries a
⚠️ DEGRADED or ⚠️ PARTIAL banner, present the banner text VERBATIM and obtain
explicit acknowledgement (AskUserQuestion or an explicit "proceed") BEFORE allowing
Build — even at C+H = 0. A clean review (no banner) skips this checkpoint. Banner
meaning: `${CLAUDE_PLUGIN_ROOT}/skills/cross-provider-reviewer/references/provenance.md`.

Never auto-promote the artifact's status — the human (or caller skill) decides.

- [ ] C+H tier applied; banner (if any) acknowledged by the human; status untouched.

## Related

- Pattern + maintainer notes (invocation, history): `README.md`.
