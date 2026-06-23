---
name: code-review
description: |
  Code review with caller-declared mode. Default: per-commit (Pattern C — generic Sonnet reviewer in parallel with language/security/database specialists, all in fresh context). `batch` mode: logical commit group (Pattern B — vendor-not-builder reviews; default = Codex reviews when CC builds). Mode is explicit via `batch` keyword; no commit-count heuristic. Renamed from `m-patch-review`.
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

<!-- orientation-inline: none — the "why Pattern B" rationale and Dependencies live in README per ADR-0016 (1a). -->

Parallel reviewers in separate contexts. Fast quality check before commit.

Dispatches:
- **Always:** generic Sonnet reviewer (primary)
- **Conditional:** language-specific reviewer(s) based on changed-file languages
- **Conditional (AI-judged):** `security-reviewer` if the diff touches security-sensitive code; `database-reviewer` if the diff touches DB/SQL/schema

## Usage

```
/touchstone:code-review                          # default: HEAD commit, Pattern C
/touchstone:code-review <commit-ish>             # named single commit, Pattern C
/touchstone:code-review batch                    # logical group (default range: <main>..HEAD), Pattern B
/touchstone:code-review batch <range>            # explicit logical group, Pattern B

/touchstone:code-review with codex               # Pattern C; codex-reviewer replaces generic Sonnet
/touchstone:code-review with cc                  # Pattern C; explicit (no-op — Sonnet is the default)
/touchstone:code-review batch with cc            # Pattern B; force CC reviewer regardless of builder
/touchstone:code-review batch with codex         # Pattern B; force Codex reviewer regardless of builder
/touchstone:code-review solo                     # Pattern C; primary reviewer only — skip language/security/DB specialists
/touchstone:code-review solo with codex          # Pattern C; codex-reviewer alone, no specialists
```

The `batch` keyword is the explicit Pattern B trigger. Without it, even a multi-commit range invocation defaults to Pattern C applied per-commit.

The `with <vendor>` modifier overrides reviewer routing. Recognized vendors: `codex`, `cc`. The modifier is parsed after `batch` (if present) and after the commit-ish/range. Unrecognized values fail loudly: "unknown vendor in `with` modifier — expected `codex` or `cc`".

The `solo` modifier disables the parallel specialist fan-out (language reviewer, security-reviewer, database-reviewer). Useful when the diff is small / single-purpose and specialists would be noise. Pattern B already implies solo (single reviewer); `solo` on Pattern B is a no-op.

## Argument parsing

Parse the args string left-to-right:
1. If first token is `batch` → `mode = batch`, advance.
2. Next token, if not `with` / `solo`, is treated as commit-ish (Pattern C) or range (Pattern B).
3. If `solo` appears anywhere → `solo = true` (disables specialist fan-out).
4. If `with <vendor>` appears, set `force_reviewer = <vendor>`. Validate against {`codex`, `cc`}; fail loudly otherwise.

## Batch Mode (Pattern B)

If invoked with the `batch` keyword → read `references/batch-mode.md` and follow it
(Pattern B vendor-not-builder review). All steps, builder-detection logic, evidence-honesty
criteria, provenance, fallback, and CONSENT-3 checkpoint live there.

## Process

### Step 0: Shipped-ref guard (deterministic pre-check)

Before dispatching reviewers, run `bash scripts/check-shipped-refs.sh` if it exists.
It flags a committed `docs/`/`skills/` file referencing an untracked dated local-doc
artifact (a clone-dangling leak). Exit 1 ⇒ fix the leak before commit. Exit 2 ⇒
environment problem (not at repo root / no git) — resolve and re-run. Exit 0 ⇒ proceed.
This is a best-effort floor; the reviewers' grounded-claims judgment remains the
semantic catch.

### Step 1: Determine diff path

1. If argument provided → use that path directly
2. If project CLAUDE.md defines a diff path → use it (e.g., `dl/` for buildroot)
3. Default: `git diff HEAD`

**If `solo = true`,** skip Step 2 entirely — go straight to Step 3 with the primary reviewer alone (Sonnet, or codex-reviewer if `force_reviewer = codex`). No language reviewer, no security/DB specialists.

### Step 2: Detect languages + domain concerns

Inspect changed file paths from `git diff --name-only HEAD -- {path}`.

**Language mapping** (primary file extension → reviewer agent):
- `.py` → `everything-claude-code:python-reviewer`
- `.rs` → `everything-claude-code:rust-reviewer`
- `.go` → `everything-claude-code:go-reviewer`
- `.ts`, `.tsx`, `.js`, `.jsx` → `everything-claude-code:typescript-reviewer`
- `.java` → `everything-claude-code:java-reviewer`
- `.kt`, `.kts` → `everything-claude-code:kotlin-reviewer`
- `.cpp`, `.cc`, `.cxx`, `.hpp`, `.h`, `.c` → `everything-claude-code:cpp-reviewer`
- `.dart` → `everything-claude-code:flutter-reviewer`
- Other → skip language reviewer

If multiple languages detected, dispatch one reviewer per distinct language.
Skip languages with <10 lines changed (noise threshold).

**Domain-concern judgment (AI, not regex):**

Read the diff briefly. Dispatch the specialist only if the diff *meaningfully*
touches the domain — not just mentions a keyword:

- `security-reviewer` — new/changed auth flows, session handling, password/token
  handling, crypto primitives, input validation at trust boundaries,
  subprocess/exec calls on user input, JWT, CORS, SSRF surface, secret handling.
- `database-reviewer` — new/changed SQL queries, migration files, schema
  definitions, ORM models/relations, transaction boundaries, prepared-statement
  patterns, index definitions.

Variable names that *contain* "user" or "auth" but operate on trusted internal
data do NOT warrant dispatch. False positives here waste agents; prefer skipping
in ambiguous cases.

### Step 3: Dispatch reviewers in parallel

Never review inline — always spawn separate agents. Launch all reviewers in a
**single message** with multiple Agent tool calls, all with `run_in_background: true`.

**Primary reviewer:**
- If `force_reviewer = codex` → dispatch `codex-reviewer` instead of the generic Sonnet reviewer below. Pass the diff in the same envelope shape used by Pattern B (`{ task: <diff>, role: "reviewer", task_dir: <optional> }`). Specialists (language / security / DB) still dispatch in parallel per below.
- Otherwise (default, or `force_reviewer = cc`) → generic Sonnet reviewer (`model: "sonnet"`), dispatched with the `generic-diff` prompt from `references/reviewer-prompts.md`.

**Language reviewer(s):** dispatch one per detected language. Each gets:

```
Review the changes in {diff path} for {language}-specific issues — idioms,
type safety, best practices, performance gotchas, and language-specific
security patterns beyond generic checks.

Report findings as a numbered list tagged [Critical], [High], [Medium], or [Low].
Keep it concise.
```

**security-reviewer / database-reviewer:** dispatched only when AI judgment in
Step 2 flagged the concern. Default prompts from those agents' definitions apply.

**If ECC is not installed**, log "ECC plugin not installed — language-specific
reviewers skipped" and proceed with generic only.

**For specific-file invocation** (`/touchstone:code-review path/to/file`):

Still detect language from the file extension. Dispatch generic reviewer with
the `specific-file` prompt from `references/reviewer-prompts.md`.
Also dispatch the matching language reviewer if ECC is available. Skip domain
reviewers unless the file clearly falls in the security/DB domain.

### Step 4: Aggregate findings

Wait for **all** reviewers to complete. Merge findings into one table,
deduplicating overlaps. If reviewers disagree on severity, use the higher one.
Mark which reviewer(s) found each issue for traceability.

### Step 5: Apply fixes

1. **Critical/High** — fix immediately, no asking
2. **Medium** — note in report, do not fix (save for batch review)
3. **Low** — AI judgment: if the fix is trivial (≤2 lines, no architectural
   change), fix inline; otherwise note and defer. No ledger — don't track
   deferred Lows across commits.

No re-review loop in Pattern C — the per-commit scope is too small to justify it
(that is `/touchstone:code-review batch`'s job).

### Step 6: Report

```markdown
## Patch Review: {target}

**Reviewers dispatched:** generic Sonnet, {language}-reviewer{, security-reviewer}{, database-reviewer}

| # | Issue | Severity | Source | Action |
|---|---|---|---|---|
| 1 | ... | Critical | Sonnet + python-reviewer | Fixed: ... |
| 2 | ... | High | security-reviewer | Fixed: ... |
| 3 | ... | Low | python-reviewer | Fixed inline (trivial) |
| 4 | ... | Medium | Sonnet | Deferred to /touchstone:code-review batch |

Ready to commit: {yes/no}
```

## Related

- Dependencies, the "why Pattern B not Pattern A" rationale, and a Key-Rules summary card: `README.md`.
