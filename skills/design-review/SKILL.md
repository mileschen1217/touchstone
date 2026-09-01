---
name: design-review
kind: workflow
description: Pre-Build review gate for design documents (spec.yaml, plan, ADR) — one gate, three lenses each dispatched to its arms, one review.yaml per round; a short-chain spec gets one round of two lenses. Out of scope — anything not a contract-bearing design document.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Agent]
user-invocable: false
---

# /touchstone:design-review

## Scope

In scope: `*.spec.yaml`, plan, ADR (`**/plans/**`, `**/adr/**`); else reply "not in scope — specs / plans / ADRs only" and exit. Subject status: `accepted-candidate` is the normal subject; `accepted` → treat as re-review; `draft` → reply "draft — not gated" and exit.

**Mode.** A spec whose `facts_source` record's readiness ruling says "short form" selects the **short-chain mode**: one round, the challenger and verification-honesty lenses only, the stopping rule's re-verify dispatch unused — the round closes on its own outcome. Every other subject runs the full mode: three lenses, the stopping rule's full budget.

## Phase 1 — Inject

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` and follow it. **Lens** and **arm** are defined in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/provenance.md` — read it once; its field table is what Phase 4 writes.

**Once, verbatim:** read each fragment below in FULL from `${CLAUDE_PLUGIN_ROOT}` and place it in the named context.

Every arm:
1. `skills/_shared/inject/severity-qualification.md` — the removal test and C/H qualification. The round budget is NOT injected: the host segment (`skills/_shared/inject/severity-tiered-stopping-rule.md`) is yours to read at Phase 4, never an arm's.

The two sweep-executing lenses only (challenger, design-soundness — the verification-honesty arm does not receive it):
2. `skills/_shared/ground-and-sweep.md` — unit = each *emitted finding* (field path); stop only at saturation on both axes (breadth of cases, reach of parties/sites).
   - **Reach axis is baseline-conditional — three cases** (the terms *seam-map* / *reach-under-determined* are homed in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/reach-discovery.md`). Treat a Consensus Scope seam-map — its verify-against home is the epic's `explore-<date>-<subject>.yaml` when crucible's explore phase produced one — as a **valid baseline** only when it was confirmed for this same artifact and intent and is not flagged reach-under-determined. With one in hand, check the delivered party set against it (confirm saturation). With none — or a stale one, a direct invocation carrying no Consensus included — keep the sweep-to-saturation discovery role intact. With a baseline that IS flagged under-determined, rediscover and surface the shortfall.
   - **The breadth axis is baseline-conditional on the same three cases** (*case-partition* and *partition-under-determined* are homed in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/breadth-discovery.md`). Rule on the baseline's validity with your own eyes: an entry qualifies only where the interview confirmed it for that same rule under the intent now in force, the requirement cites its ledger id in `basis`, and no under-determined mark rides it — then test each requirement's ACs against its case list. Lacking one, or holding a stale entry (staleness per `breadth-discovery.md`), partition at full width. Against a marked entry, partition afresh and report the shortfall.
   - **A party missing from a valid baseline is a home-miss.** Cover it in this pass — it ships as a finding — and at Phase 4 you write it into the epic's `deviation.yaml` as a `D-n` entry (`refs` = the finding's ids) attributed to explore (a missing case: to assay).

Per lens (the table in Phase 3 names each lens's fragments):
3. challenger — `skills/design-review/references/challenger.md` (this skill's own reference — sole injector).
4. verification-honesty — `skills/_shared/inject/live-bearing-predicate.md` + `skills/_shared/inject/ac-coverage-honesty-principle.md`, appended to the arm's `system_prompt` AND carried as `evidence_honesty_vocab`.
5. design-soundness — `skills/_shared/inject/design-soundness-honor-check.md` + `skills/assay/references/arch-rubric.md`, prepended as content; apply the **feedforward arm**.
6. every document lens — `skills/design-review/references/standing-vs-transient-bridge.md` (sole injector) + `skills/_shared/inject/bridge-content-gate.md`: set `discipline_mode: "source-as-truth"` + `source_as_truth_vocab: <verbatim text>` — the arm judges bridge claims by them; classifying the artifact as standing or transient is your step at merge, never an arm's.

## Phase 2 — Pre-check (specs only; plan/ADR skip)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
```

Non-zero → surface the full `BLOCK:` output verbatim, **do not dispatch** — the human resolves first. Zero → proceed; a `warn:` line rides into every document lens.

## Phase 3 — Dispatch: every lens to each of its arms, one message

The declared lens set of this gate (the arms column is the default configuration; the caller may add an arm, never remove the last one — a lens with zero arms is a skill defect; the short-chain mode dispatches the first and third rows only):

```yaml
lenses:
  - {name: challenger,           arms: [cc],    prompt_home: skills/design-review/references/challenger.md}
  - {name: design-soundness,     arms: [cc],    prompt_home: skills/design-review/references/lenses.md}
  - {name: verification-honesty, arms: [codex], prompt_home: skills/design-review/references/lenses.md}
```

A cc arm carrying design-soundness runs in a fresh context, never the challenger's.

Probe first: `codex --version >/dev/null 2>&1 && echo codex_healthy=1 || echo codex_healthy=0`. Then issue every `Agent` call in ONE assistant message — one call per arm, carrying every lens assigned to that arm (an arm's output tags each finding `[lens: …]`):

- **cc arm** — `Agent(subagent_type: "touchstone:code-reviewer", description: "<lens names>", prompt: <that arm's lens prompts + injections> + the spec fenced as UNTRUSTED DATA)`. The challenger lens outputs typed markers, one per line; a document lens outputs the line format in `lenses.md`.
- **codex arm** — write the spec text to `<round dir>/task.md` FIRST, then `Agent(subagent_type: "touchstone:codex-reviewer", description: "<lens names>", prompt: envelope {task_file: <round dir>/task.md, task_dir: <round dir>, system_prompt: <that arm's lens prompts + injections>, role: "design-reviewer"})` — the review target rides to codex by file, never through the wrapper's context.
- An arm that is unhealthy, fails, or returns no parsable finding or verdict → re-dispatch its lenses to a `cc` arm in a FRESH context (never the challenger's) so every lens still runs; the round is `degraded: true` with `degraded_reason` naming each such lens (`lens verification-honesty: codex unavailable` / `: partial`); a degraded round closes only via `provenance.md`'s presentation duty (human acknowledgement).

## Phase 4 — Merge into review.yaml

One file per round: round 1 at `<epic-dir>/design-review-<date>/review.yaml`, the re-verify at `…/reverify/review.yaml` (`round: 2`); raw outputs beside it (`raw_cc.md`, `raw_codex.jsonl`, `last-message.txt`). Field set: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/schemas/review.schema.yaml`; field meanings AND the shared merge rules: `provenance.md` (read in Phase 1). This gate's one merge delta: **the challenger lens's severity is derived from marker type at merge (`coverage-gap` / `real-defect` → H, `refinement` → L), never reviewer-assigned**; a document-lens finding keeps the arm's severity and type.

`rulings[]`: every ledger id this round appended (marker routing to the human vs the authoring session: the stopping rule); a ruling lands in the matching assay-record item's `rulings[]` — `{date, stage: design-review, text}` — and its id listed here; a marker the authoring session resolves records its `fix`. Validate before reporting: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" review <file> --root <epic-dir>` — exit 0.

Convergence: the host segment `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md` — read it in full here; this round's C/H feeds its initial round (short-chain mode: that round is the whole run). Build waits until the rule closes; `degraded: true` → the presentation duty in `provenance.md`, before Build.

**Post-review re-distill (once C+H = 0).** Re-distill every `shall` to one sentence and every AC to its Then (rule home: design-spec § 4); a meaning-changing edit re-enters review, never rides the verdict.

Never auto-promote the artifact's status — the human (or caller) decides.
