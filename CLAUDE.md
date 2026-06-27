# touchstone — Project Instructions

Plugin scaffolding for the touchstone plugin itself. Inherits all rules from `~/.claude/CLAUDE.md` (Review Gate, 6-stage workflow, model allocation, source-of-truth, test quality). This file adds team-shared, project-specific conventions only.

## What this repo is

A Claude Code plugin: skills + commands + agents under `.claude-plugin/`, `skills/`, `agents/`, `commands/`. No compiled code.

## Doc Routing (public surfaces)

| Artifact | Location | Notes |
|---|---|---|
| User-facing docs | `docs/` | Comparisons, design notes, anything for external readers |
| Published ADRs | `docs/adr/` | Final decisions worth sharing |
| Plugin source | `skills/`, `agents/`, `commands/`, `.claude-plugin/` | The plugin itself |
| Scripts | `scripts/` | Migration / audit / smoke helpers |

In-flight work (specs, plans, epics, draft ADRs) is **local-only** — see `CLAUDE.local.md`. Promote to the public surfaces above when an artifact is stable and externally relevant. `ROADMAP.md` is part of this local-only set — it is the machine-local epic tracker indexing `.touchstone/epics/`, gitignored, not a public committed surface (see `CLAUDE.local.md § Local Doc Routing`).

## Skill-body content conventions

- **State the rule, not the ADR.** A `SKILL.md` body states its behaviour/rule self-containedly — it does **not** cite ADR numbers (`ADR-NNNN`) inline. ADRs are the rationale *ledger*; their home is `docs/adr/` (the why), indexed from `CONTEXT.md` (the vocab/authority table). A reader of a skill should learn *what to do* without a lookup. (Where a rationale pointer genuinely helps, point at the **named concept** in `CONTEXT.md`, not the ADR number.) Legitimate ADR citations stay in: `CONTEXT.md` (the authority ledger), `docs/`, and test assertions that verify an ADR file exists.
- **Cold-reviewer self-containment.** Any lens / doctrine a *cold-dispatched* reviewer must apply MUST be either defined inline in the dispatch prompt or load-and-injected from a `_shared/inject/` fragment — never named without a usable definition (the cold reviewer cannot see `CONTEXT.md`). A union/multi-lens review's lenses must be grounded to **equal depth** — one lens injected + another merely named is the defect that shipped the design-soundness gap (PR #27).

## Issue Tracking — GitHub

Shared work moves through GitHub Issues, not committed `.md` files.

- **Epics** → Issue labeled `epic`. Body references the epic slug tracked in the local `ROADMAP.md` (machine-local tracker; the Issue is the shared surface of record — do not link to the local file from the shared Issue).
- **Specs** → If the spec drove a non-trivial change, paste the Acceptance Criteria section or attach the final `.md` to the issue.
- **Plans** → Inline as issue task list, or referenced from the epic.
- **ADRs** → If the decision is final and externally interesting, promote to `docs/adr/` AND link from the relevant issue.

Use `/triage` and `/to-issues` skills to move work from local drafts to GitHub.

## Build / Test

- Lint shell: `shellcheck scripts/*.sh`
- Lint shipped refs: `bash scripts/check-shipped-refs.sh`
- Run tests: `bash scripts/tests/run-all.sh`
- Lint test shell: `shellcheck scripts/tests/*.sh`
- Plugin reload after edits: `/reload-plugins`
- Smoke test: install plugin in a clean repo, run `/touchstone:init`, exercise stage skills.

## Stage Routing

Defer to global `~/.claude/CLAUDE.md`. The `touchstone:*` skills are this project's own subject matter — use them dogfood-style.
