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
- **Execution-precise, not README-style.** A `SKILL.md` body states *only what the executing agent needs to know to run the skill correctly this time* — inputs to resolve, the command / procedure, how to present output, and what NOT to do. It is not documentation: mechanism / rationale / how-it-works narration, and forward-looking or roadmap context (a future layer or mode that does not affect this execution), belong in `README` / `docs` / `CONTEXT.md` or the owning epic — never in the skill body. Test: if a paragraph would not change what the agent *does* on this run, cut it. (A future capability does not help present execution — capture its context in the epic that owns it, not the skill it will one day extend.)
- **Name for the destination, not the current shape.** When a skill is a lean first cut of something that will grow (e.g. a report shell that later gains an analysis layer), name it for what it *is for*, not the thin thing it does today — so adding the later capability does not force a rename and a reference-sweep.
- **Imperative honesty — name the actor, not a phantom mechanism.** A MUST / MUST NOT directed at the executing agent is an honest instruction — keep its full imperative strength. What is dishonest is describing an LLM-followed instruction as a system property ("is Build-blocking", "fires on a condition", "a mechanism forces…") when no hook or script backs it. Write who acts — the reviewer, the caller, *you* — and keep the MUST; claim a mechanism only where an event-bound check (hook / script exit code) actually enforces it.

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

## Versioning (the plugin is the deliverable)

The plugin is deployed from a **version-keyed cache** — an unchanged version string never reaches the user, no matter what merged. So **any PR that changes shipped surface (the path set defined in `.touchstone/shipped-surface.txt`) MUST bump `version` in `.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json`** (keep the two in lockstep). Bump **in the feature PR itself**, not as a separate release commit that is easy to forget (the `#27` precedent; the standalone `chore(release)` commit is also acceptable but only when it actually happens). Minor bump for new feature/skill content, patch for fixes. This is a Ship-Gate item (`CLAUDE.local.md`), and a mechanization candidate (a pre-push check: diff touches shipped surface AND `plugin.json` version == `origin/main` → fail).

## Stage Routing

Defer to global `~/.claude/CLAUDE.md`. The `touchstone:*` skills are this project's own subject matter — use them dogfood-style.
