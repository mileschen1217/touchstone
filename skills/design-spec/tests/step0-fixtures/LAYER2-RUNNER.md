# Foundation-elicitation fixture replay runner — PENDING (Phase D, OQ-1 deferred)

The 18 Foundation-elicitation-phase fixtures in `skills/*/tests/step0-fixtures/` were authored and
ready as of the 2026-05-23 baseline (`BASELINE.md`), but no replay runner is
wired yet. This file records the pending decision and the execution contract
for whoever wires it.

**2026-07-12 update:** the 2026-07-11 design-spec-deep-module refactor
retired 5 and rewrote 5 of design-spec's fixtures per a per-item survival
table — see `BASELINE.md § 2026-07-12 update` for the disposition list. Current
count: 8 design-spec + 3 epic-driven-roadmap (untouched, AC-11) = **11
fixtures total**, down from 18 historical / 16 pre-refactor. The AC-N labels
below (AC-1/2/3/13) are this file's own pre-refactor numbering (the
intention-first epic's), not the P2 spec's — they identify the same
behavioral classes (shallow boundary / elicitation happy-path / decline vague
aim / hand-off confirm) that the rewritten fixtures now anchor on the P2
spec's new AC numbers instead (see each rewritten fixture's own header).

## Status by verification tier (per ADR-0005 + the spec's two-layer model)

| Tier | What | Status |
|---|---|---|
| Structural Layer-1 | greps/awk over `skills/design-spec/SKILL.md`'s `^### Foundation & facts intake` region (rewritten anchor, post-P2) plus the epic-scaffold-side checks (AC-11, AC-5 template half) | **GREEN now** via `scripts/check-foundation-gate-structure.sh` — triggered by pre-commit checker |
| Behavioral Layer-1 (replay) | replay each fixture, assert deterministic fields (`required-phrases`, `forbidden-substrings`, `expected-foundation` incl. `aim-not-contains`, `expected-risk-notes`, `expected-artifacts`, `awk-shape`) | **pending-harness** (not-scheduled) — needs the replay runner; runner has not been created and is not scheduled for creation |
| Layer-2 rubric | judge AC-1 / AC-2 / AC-3 / AC-13 rubrics over `runs` with `min-pass` | **pending-runner** (not-scheduled) — depends on the same unscheduled runner |

Only AC-1, AC-2, AC-3, AC-13 carry `rubric`/`runs`/`min-pass`. The other
ACs are Layer-1; their behavioral parts are pending-harness (replay), NOT
"verified" — the structural script does not exercise them.

## OQ-1 — which runner? (open)

Candidates named in ADR-0005 / the spec § Interfaces: `eval-harness`,
`agent-eval`, `ai-regression-testing`. Pick the one whose invocation
contract fits the two-layer fixture schema. Decision is the human's; none is
wired in this repo today.

## Execution contract for the runner (when wired)

Author `scripts/run-step0-fixtures.sh` supporting two modes:

- `--layer1` (deterministic, GATING): for each fixture, materialize `setup`
  / `session-state`, launch the skill per `invocation`, replay the `turns`
  (per `cases` entry if present), capture transcript + filesystem, and
  assert every populated Layer-1 field. Exact pass/fail, single run. ALL
  fixtures must pass.
- `--layer2` (rubric judge): replay each rubric-bearing fixture `runs`
  times; a cross-context / cross-provider judge applies the `rubric`;
  PASS iff ≥ `min-pass` of `runs` pass the full rubric (default 4/5).

Honor the harness-wide premature-hand-off invariant: the AC-13 hand-off
phrase is forbidden in every fixture except `aim-handoff`.

## Interim (until wired)

A human may replay any fixture by hand and check its deterministic fields
on demand. Structural Layer-1 (`scripts/check-foundation-gate-structure.sh`) is the
standing gate, triggered by the pre-commit checker, and stays GREEN.
