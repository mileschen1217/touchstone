---
name: test-quality-audit
description: Audit an existing test suite for quality and coverage gaps — feedback loop for test maintenance. Use when flaky tests exceed budget, after major refactors, when branch coverage drops, before a phase milestone, or when bugs have been fixed without regression tests. Reports gaps, stale patches, flaky tests, and assertion anti-patterns; suggests what to add/remove. Report-only — does not modify tests or auto-fix.
kind: workflow
---

# /touchstone:test-quality-audit

Feedback-loop audit of the current project's test suite. Checks **what exists**, flags gaps and staleness, and recommends additions/removals. **Report-only: does not write, modify, or auto-fix tests** — surfaces gaps for a human or follow-up agent (use `/superpowers:test-driven-development` or the `tdd` agent to write tests).

## Usage

```
/touchstone:test-quality-audit                       # default: 30-day window, 80% branch threshold
/touchstone:test-quality-audit <days>                # custom window (e.g. `7`, `90`)
/touchstone:test-quality-audit --threshold=<N>       # override branch coverage threshold (percent)
/touchstone:test-quality-audit <days> --threshold=<N> # both — window AND threshold override
```

### Argument parsing

Parse left-to-right:
1. First bare numeric token → `days` (window for the regression-gap git log scan).
2. Any `--threshold=<N>` flag → `threshold` (integer 0-100; branch-coverage gate).
3. Both arguments are independent — order doesn't matter, either can be omitted.
4. Unknown tokens → fail loudly: "unknown argument — expected `<days>` (integer) or `--threshold=<N>`".

Defaults — used when an argument is omitted:
- `days = 30` (the regression-window default referenced throughout the body)
- `threshold = 80` (the branch-coverage default in §7 Coverage policy and §1 Coverage gaps)

Project CLAUDE.md may declare different defaults; project values override skill defaults, and CLI args override both.

## What the audit checks

### 1. Coverage gaps
- **Regression gap:** search git log for `fix`/`bug` commits in the last N days. For each, check whether a test file was modified in the same commit. Flag commits without test changes.
- **Public API surface** not exercised by any test
- **Error paths and boundary values** untested

### 2. Flaky tests
- Count tests marked `@flaky` / `@skip` / `@xfail` or retried via plugin
- Count tests that fail intermittently across the last N CI runs (if available)
- If total > budget (default 5): stop new feature work and stabilize before continuing

### 3. Stale patches
- Commented-out test code — candidate for deletion
- Skipped tests with no tracking issue or TODO reference
- Tests that no longer exercise meaningful paths (code under test was refactored; test wasn't updated)
- Mocks referencing APIs that no longer exist
- Tests of trivial getters/setters, simple delegation, framework internals, or private methods tested directly instead of through public API — flag for removal

### 4. Assertion quality
Scan for anti-patterns:
- **Exact string matches** on values that vary across environments (timestamps, IDs, hashes). Prefer structure + key-field validation.
- **Absolute counts** (`len == 104`). Prefer relational (`len > 0`, `len(A) == len(B)`).
- **Missing write-then-readback** on mutation tests — value must be read back and verified, then restored.
- **Multiple logically distinct behaviors** asserted in one test (split).

### 5. Test isolation
- Tests with ordering dependencies (pass individually but fail when reordered)
- Tests that leak state (global config, database rows, filesystem, env vars) without teardown
- Shared resource violations (each test opens its own DB connection instead of reusing one suite-level connection)

### 6. Mocking smell
- Mocks of code the project owns (should use a fake or real instance)
- Test files where >50% of lines are mock setup (over-mocking or wrong test level)
- Mocks of internal helpers / pure functions (should mock at boundary only)

### 7. Coverage policy
- Branch coverage threshold (default 80%, configurable per project)
- If below: identify files causing the drop; propose minimum tests to restore

## Scope — what this skill does NOT do

- **Does not write new tests** — that's `/superpowers:test-driven-development`, the `tdd` agent, or language-specific `tdd-*` skills.
- **Does not re-run the full suite for proof** — use the project's regular test command for that.
- **Does not modify test files** — report-only; findings are for a human or follow-up agent.
- **Does not auto-fix** — surfaces gaps, doesn't silently change them.

## How to run

1. **Detect test command** — read project CLAUDE.md for the canonical test command. Fall back to conventions (`pytest`, `npm test`, `cargo test`, `go test`, `mvn test`).
2. **Run with coverage** if supported. Parse: total / passing / failing / skipped / flaky / branch%. Compare branch% against the resolved `threshold` (default 80, overridable via `--threshold=N`).
3. **Walk git log** for the last `days` (default 30, overridable as the first positional arg). Find `fix` / `bug` commits. For each, check whether any `test*` / `*test*` / `*spec*` file was touched.
4. **Scan test files** using Grep for: `@skip`, `@xfail`, `@flaky`, `xit(`, `xdescribe(`, `skip:`, commented-out `it(` / `test(` / `def test_`, TODO/FIXME in tests.
5. **Scan assertions** for anti-patterns: exact hard-coded strings, absolute `len == N` patterns, missing teardown / restore blocks.
6. **Scan mocks** for: own-code references, mock-to-code ratio > 50%, internal-helper mocks.

## Report format

Structured output:

```
Test Quality Audit — <project> — <date>

COVERAGE SUMMARY
  Total: X | Passing: Y | Failing: Z | Skipped: S | Flaky: F | Branch: B%

REGRESSION GAPS (<N>)
  - <commit-sha> "<msg>" — no test file touched in same commit
  - ...

FLAKY BUDGET (<count>/5)
  - <test_name> (skipped)
  - <test_name> (retried 3x)
  - ...

STALE PATCHES (<N>)
  - <file:line> — commented-out test
  - <file:line> — @skip no tracking issue
  - ...

QUALITY ISSUES (<N>)
  - <file:line> — absolute count assertion "len == 104"
  - <file:line> — missing write-then-readback on mutation
  - ...

RECOMMENDATIONS
  🔴 Critical (blocks ship):
    - ...
  🟡 Important (fix this week):
    - ...
  🟣 Nit (deferred):
    - ...
```

## Related

- `/superpowers:test-driven-development` — write new tests after the audit.
- `/superpowers:verification-before-completion` — pre-commit verification.
- ECC language-specific testing skills: `python-testing`, `rust-testing`, `kotlin-testing`, `cpp-testing`, `golang-testing` — per-language test craft.
- Decision-rationale ADR: `README.md`.
