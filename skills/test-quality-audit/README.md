# test-quality-audit — maintainer notes

Orientation for maintainers. The executable audit (checks §1–8, How-to-run, Report format)
lives in `SKILL.md`.

## Usage examples

- `/touchstone:test-quality-audit 7` — last week's regression gaps only (post-sprint pass).
- `/touchstone:test-quality-audit 90 --threshold=70` — quarterly audit with a relaxed coverage gate (legacy module).
- `/touchstone:test-quality-audit --threshold=90` — strict coverage gate (release-candidate audit).

## Related skills + rationale

- `/superpowers:test-driven-development` — for writing new tests after the audit.
- `/superpowers:verification-before-completion` — for pre-commit verification.
- ECC language-specific testing skills: `python-testing`, `rust-testing`, `kotlin-testing`,
  `cpp-testing`, `golang-testing` — for per-language test craft.
- Config repo: `docs/adr/0011-*.md` — decision rationale for this skill.
