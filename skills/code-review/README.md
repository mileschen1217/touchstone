# code-review — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`.

## Why Pattern B (not Pattern A) for batch

Per-batch volume is high enough that Pattern A's 2× cost is not justified. Cross-vendor
diversity is preserved via the builder→reviewer swap. High-leverage Pattern A is reserved
for `/touchstone:design-review` (Stage 0), `/touchstone:assay` (structural-fork ADR case), and
`/touchstone:design-spec`.

## Specialist-roster cap (why security/database are the only named reviewers)

A *separate* specialist dispatch is added only when the generic reviewer
**measurably** under-reviews a deep domain — justified per item, not per
file-type. This keeps the roster from growing into an enumerated catalogue (one
reviewer per language / per file kind), which would be the checklist smell the
altitude doctrine forbids. Security and database are the only current named
exceptions because each is a deep domain where a focused, invariant-driven prompt
measurably outperforms the generic reviewer. The test-evidence lens is folded into
the generic reviewer rather than dispatched separately, precisely because test
hygiene is *not* such a deep domain. Rationale: ADR-0025.

## Why a generic Sonnet agent on per-commit (not the ECC code-reviewer)

Per-commit is the hot path. Keeping it on a generic Sonnet agent + touchstone's own
`generic-diff` prompt avoids a hard dependency on the everything-claude-code plugin
and keeps the per-commit review philosophy under touchstone's control. The dedicated
cross-vendor agents (`codex-reviewer` / `everything-claude-code:code-reviewer`) come
in at `batch` (Pattern B), where vendor independence carries the most weight.

## Dependencies

- `everything-claude-code:code-reviewer` (ECC, EXTERNAL) — used only as the `batch`
  (Pattern B) reviewer when the builder is Codex (cross-vendor swap). Epic B vendors
  or makes it optional.
- `touchstone:codex-reviewer` (plugin-local) — Pattern B cross-vendor reviewer when CC builds.

Security, database, and language scrutiny are all plugin-local: the generic Sonnet
reviewer infers language-appropriate scrutiny from the diff, and the security/database
specialists run touchstone's own invariant-based `specialist-reviewer` prompt (not the
ECC `security-reviewer` / `database-reviewer` agents). Per-commit (Pattern C) therefore
has no ECC dependency; only a `batch` review of a Codex-built range reaches for the ECC
reviewer.

