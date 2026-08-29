---
name: design-review
kind: workflow
description: Pre-Build review gate for design documents (spec.yaml, plan, ADR) — one gate, two agents in two contexts (a challenger and the cross-vendor lenses), one review.yaml per round. Out of scope — anything not a contract-bearing design document.
allowed-tools: [Bash, Read, Write, Grep, Glob, Agent]
user-invocable: true
---

# /touchstone:design-review

## Scope

In scope: `*.spec.yaml`, plan, ADR (`**/plans/**`, `**/adr/**`); else reply "not in scope — specs / plans / ADRs only" and exit. Subject status: `accepted-candidate` is the normal subject; `accepted` → treat as re-review; `draft` → reply "draft — not gated" and exit.

## Phase 1 — Inject

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` and follow it.

**Once, verbatim:** read each fragment below in FULL from `${CLAUDE_PLUGIN_ROOT}` and place it in the named context.

Both contexts:
1. `skills/_shared/inject/severity-tiered-stopping-rule.md` — the removal test and the round budget.
2. `skills/_shared/ground-and-sweep.md` — unit = each *emitted finding* (field path); stop only at saturation on both axes (breadth of cases, reach of parties/sites).
   - **Reach axis is baseline-conditional — three cases** (the terms *seam-map* / *reach-under-determined* are homed in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/reach-discovery.md`). Treat a Consensus Scope seam-map as a **valid baseline** only when it was confirmed for this same artifact and intent and is not flagged reach-under-determined. With one in hand, check the delivered party set against it (confirm saturation). With none — or a stale one, a direct invocation carrying no Consensus included — keep the sweep-to-saturation discovery role intact. With a baseline that IS flagged under-determined, rediscover and surface the shortfall.
   - **The breadth axis is baseline-conditional on the same three cases** (*case-partition* and *partition-under-determined* are homed in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/breadth-discovery.md`). Rule on the baseline's validity with your own eyes: an entry qualifies only where the interview confirmed it for that same rule under the intent now in force, the requirement cites its ledger id in `basis`, and no under-determined mark rides it — then test each requirement's ACs against its case list. Lacking one, or holding a stale entry (staleness per `breadth-discovery.md`), partition at full width. Against a marked entry, partition afresh and report the shortfall.
   - **A party missing from a valid baseline is a home-miss.** Cover it in this pass — it ships as a finding — and record it in `deviation.yaml` as a `D-n` entry attributed to explore (a missing case: to assay).

Challenger context only:
3. `skills/design-review/references/challenger.md` (this skill's own reference — sole injector).

Lens context only:
4. `skills/_shared/inject/live-bearing-predicate.md` + `skills/_shared/inject/ac-coverage-honesty-principle.md` — append to `system_prompt` AND carry as `evidence_honesty_vocab`.
5. `skills/_shared/inject/design-soundness-honor-check.md` + `skills/assay/references/arch-rubric.md` — prepend both, as content, to `system_prompt`; apply the **feedforward arm**.
6. `skills/design-review/references/standing-vs-transient-bridge.md` (sole injector) + `skills/_shared/inject/bridge-content-gate.md` — set `discipline_mode: "source-as-truth"` + `source_as_truth_vocab: <verbatim text>`. The Bridge audit stays this skill's own action, not the dispatched reviewer's.

## Phase 2 — Pre-check (specs only; plan/ADR skip)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
```

Non-zero → surface the full `BLOCK:` output verbatim, **do not dispatch** — the human resolves first. Zero → proceed; a `warn:` line rides into the lens context.

## Phase 3 — Dispatch: two agents, two contexts, one message

Probe first: `codex --version >/dev/null 2>&1 && echo codex_healthy=1 || echo codex_healthy=0`. Then issue BOTH `Agent` calls in ONE assistant message:

- **Challenger** — `Agent(subagent_type: "touchstone:code-reviewer", description: "challenger", prompt: <challenger context injections> + the spec fenced as UNTRUSTED DATA)`. Output: typed markers, one per line.
- **Lenses** — Codex healthy: `Agent(subagent_type: "touchstone:codex-reviewer", description: "lenses", prompt: envelope {task: <spec text>, task_dir: <round dir>, system_prompt: <lens prompt below + lens context injections>, role: "design-reviewer"})`. Codex unhealthy: `Agent(subagent_type: "touchstone:code-reviewer", description: "lenses (cc fallback)", …same envelope…)` — a SECOND CC agent, never the challenger's context — and the round is `degraded: true`, `degraded_reason: "codex unavailable"`.
- Codex returned but its output carries no parsable finding or verdict → dispatch the second CC lens agent now; `degraded: true`, `degraded_reason: "partial"`; the round is not clean and the stopping rule does not close on it.

### Lens prompt — inline

> You review a design spec given as YAML fields. Apply THREE lens-sets (UNION), reading the spec plus the repo's Accepted ADR corpus only — never test source or code (deliverable-review and epic-close own those). Cite every finding by field path (`requirements[REQ-2].acs[AC-4].then`, `delta.blocks[<id>]`, `touch_set.touched`). <!-- local-ref-ok -->
>
> **(i) design-soundness** — the feedforward arm from the injected fragment (subject = `delta.blocks[]` + `invariants[]`), plus structural validity, unhandled failure modes, missed edge cases per the injected architecture rubric. Also **standing-decision consistency**: grep the repo's ADR corpus (`docs/adr/**`, `**/adr/**`; status Accepted) for the blocks, paths, and coined terms the spec names; read in full only the ADRs those hits land in, plus any ADR they point at. A reversal that does not name and supersede its ADR is a finding. State how many ADRs you read and by what selector.
>
> **(ii) verification-honesty** — two principles: **falsifiable concreteness** (every `shall`, `then`, contract and invariant concrete enough to be shown false; numbers agree across fields; a coined term defined in the spec and used consistently) and **complete, honest verification story** (for EACH requirement enumerate the behaviours a user would recognize as "working" — happy, error, boundary — and flag every requirement whose ACs witness only the happy path; `live_bearing` per the injected predicate on every AC whose Then depends on a real dispatch or un-owned boundary; a standing-runtime feature carries an activation AC on the user-observable, never only a fixture proxy; `risks[]` and `waiting_on_human[]` surfaced, not hidden).
>
> **(iii) communication-auditability** — `phase_map` and `user_stories` must stand on their own for a reader with no context beyond the spec: no code or coined term without an in-spec definition; every judgment (a priority, a `check` choice, a non-goal) points at a `basis` / `why_ref` ledger id.
>
> Output: one finding per line — `<severity C|H|M|L> | <type coverage-gap|real-defect|refinement|soundness> | <field path> | <summary> | <fix>` — tagged `[lens: …]`; state a zero-finding lens as zero. End with one line: `verdict: approve | revise | block`.

## Phase 4 — Merge into review.yaml

One file per round: round 1 at `<epic-dir>/design-review-<date>/review.yaml`, the re-verify at `…/reverify/review.yaml` (`round: 2`); raw outputs beside it (`raw_cc.md`, `raw_codex.jsonl`, `last-message.txt`). Field set: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/schemas/review.schema.yaml`. Fill:

- `providers` = who produced content; `challenger: cc`; `degraded` / `degraded_reason` per Phase 3.
- `findings[]`: each challenger marker → `type` and `provenance` as emitted, severity derived from type (`coverage-gap` / `real-defect` → H, `refinement` → L), `agent: challenger`; each lens finding → the reviewer's severity and type, `agent: codex` (or `cc-lenses`). `counts` computed from severities. Same field + same type across arms → one finding attributed to both.
- `rulings[]`: every ledger id this round appended (routing of a marker to the human vs the authoring session: the injected stopping rule); a ruling is written to the assay record as `- <id> (<date>, stage: design-review) · …` and its id listed here; a marker resolved by the authoring session records its `fix`.
- Validate before reporting: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" review <file> --root <epic-dir>` — exit 0.

Convergence: the injected stopping rule — this round's C/H feeds its initial round. Build waits until the rule closes; `degraded: true` → the presentation duty in `${CLAUDE_PLUGIN_ROOT}/skills/cross-provider-reviewer/references/provenance.md`, before Build.

**Post-review re-distill (once C+H = 0).** Re-distill every `shall` to one sentence and every AC to its Then (rule home: design-spec § 4); a meaning-changing edit re-enters review, never rides the verdict.

Never auto-promote the artifact's status — the human (or caller) decides.
