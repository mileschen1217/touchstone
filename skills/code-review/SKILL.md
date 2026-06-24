---
name: code-review
description: |
  Code review with caller-declared mode. Default: per-commit (Pattern C — generic Sonnet reviewer in parallel with security/database specialists when warranted, all in fresh context). `batch` mode: logical commit group (Pattern B — vendor-not-builder reviews; default = Codex reviews when CC builds). Mode is explicit via `batch` keyword; no commit-count heuristic. Renamed from `m-patch-review`.
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
- **Always:** generic Sonnet reviewer (primary) — carries language-appropriate scrutiny inferred from the diff
- **Conditional (AI-judged):** `security-reviewer` if the diff alters an untrusted-source → dangerous-sink path; `database-reviewer` if the diff touches persistence structure (schema / migration / data contract)

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
/touchstone:code-review solo                     # Pattern C; primary reviewer only — skip security/DB specialists
/touchstone:code-review solo with codex          # Pattern C; codex-reviewer alone, no specialists
```

The `batch` keyword is the explicit per-batch (Pattern B) trigger. Without it, even a multi-commit range invocation defaults to Pattern C applied per-commit.

The `with <vendor>` modifier overrides reviewer routing. See parse details in `## Argument parsing` below.

The `solo` modifier disables the parallel specialist fan-out (security-reviewer, database-reviewer). Useful when the diff is small / single-purpose and specialists would be noise.

## Argument parsing

Parse the args string left-to-right:
1. If first token is `batch` → `mode = batch`, advance.
2. Next token, if not `with` / `solo`, is treated as commit-ish (Pattern C) or range (Pattern B).
3. If `solo` appears anywhere → `solo = true` (disables specialist fan-out). Pattern B already implies solo (single reviewer); `solo` on Pattern B is a no-op.
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

**If `solo = true`,** skip Step 2 entirely — go straight to Step 3 with the primary reviewer alone (Sonnet, or codex-reviewer if `force_reviewer = codex`). No security/DB specialists.

### Step 2: Detect domain concerns

Read the diff briefly. Dispatch a specialist only if the diff *meaningfully*
touches the domain — not just mentions a keyword.

**security-reviewer** — fires on a **data-flow** condition: the diff alters an
`untrusted-source → dangerous-sink` path. Judge by data provenance (does
adversary-controlled input reach this code?) and sink danger (does the code drive
a harmful capability?). An internal interface is a security boundary only at a
trust-level transition. Signals like JWT, CORS, and SSRF are examples of
untrusted-source/dangerous-sink pairings, not the trigger rule. False positives
waste agents — prefer skipping in ambiguous cases.

**database-reviewer** — fires on a **structural** condition: the diff touches
persistence operations, schema definitions, migration files, or data contracts
(ORM models / transaction boundaries / index definitions). Pure application-layer
changes that reference DB entities without altering persistence structure do NOT
warrant dispatch.

### Step 3: Dispatch reviewers in parallel

Never review inline — always spawn separate agents. Launch all reviewers in a
**single message** with multiple Agent tool calls, all with `run_in_background: true`.

**Primary reviewer:**
- If `force_reviewer = codex` → dispatch `codex-reviewer` instead of the generic Sonnet reviewer below. Pass the diff in the same envelope shape used by Pattern B (`{ task: <diff>, role: "reviewer", task_dir: <optional> }`). Specialists (security / DB) still dispatch in parallel per below.
- Otherwise (default, or `force_reviewer = cc`) → generic Sonnet reviewer (`model: "sonnet"`), dispatched with the `generic-diff` prompt from `references/reviewer-prompts.md`. The generic reviewer applies language-appropriate scrutiny inferred from the diff's languages (idioms, type safety, performance, language-specific security) — no enumerated language list; this covers shell, markdown, and any other language in the diff.

> _Why a generic Sonnet agent here, not the dedicated `everything-claude-code:code-reviewer` (which `batch` mode does use):_ per-commit is the hot path. Keeping it on a generic Sonnet agent + touchstone's own `generic-diff` prompt avoids a hard dependency on the everything-claude-code plugin and keeps the per-commit review philosophy under touchstone's control. The dedicated cross-vendor agents (`codex-reviewer` / `everything-claude-code:code-reviewer`) come in at `batch` (Pattern B), where vendor independence carries the most weight.

**security / database review:** dispatched only when AI judgment in Step 2 flagged the
concern. Dispatch a **generic Sonnet agent** (`model: "sonnet"`) carrying the
`security-reviewer` / `database-reviewer` invariant prompt from
`references/reviewer-prompts.md` — touchstone's own invariant-based prompts that
self-generate the specific checks from the domain invariant. These are **not** the ECC
`everything-claude-code:security-reviewer` / `database-reviewer` agents: we deliberately
do not depend on their fixed checklists, for self-containment.

**For specific-file invocation** (`/touchstone:code-review path/to/file`):

Dispatch generic reviewer with the `specific-file` prompt from
`references/reviewer-prompts.md`. Skip domain reviewers unless the file clearly
falls in the security/DB domain per Step 2's conditions.

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

No re-review loop in per-commit mode (Pattern C) — the per-commit scope is too small to justify it
(that is `/touchstone:code-review batch`'s job).

### Step 6: Report

```markdown
## Patch Review: {target}

**Reviewers dispatched:** generic Sonnet{, security-reviewer}{, database-reviewer}

| # | Issue | Severity | Source | Action |
|---|---|---|---|---|
| 1 | ... | Critical | Sonnet | Fixed: ... |
| 2 | ... | High | security-reviewer | Fixed: ... |
| 3 | ... | Low | Sonnet | Fixed inline (trivial) |
| 4 | ... | Medium | Sonnet | Deferred to /touchstone:code-review batch |

Ready to commit: {yes/no}
```

## Related

- Dependencies and the "why Pattern B not Pattern A" rationale: `README.md`.
