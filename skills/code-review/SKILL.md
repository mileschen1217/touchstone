---
name: code-review
description: |
  Use when a commit or logical commit group needs review. Default: per-commit (Pattern C — generic Sonnet reviewer, plus security/database specialists when the diff warrants). `batch` keyword: logical group (Pattern B — vendor-not-builder reviews). Mode is caller-declared; no commit-count heuristic.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
user-invocable: true
kind: workflow
---

# /touchstone:code-review — Code Review (Patterns C and B)

<!-- orientation-inline: none — rationale (why Pattern B, why generic Sonnet, specialist cap) and Dependencies live in README.md. -->

Dispatches parallel reviewers in separate contexts over a diff and applies their
findings before commit. Never review inline — always spawn separate agents.

## Usage

```
/touchstone:code-review                          # HEAD commit, Pattern C
/touchstone:code-review <commit-ish>             # named single commit, Pattern C
/touchstone:code-review batch [<range>]          # logical group (default <main>..HEAD), Pattern B
/touchstone:code-review [batch] with <codex|cc>  # override reviewer vendor
/touchstone:code-review solo [with codex]        # Pattern C, primary reviewer only
```

Parse args left-to-right:
1. First token `batch` → `mode = batch`.
2. Next token, unless `with`/`solo`, is the commit-ish (Pattern C) or range (Pattern B).
3. `solo` anywhere → skip the specialist fan-out (no-op in Pattern B — already single-reviewer).
4. `with <vendor>` → `force_reviewer = <vendor>`; validate against {`codex`, `cc`}; fail loudly otherwise.

**Batch mode:** on the `batch` keyword, read `references/batch-mode.md` and follow it
(builder detection, evidence-honesty criteria, provenance, fallback, CONSENT-3 all
live there). The rest of this body is Pattern C.

## Phase 1 — Guard and scope

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-shipped-refs.sh"` if it exists. Exit 1
→ a committed `docs/`/`skills/` file references an untracked dated local artifact;
fix the leak before commit. Exit 2 → environment problem; resolve and re-run. Exit 0
→ proceed. (Best-effort floor; the reviewers' grounded judgment remains the semantic catch.)

Diff target: the argument if given; else the project CLAUDE.md's declared diff path;
else `git diff HEAD`.

- [ ] Shipped-ref guard exit code acted on; diff target resolved.

## Phase 2 — Select reviewers

The generic reviewer **self-selects domain lenses** from the diff (idioms, type
safety, performance, language-specific security — no enumerated catalogue). A
separate specialist dispatch fires ONLY for the two deep domains below, and only
when the diff *meaningfully* touches the domain — prefer skipping in ambiguous
cases; false positives waste agents. If `solo = true`, skip specialists entirely.

**security-reviewer** — dispatch when the diff alters an
`untrusted-source → dangerous-sink` path (a data-flow condition: adversary-controlled
input reaching a harmful capability). An internal interface is a security boundary
only at a trust-level transition; JWT/CORS/SSRF are example pairings, not the rule.

**database-reviewer** — dispatch when the diff touches persistence *structure*:
schema, migrations, data contracts (ORM models / transaction boundaries / indexes).
Application-layer changes that merely reference DB entities do not qualify.

**Regression-presence note:** "a fix commit should carry a regression test" fires on
fix commits regardless of whether test files are touched (gating on test-files-touched
would skip exactly the commits that need it). It belongs to the generic review
(check 7 of the generic-diff prompt), not the test-evidence lens.

## Phase 3 — Dispatch in parallel

Launch all reviewers in a **single message**, each `run_in_background: true`:

- **Primary:** generic Sonnet reviewer (`model: "sonnet"`) with the `generic-diff`
  prompt from `references/reviewer-prompts.md`. If `force_reviewer = codex`, dispatch
  `codex-reviewer` instead, with the Pattern-B envelope shape
  `{ task: <diff>, role: "reviewer", task_dir: <optional> }`.
- **Specialists (as selected):** a generic Sonnet agent carrying the
  `specialist-reviewer` prompt from `references/reviewer-prompts.md`, inlined with
  the **security** or **database** domain block (touchstone's own invariant-based
  prompt — never the ECC specialist agents; see README for why).
- **Specific-file invocation** (`/touchstone:code-review path/to/file`): use the
  `specific-file` prompt; add specialists only per Phase-2 conditions.

- [ ] All reviewers launched in one message; none reviewed inline.

## Phase 4 — Aggregate and fix

Wait for ALL reviewers. Merge findings into one table, deduplicating; on severity
disagreement keep the higher; mark each finding's source reviewer.

1. **Critical/High** — fix immediately, no asking.
2. **Medium** — note in report, defer to batch review.
3. **Low** — fix inline only if trivial (≤2 lines, no structural change); else note.
   No cross-commit ledger of deferred Lows.
4. **Post-fix sweep** — after any Critical/High fix, re-read the fix diff itself:
   is it complete, does it break an adjacent behaviour, does the same defect survive
   at a sibling site? Fixes are the one diff no reviewer saw.
5. **Changed-AC re-check** — when the commit claims an AC discharged (AC id in the
   commit message or task brief), confirm that AC's Then-clause against the diff.
   Changed ACs only, never the full table; a green suite is not the confirmation.

No re-review loop in Pattern C — per-commit scope is too small (batch owns that).
The post-fix sweep above is a self-read of the fix diff, not a re-dispatch.

- [ ] Every Critical/High fixed + post-fix sweep done; claimed ACs re-checked.

## Phase 5 — Report

```markdown
## Patch Review: {target}

**Reviewers dispatched:** generic Sonnet{, security-reviewer}{, database-reviewer}

| # | Issue | Severity | Source | Action |
|---|---|---|---|---|
| 1 | ... | Critical | Sonnet | Fixed: ... |
| 2 | ... | Medium | Sonnet | Deferred to /touchstone:code-review batch |
| 3 | ... | Low | Sonnet | Fixed inline (trivial) |

Ready to commit: {yes/no}
```

## Related

- Rationale (Pattern B, generic-Sonnet choice, specialist cap) + Dependencies: `README.md`.
