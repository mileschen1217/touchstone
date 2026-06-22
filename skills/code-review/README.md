# code-review — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`.

## Why Pattern B (not Pattern A) for batch

Per-batch volume is high enough that Pattern A's 2× cost is not justified. Cross-vendor
diversity is preserved via the builder→reviewer swap. High-leverage Pattern A is reserved
for `/touchstone:design-review` (Stage 0), `/touchstone:keystone`, and
`/touchstone:design-spec`.

## Dependencies

- `everything-claude-code:code-reviewer` + language/security/database reviewers (ECC, EXTERNAL)
  — Epic B vendors or makes optional.
- `touchstone:codex-reviewer` (plugin-local) — Pattern B cross-vendor reviewer when CC builds.

Language-specific, security, and database reviewers require the `everything-claude-code`
plugin (ECC). CC-only fallback (enforced inline in `SKILL.md` Step 3): if ECC is not installed,
the skill runs with the generic Sonnet reviewer only and logs a note about the missing dependency.

## Key-rules summary (all enforced inline in the procedure)

- Always spawn separate agents — never review inline (Step 3).
- Generic reviewer model: Sonnet; language/security/DB reviewers use their own defaults.
- Dispatch all reviewers in parallel (single message, multiple Agent calls, `run_in_background: true`).
- AI judgment, not regex, for security/DB dispatch — prefer skipping in ambiguous cases.
- Fix only Critical/High by default; Low fixable inline if trivial; Medium deferred to batch (Step 5).
- No re-review loop in Pattern C (Step 5).
- Project CLAUDE.md may override the diff path (Step 1).
