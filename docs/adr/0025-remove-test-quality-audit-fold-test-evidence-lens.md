---
kind: workflow
adr_id: 0025
status: Accepted
date: 2026-06-25
kill-on: touchstone-owns-an-out-of-band-test-runner
---

# ADR-0025: Remove the `test-quality-audit` skill — fold a test-evidence lens into `code-review`

## Status

Accepted. Decided during Stage 1.5 grill-with-docs for Phase 2.12 of the
`skill-ceiling` epic. Reverses the decision to ship `test-quality-audit` as a
standalone skill (it shipped but was never wired / invoked).

## Triggered by

Phase 2.10's first-principles descent on `test-quality-audit`
(`research/2026-06-24-test-quality-audit-first-principles.md`, finding 13): the
skill has no distinct purpose sufficient for a standalone, static, report-only
skill, and is dormant (zero invocations anywhere).

## Context

`test-quality-audit` checked seven things: coverage gaps + regression-gap (§1),
flaky tests (§2), stale patches (§3), assertion quality (§4), test isolation
(§5), mocking smell (§6), coverage policy (§7). Splitting these by what a static
skill can actually do:

- **Execution-dependent / history-dependent** (flaky budget, reorder-dependency,
  branch-coverage trend, the N-day regression-gap git scan) require *running*
  the suite with history — an out-of-band CI / runner that touchstone does not
  own (F1: touchstone mediates a satisficer through prose; F2: it owns no
  runtime). A static skill is structurally barred from these.

- **Source-readable** (assertion anti-patterns §4, mocking smell §6, the
  diff-visible parts of §3/§5) need only the diff — which is exactly
  `code-review`'s input. They collapse into code-review.

So the standalone skill's residual value is either out-of-band (not ours) or
already code-review's. A report-only static skill with no distinct, ownable
purpose is over-machinery.

A second concern surfaced during the grill: folding test checks in as an
*enumerated* `if diff touches test files → run checklist X` invites an
ever-growing roster of conditional specialist reviewers (security, database,
test, …), which is itself the checklist smell touchstone's altitude doctrine
(ADR-0020 pt4) forbids.

## Decision

1. **Remove the `test-quality-audit` skill** (`skills/test-quality-audit/`).
   Low-risk: it is dormant, so nothing in active use breaks.

2. **Fold the source-readable value into `code-review` as an invariant, not a
   checklist.** A test exists to make a green build a true witness that a named
   behavior holds — `claim ≤ evidence` applied to tests. The lens, applied when
   a diff touches test files, is one question with illustrative failure shapes:

   > A test's green must be a true, reproducible, localized witness that the
   > behavior it names actually holds. Ask of each test: **if the named behavior
   > silently broke, would this test go red?** It would NOT (flag it) when it —
   > asserts a proxy not the behavior (env-varying values, absolute counts);
   > exercises a substitute not the code (mocks the boundary under test — only
   > replace the genuinely external: network / fs / clock / hardware); assumes
   > an effect instead of observing it (no write-then-readback on a mutation);
   > depends on the schedule not the behavior (order / leaked shared state, no
   > self-contained teardown); would not localize (one test bundles several
   > behaviors); has no behavior to witness (tautological accessor / framework
   > internal); or cannot go red because it is disabled (skipped / `xfail` /
   > commented-out, added as if it were coverage).

   The lens lives in `code-review` (single consumer — not promoted to
   `_shared/`), as the invariant plus those examples. Depth cross-references the
   ECC `*-testing` skills and `superpowers:test-driven-development`, as the
   removed skill's Related section did.

3. **Record a governance invariant in `code-review` that caps the specialist
   roster.** The generic reviewer self-selects domain lenses from the diff;
   carry the invariant "scrutinize at the depth the diff's risk surface
   demands," not a domain catalog. A *separate* specialist dispatch is added
   only when the generic reviewer **measurably** under-reviews a deep domain —
   justified per item, not per file-type. Security and database are the only
   current named exceptions; the enumeration does not grow with file types.
   The test-evidence lens is therefore folded into the generic reviewer, not a
   new conditional dispatch.

   > **Amendment (2026-07-06).** The two named exceptions (security, database)
   > were retired by user ruling: the fan-out had no dispatch-yield
   > instrumentation, and the generic reviewer's self-selected lenses carry
   > both domains. The governance invariant itself stands — it is now the
   > re-admission bar for any future specialist.

4. **Regression-presence is a different concern with a different trigger.**
   "A bug-fix commit should carry a regression test" fires on *fix commits
   regardless of whether tests were touched* — gating it on test-files-touched
   would skip exactly the commits that need it. It belongs to the generic
   always-on review (per-commit) and the batch regression-gap scan (suite-wide
   git history), not the test-evidence lens.

5. **Route the execution-dependent value out-of-band.** Flaky detection,
   isolation-by-reorder, and coverage-trend belong to `core-locus-and-roles` /
   a future `touchstone-as-harness` mechanism — touchstone does not own the
   runner. This value was never actually delivered by the static skill anyway.

6. **Scrub the operational references** (propose-only for the global file): the
   global `~/.claude/CLAUDE.md` § Test Quality audit line, the `README.md`
   listing, the `plugin.json` skill-count description, and the
   `migration-audit.sh` `SKILL_NAMES` token. Historical research / plan / epic
   references are left as-is.

## Consequences

**Positive**

- One fewer dormant skill; the source-readable test checks gain a real, wired
  home (every per-commit and batch review) instead of an uninvoked report.
- The lens is an invariant a capable reviewer applies, so new anti-patterns fall
  under the core question without growing a checklist.
- The governance invariant gives a principled answer to "do we enumerate a
  specialist per domain forever?" — no; doctrine forbids it.

**Negative / costs**

- The execution-dependent checks (flaky / coverage-trend) have no home until a
  harness mechanism exists. Acceptable: the static skill never delivered them,
  and `kill-on:` records that owning a runner would revisit this.
- The global CLAUDE.md scrub is propose-only (out-of-repo); until the user
  applies it, the § Test Quality audit line dangles to a removed skill.

## Alternatives considered

- **Keep the skill.** Rejected: dormant, no distinct ownable purpose; the
  source-readable value duplicates code-review and the rest is out-of-band.
- **Add a dedicated `test-file-reviewer` agent / conditional dispatch.**
  Rejected: test hygiene is not a deep specialist domain a generic reviewer
  under-reviews; a separate agent is over-machinery and starts the
  enumeration-of-specialists slide (the checklist smell).
- **Fold the checks in as an enumerated checklist.** Rejected: skills carry
  invariants, not checklists (ADR-0020 pt4). The enumerated anti-patterns are
  instances of one force (green must witness behavior); encode the force.
