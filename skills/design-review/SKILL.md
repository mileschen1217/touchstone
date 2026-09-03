---
name: design-review
kind: workflow
description: Pre-Build review gate for design documents (spec.yaml, plan, ADR). Out of scope — anything not a contract-bearing design document.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Agent]
user-invocable: false
---

# /touchstone:design-review

## Scope

In scope: `*.spec.yaml`, plan, ADR (`**/plans/**`, `**/adr/**`); else reply "not in scope — specs / plans / ADRs only" and exit. Subject status: `accepted-candidate` is the normal subject; `accepted` → treat as re-review; `draft` → reply "draft — not gated" and exit.

**Mode.** A spec whose `facts_source` record's readiness ruling says "short form" selects the **short-chain mode**: one round, the challenger and verification-honesty lenses only, the stopping rule's re-verify dispatch unused — the round closes on its own outcome. Every other subject runs the full mode: three lenses, the stopping rule's full budget.

## Phase 1 — Setup

Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md` and follow it. **Lens** and **arm** are defined in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/provenance.md` — read it once; its field table is what Phase 4 writes, its arm-dispatch mechanics are the transport Phase 3 follows, and its merge rules carry the read-back comparison Phase 4 applies.

## Phase 2 — Pre-check (specs only; plan/ADR skip)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/design-review-precheck.sh" <spec-path>
```

Non-zero → surface the full `BLOCK:` output verbatim, **do not dispatch** — the human resolves first. Zero → proceed; a `warn:` line rides into every document lens.

## Phase 3 — Dispatch: every lens to each of its arms, one message

The declared lens set of this gate (the arms column is the default configuration; the caller may add an arm, never remove the last one — a lens with zero arms is a skill defect; the short-chain mode dispatches the first and third rows only):

```yaml
lenses:
  - {name: challenger,           arms: [cc]}
  - {name: design-soundness,     arms: [cc]}
  - {name: verification-honesty, arms: [codex]}
```

A cc arm carrying design-soundness runs in a fresh context, never the challenger's.

Transport: the arm-dispatch mechanics in `provenance.md`, already read in Phase 1. This gate's deltas: arm labels `challenger-cc` / `design-soundness-cc` / `verification-honesty-codex`; every subject is `--subject-file <spec-path>`; round dir = `<epic-dir>/design-review-<date>/` or `…/reverify/`; the codex envelope's role string is `"design-reviewer"`; an arm's output tags each finding `[lens: …]`.

An arm that is unhealthy, fails, or returns no parsable finding or verdict → re-dispatch its lenses to a `cc` arm in a FRESH context (never the challenger's) so every lens still runs; the round is `degraded: true` with `degraded_reason` naming each such lens (`lens verification-honesty: codex unavailable` / `: partial`); a degraded round closes only via `provenance.md`'s presentation duty (human acknowledgement).

## Phase 4 — Merge into review.yaml

One file per round: round 1 at `<epic-dir>/design-review-<date>/review.yaml`, the re-verify at `…/reverify/review.yaml` (`round: 2`); raw outputs beside it (`raw_cc.md`, `raw_codex.jsonl`, `last-message.txt`). Field set: `${CLAUDE_PLUGIN_ROOT}/skills/_shared/schemas/review.schema.yaml`; field meanings AND the shared merge rules: `provenance.md` (read in Phase 1). This gate's one merge delta: **the challenger lens's severity is derived from marker type at merge (`coverage-gap` / `real-defect` → H, `refinement` → L), never reviewer-assigned**; a document-lens finding keeps the arm's severity and type.

**Read-back check**: `provenance.md`'s `fragments_read` comparison, against the recorded assembler ids; the reason-shape literals live in `review.schema.yaml`'s `degraded_reason` pattern (single home).

**Bridge classification** (host-side): a document lens judges bridge claims against the standing-vs-transient rule carried in its own assembled lens file; classifying the reviewed artifact itself as standing or transient is this merging session's step, never an arm's.

**Sweep home-misses:** a home-miss finding from the challenger or design-soundness arm (a party missing from a valid baseline — the sweep-axis rule carried in its assembled lens file) is written into the epic's `deviation.yaml` as a `D-n` entry (`refs` = the finding's ids), attributed to explore (a missing case: to assay).

`rulings[]`: every ledger id this round appended (marker routing to the human vs the authoring session: the stopping rule); a ruling lands in the matching assay-record item's `rulings[]` — `{date, stage: design-review, text}` — and its id listed here; a marker the authoring session resolves records its `fix`. Validate before reporting: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" review <file> --root <epic-dir>` — exit 0.

Convergence: the host segment `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/severity-tiered-stopping-rule.md` — read it in full here; this round's C/H feeds its initial round (short-chain mode: that round is the whole run). Build waits until the rule closes; `degraded: true` → the presentation duty in `provenance.md`, before Build.

**Post-review re-distill (once C+H = 0).** Re-distill every `shall` to one sentence and every AC to its Then (rule home: design-spec § 4); a meaning-changing edit re-enters review, never rides the verdict.

Never auto-promote the artifact's status — the human (or caller) decides.
