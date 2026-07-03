---
kind: workflow
adr_id: 0029
status: Accepted
date: 2026-07-03
kill-on: git-hooks-subsumed-by-external-ci-gate
---

# ADR-0029: Git hooks are not shipped in the plugin; this repo installs wrappers locally

## Status

Accepted. Decided 2026-07-03 during the workflow-mechanization Phase 1 audit, when the
question arose: should the touchstone plugin ship git hooks so all plugin users inherit them?

## Context

The touchstone plugin ships as a Claude Code plugin — skills, agents, and hooks under
`.claude-plugin/` and `hooks/`. The Claude Code runtime fires `hooks/run-project-checks.sh`
via the `PreToolUse(Bash)` hook whenever the agent executes a `git commit` or `git push`
command.

This covers agent-issued commits. But a developer can bypass Claude Code entirely and run
`git commit` directly from a terminal. In that case the `PreToolUse` hook never fires, and
the `.touchstone/checker/<stage>/check-*.sh` suite does not run.

The natural fix would be to ship `pre-commit` and `pre-push` git hook scripts as part of
the plugin. That approach fails for two reasons:

1. **Multi-repo non-distributability.** A Claude Code plugin is installed once, globally.
   Git hooks, however, must live inside each repository's `.git/hooks/` (or the directory
   pointed to by `core.hooksPath`). There is no automatic mechanism by which a CC plugin
   install writes hooks into multiple target repositories. A plugin author cannot distribute
   git hooks to end-user repos — the end user must install them into each repo themselves.

2. **Worktree scoping.** Each git worktree has its own hooks directory (returned by
   `git rev-parse --git-path hooks`), which may differ from `.git/hooks`. Shipping a
   single hook path would silently miss worktrees unless the installer explicitly queries
   and populates each one.

## Decision

Git hooks are **not shipped** in the plugin. Instead:

1. **`scripts/install-git-hooks.sh`** — a one-shot, idempotent installer that writes thin
   `pre-commit` and `pre-push` wrappers into the current repo's hooks directory (resolved
   via `git rev-parse --git-path hooks`, which is worktree-safe). The wrappers glob-execute
   `.touchstone/checker/<stage>/check-*.sh` using the same convention as
   `hooks/run-project-checks.sh`. Developers run this once per repo or worktree.

2. **Belt-and-suspenders**: the CC `PreToolUse` hook and the git hooks serve the same
   checker suite from different call sites — the CC hook covers agent commits, the git
   hooks cover terminal commits. Either can run alone; together they close the gap.

## Trust grade

Both mechanisms are **same-uid forcing-grade**: an agent or a developer can bypass them
with `git commit --no-verify`. They are not unforgeable. The unforgeable enforcement layer
is an external CI gate (running on a separate system with independent credentials), which
is outside the scope of this decision. CI integration is tracked separately.

## Consequences

- Developers must run `bash scripts/install-git-hooks.sh` once per repo / worktree to
  activate terminal-commit checking. This is intentional friction rather than hidden magic.
- The installer refuses to overwrite a foreign hook (one without its marker comment), so
  existing pre-commit setups are not clobbered silently.
- Re-running the installer is safe (idempotent): it detects its own marker and updates
  the wrapper in place.
- Future work: a CI gate closes the unforgeable tier. This ADR records the same-uid ceiling
  explicitly so the gap is visible, not papered over.

## Related ADRs

- ADR-0025 (test-evidence review lens) — the same-uid ceiling documented here applies
  equally to the test-quality gate; external CI is the shared escalation path.
