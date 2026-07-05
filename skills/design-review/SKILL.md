---
name: design-review
kind: workflow
description: Pre-Build review gate for design documents (spec, plan, ADR). Out of scope — anything not a contract-bearing design document.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob]
user-invocable: true
---

# /touchstone:design-review

The consolidated design gate before Build: **design-soundness ∪
verification-honesty** — one lens never discharges the other.
`design-spec` is pure authoring; "design-spec was run" ≠ "this gate passed".

## Scope

In scope (`type:`/path): spec, plan, ADR (`**/specs/**`, `**/plans/**`,
`**/adr/**`); else reply "not in scope — specs / plans / ADRs only" and exit.
Normal subject: `status: accepted-candidate` (crucible invokes pre-accept;
accept promotes on a clean pass); `accepted` → re-review; `draft` → not
gated.

## Phase 1 — Inject

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` and follow it.

**Injection discipline (once):** Read each fragment below in full from
`${CLAUDE_PLUGIN_ROOT}` and place it **verbatim** in the reviewer envelope — a
lens named without its usable text is the known defect class; this path wires
its own fragments.

Unconditional:
1. `skills/_shared/inject/live-bearing-predicate.md` +
   `skills/_shared/inject/ac-coverage-honesty-principle.md` — append to
   `system_prompt` AND carry as `evidence_honesty_vocab`.
2. `skills/_shared/inject/design-soundness-honor-check.md` — prepend to
   `system_prompt`; apply its **feedforward duty** (subject = the document), not
   the feedback duty.
3. `skills/_shared/ground-and-sweep.md` — Read and inject verbatim into the
   reviewer envelope; the fragment carries the saturation definition and
   scope-resolution rule. Unit = each *emitted finding* (file / line / field /
   AC-id).

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
> path — hunts ACs that do NOT exist; the doc has a non-empty
> `## Verification Strategy` and every live-bearing AC id (per the injected
> predicate + AC-coverage-honesty principle) appears in `Live-bearing AC IDs` —
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

Sum Critical+High (C+H):

| C+H | Action | Build |
|---|---|---|
| ≥ 5 | fix inline; re-invoke — 2nd pass mandatory | waits for a C+H = 0 run |
| 1–4 | surface; 2nd pass optional | waits until C+H resolved |
| 0 | surface Medium/Low | may proceed at user's discretion |

A ⚠️ DEGRADED / ⚠️ PARTIAL banner (orthogonal to C+H) → present VERBATIM and
get explicit acknowledgement BEFORE Build, even at C+H = 0 (meaning:
`cross-provider-reviewer/references/provenance.md`).

Never auto-promote the artifact's status — the human (or caller) decides. Close
the metrics window (silent no-op):
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/metrics/stamp-end.sh"`.
Maintainer notes: `README.md`.
