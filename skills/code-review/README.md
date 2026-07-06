# code-review — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`.

## Why Pattern B (not Pattern A) for batch

Per-batch volume is high enough that Pattern A's 2× cost is not justified. Cross-vendor
diversity is preserved via the builder→reviewer swap. High-leverage Pattern A is reserved
for `/touchstone:design-review` (Stage 0), `/touchstone:assay` (structural-fork ADR case), and
`/touchstone:design-spec`.

## Specialist-roster policy (roster empty since 2026-07-06)

The security/database specialist fan-out was retired by user ruling (2026-07-06):
the dispatch had no yield instrumentation, and the generic reviewer self-selects
domain lenses at the depth the diff's risk surface demands. The admission bar is
unchanged and now gates re-entry: a *separate* specialist dispatch is justified
only when the generic reviewer **measurably** under-reviews a deep domain — per
item, not per file-type — so the roster cannot grow into an enumerated catalogue
(one reviewer per language / per file kind, the checklist smell the altitude
doctrine forbids). The test-evidence lens stays folded into the generic reviewer
for the same reason. Original roster rationale: ADR-0025 (item 3 amendment
records the retirement).

## Why a generic Sonnet agent on per-commit (not a dedicated reviewer agent)

Per-commit is the hot path. Keeping it on a generic Sonnet agent + touchstone's own
`generic-diff` prompt keeps the per-commit review philosophy under touchstone's
control. The dedicated cross-vendor agents (`touchstone:codex-reviewer` /
`touchstone:code-reviewer`) come in at `batch` (Pattern B), where vendor
independence carries the most weight.

## Dependencies

- `touchstone:code-reviewer` (plugin-local, vendored 2026-07-06 — ECC dependency
  retired) — the `batch` (Pattern B) reviewer when the builder is Codex
  (cross-vendor swap), and the CC arm of `cross-provider-reviewer`.
- `touchstone:codex-reviewer` (plugin-local) — Pattern B cross-vendor reviewer when CC builds.

Security, database, and language scrutiny all live in the generic Sonnet
reviewer's self-selected lenses (no separate specialist dispatch). The whole
review surface has no external-plugin dependency.

