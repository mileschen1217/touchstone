---
name: design-review
kind: workflow
description: Pre-Build review gate for design documents (spec, plan, ADR). Out of scope — anything not a contract-bearing design document.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
user-invocable: true
---

# /touchstone:design-review

## Scope

In scope (`type:`/path): spec, plan, ADR (`**/specs/**`, `**/plans/**`,
`**/adr/**`); else reply "not in scope — specs / plans / ADRs only" and exit.
Subject status: `accepted-candidate` is the normal subject; `accepted` →
treat as re-review; `draft` → reply "draft — not gated" and exit.

## Phase 1 — Inject

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` and follow it.

**Injection discipline (once).** Graded by fragment size: a ≤20-line spine fragment is
injected **verbatim**; a >20-line reachable fragment is dispatched by
**path+attestation** per
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/path-attestation-dispatch.md` (single home of the
dispatch form + shared fallback).

Verbatim (≤20L, append to `system_prompt`):
1. `skills/_shared/inject/live-bearing-predicate.md` +
   `skills/_shared/inject/ac-coverage-honesty-principle.md` — also carry as
   `evidence_honesty_vocab`.
2. Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/ground-and-sweep.md` and inject it verbatim
   into the reviewer envelope — it carries the saturation definition and scope-resolution
   rule. Unit = each *emitted finding* (file / line / field / AC-id).

Path+attestation (>20L, resolved path in `system_prompt`, read-first + attestation):
3. `skills/_shared/inject/design-soundness-honor-check.md` — apply its
   **feedforward duty** (subject = the document), not the feedback duty. Its injector
   requirement's `arch-rubric.md` travels the same path+attestation way (not pasted).

Conditional (`source-as-truth` in `bundle.disciplines`): read
`skills/_shared/inject/bridge-content-gate.md` +
`skills/_shared/inject/standing-vs-transient-bridge.md`; set
`discipline_mode: "source-as-truth"` + `source_as_truth_vocab: <verbatim text>`;
else `discipline_mode: "none"`. The Bridge audit stays THIS skill's action.

## Phase 2 — Pre-check (specs only)

Run each script that exists (absent → skip; plan/ADR skip):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-design-soundness-refs.sh" <spec-path>
```

Non-zero → surface the full `BLOCK:` output verbatim and **do not dispatch**;
the human resolves first. Zero → proceed.

## Phase 3 — Dispatch

Invoke `Skill(skill: "touchstone:cross-provider-reviewer")`: `task` = full doc
text, `system_prompt` = prompt below + Phase-1 injections, `discipline_mode`
per Phase 1, `role` = `design-reviewer`.

### Doc-review prompt — inline

> You review an authored design document. Apply TWO lens-sets (UNION):
> **(i) design-soundness** — the feedforward duty from the injected fragment
> (subject = the document), plus structural validity, unhandled failure modes,
> missed edge cases per the architecture rubric.
> **(ii) verification-honesty** — generate checks from two principles; the named
> instances are examples, not a closed list.
>
> **P1 — Falsifiable concreteness.** Every load-bearing statement is concrete
> enough to be shown false: Problem / Scope / Non-goals falsifiable, not
> aspiration; interfaces name fields, types, error returns; error handling maps to
> scenarios; invariants are cross-cutting rules; a coined term is
> defined at first use and used consistently; numbers agree across sections
> (counts, totals, versions).
>
> **P2 — The verification story is complete and honest.** The doc says how each
> promise will be witnessed, hiding nothing: for EACH requirement,
> enumerate the behaviours a user would recognize as "working" (happy, error,
> boundary paths) and flag every requirement whose ACs witness only the happy
> path — hunts ACs that do NOT exist; the doc carries a `Live-bearing AC IDs`
> declaration in EITHER accepted home — the AC-section intro (six-section form) or a
> `## Verification Strategy` section (legacy pre-P2 specs) — and every live-bearing
> AC id (per the injected predicate + AC-coverage-honesty principle) appears in it —
> a declaration check (no test source yet); a standing-runtime feature
> carries an activation AC on the user-observable, never only a fixture proxy;
> Risks / Open Questions are surfaced, not hidden.
>
> Shared boundary: read the document only — never test source, per-AC coverage,
> or code (code-review batch and epic-close own those).
>
> Output: tag findings `[lens: design-soundness]` /
> `[lens: verification-honesty]`; state a zero-finding lens as zero. Sort by
> severity (Critical → Low), each citing section + concrete fix. End with
> verdict: approve | revise | block, then the sentinel:
> `STAGE-REVIEW-SUMMARY: critical=<n> high=<n> degraded=<true|false>`

## Phase 4 — Apply findings

Convergence rule: read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md`
and apply it as this gate's stopping rule (single home — do not restate it). This
gate's C/H verdict feeds the initial-round table; the boundary pin (H=T re-verify
/ H=T−1 close-with-diff), the bounded single re-verify, blocked escalation, and
the no-unauthorized-third-round rule all govern here. Build waits until the rule
closes the loop (a clean close, or a human ruling on a blocked line); no severity
count leaves the next action undefined.

A ⚠️ DEGRADED / ⚠️ PARTIAL banner (orthogonal to the severity tiers) → present VERBATIM and
get explicit acknowledgement BEFORE Build, even at C+H = 0 (meaning:
`cross-provider-reviewer/references/provenance.md`).

**Post-review re-distill (spec artifacts, once C+H = 0).** You, the reviewing
session, re-distill the spec's REQ/AC surface before the status decision (rule
home: design-spec § REQ-headline discipline — review churn only adds text; this
step reclaims it). Present the re-distill diff together with the findings; an
edit that changes meaning rather than form re-enters review, never rides the verdict.

Never auto-promote the artifact's status — the human (or caller) decides. Close
the metrics window (silent no-op):
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/metrics/stamp-end.sh"`.
Maintainer notes: `README.md`.
