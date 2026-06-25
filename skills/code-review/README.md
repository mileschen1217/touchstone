# code-review — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`.

## Why Pattern B (not Pattern A) for batch

Per-batch volume is high enough that Pattern A's 2× cost is not justified. Cross-vendor
diversity is preserved via the builder→reviewer swap. High-leverage Pattern A is reserved
for `/touchstone:design-review` (Stage 0), `/touchstone:keystone`, and
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

## Dependencies

- `everything-claude-code:code-reviewer` + language/security/database reviewers (ECC, EXTERNAL)
  — Epic B vendors or makes optional.
- `touchstone:codex-reviewer` (plugin-local) — Pattern B cross-vendor reviewer when CC builds.

Language-specific, security, and database reviewers require the `everything-claude-code`
plugin (ECC). CC-only fallback (enforced inline in `SKILL.md` Step 3): if ECC is not installed,
the skill runs with the generic Sonnet reviewer only and logs a note about the missing dependency.

