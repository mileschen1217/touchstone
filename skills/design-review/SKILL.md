---
name: design-review
kind: workflow
description: Pre-Build review gate for design documents (spec, plan, ADR). Out of scope — anything not a contract-bearing design document.
allowed-tools: [Bash, Read, Grep, Glob, Agent]
user-invocable: true
---

# /touchstone:design-review

## Scope

In scope (`type:`/path): spec, plan, ADR (`**/specs/**`, `**/plans/**`, `**/adr/**`); else reply "not in scope — specs / plans / ADRs only" and exit. Subject status: `accepted-candidate` is the normal subject; `accepted` → treat as re-review; `draft` → reply "draft — not gated" and exit.

## Phase 1 — Inject

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` and follow it.

**Once, verbatim:** read each fragment below in FULL from `${CLAUDE_PLUGIN_ROOT}` and place it in the reviewer envelope — never restate a fragment's body elsewhere in this file.

Unconditional:
1. `skills/_shared/inject/live-bearing-predicate.md` + `skills/_shared/inject/ac-coverage-honesty-principle.md` — append to `system_prompt` AND carry as `evidence_honesty_vocab`.
2. `skills/_shared/inject/design-soundness-honor-check.md` — prepend to `system_prompt`; apply its **feedforward duty** (subject = the document). Reading it in full also satisfies its own injector requirement (arch-rubric content loaded alongside it).
3. `skills/_shared/ground-and-sweep.md` — inject verbatim. Unit = each *emitted finding* (file / line / field / AC-id); stop only at saturation on both axes (breadth of cases, reach of parties/sites) — never first-hit.
4. `skills/design-review/references/standing-vs-transient-bridge.md` (this skill's own reference — sole injector) + `skills/_shared/inject/bridge-content-gate.md` — set `discipline_mode: "source-as-truth"` + `source_as_truth_vocab: <verbatim text>`. The Bridge audit stays this skill's own action, not the dispatched reviewer's.

## Phase 2 — Pre-check (specs only; plan/ADR skip)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
```

Non-zero → surface the full `BLOCK:` output verbatim, **do not dispatch** — the human resolves first. Zero → proceed.

## Phase 3 — Dispatch

Invoke `Skill(skill: "touchstone:cross-provider-reviewer")`: `task` = full doc text, `system_prompt` = prompt below + Phase-1 injections, `discipline_mode` per Phase 1, `role` = `design-reviewer`.

### Doc-review prompt — inline

> You review an authored design document. Apply TWO lens-sets (UNION), reading the document only — never test source, per-AC coverage, or code (code-review batch and epic-close own those):
>
> **(i) design-soundness** — the feedforward duty from the injected fragment (subject = the document), plus structural validity, unhandled failure modes, missed edge cases per the injected architecture rubric. Also **standing-decision consistency**: sweep the repo's ADR corpus (`docs/adr/**`, `**/adr/**`; status Accepted) for decisions the document reverses or contradicts — a reversal that does not name and supersede its ADR is a finding.
>
> **(ii) verification-honesty** — two principles (named instances are examples, not a closed list):
> - **Falsifiable concreteness.** Every load-bearing statement is concrete enough to be shown false: Problem / Scope / Non-goals falsifiable, not aspiration; interfaces name fields, types, error returns; error handling maps to scenarios; invariants are cross-cutting rules; a coined term is defined at first use and used consistently; numbers agree across sections.
> - **Complete, honest verification story.** For EACH requirement, enumerate the behaviours a user would recognize as "working" (happy, error, boundary paths) and flag every requirement whose ACs witness only the happy path; the doc carries a `Live-bearing AC IDs` declaration in EITHER accepted home (the AC-section intro, or a `## Verification Strategy` section for legacy pre-P2 specs) and every live-bearing AC id (per the injected predicate) appears in it; a standing-runtime feature carries an activation AC on the user-observable, never only a fixture proxy; Risks / Open Questions are surfaced, not hidden.
>
> Output: tag findings `[lens: design-soundness]` / `[lens: verification-honesty]`; state a zero-finding lens as zero. Sort by severity (Critical → Low), each citing section + concrete fix. End with verdict: approve | revise | block, then the sentinel:
> `STAGE-REVIEW-SUMMARY: critical=<n> high=<n> degraded=<true|false>`

## Phase 4 — Apply findings

Convergence: the stopping rule is `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md` — load it, apply it, restate nothing. This gate's C/H verdict feeds the initial round; the bounded single re-verify, blocked escalation, and no-unauthorized-third-round all govern here. Build waits until the rule closes the loop; no severity count leaves the next action undefined.

A ⚠️ DEGRADED / ⚠️ PARTIAL banner (orthogonal to the severity tiers) → present VERBATIM and get explicit acknowledgement BEFORE Build, even at C+H = 0 (meaning: `cross-provider-reviewer/references/provenance.md`).

**Post-review re-distill (spec artifacts, once C+H = 0).** You, the reviewing session, re-distill the spec's REQ/AC surface before the status decision (rule home: design-spec § REQ-headline discipline). Present the re-distill diff with the findings; a meaning-changing edit re-enters review, never rides the verdict.

Never auto-promote the artifact's status — the human (or caller) decides.

## Gate stamp

After the run resolves (any outcome): follow the shared stamp schema at `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/gate-stamp.md` with gate-id `design-review` and the doc path as target.
