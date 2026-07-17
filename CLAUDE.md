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

- **Authoring rules — single home: `docs/skill-authoring-template.md`.** Read it before writing or reviewing any `skills/` or `agents/` markdown. It carries the binding two-sentence standard (layer calibration + form economy), the fat classes F1–F5, the essence-rewrite procedure, and the suite rules (incl. no-ADR-numbers-in-bodies, actor-named MUSTs, destination naming). This section adds only the project deltas below and restates none of it.
- **ADR-citation routing (project delta).** Legitimate ADR citations live in `CONTEXT.md` (the authority ledger), `docs/`, and test assertions that verify an ADR file exists; ADRs' home is `docs/adr/`, indexed from `CONTEXT.md`.
- **Cold-reviewer self-containment.** Any lens / doctrine a *cold-dispatched* reviewer must apply MUST be either defined inline in the dispatch prompt or load-and-injected from a `_shared/inject/` fragment — never named without a usable definition (the cold reviewer cannot see `CONTEXT.md`). A union/multi-lens review's lenses must be grounded to **equal depth** — one lens injected + another merely named is the defect that shipped the design-soundness gap (PR #27).
- **Single-home restatement (review lens).** When reviewing a diff that touches `skills/` or `agents/` markdown, flag any prose that names a single home or injected fragment and then restates that home's content — the legitimate form is pointer + the caller's own delta, never pointer + copy. Also flag a rule sentence that merely restates a rule homed elsewhere. (Reviewer-time lens; the author-time rewrite rules for this class are `docs/skill-authoring-template.md` F2/F5 — this sentence is the review trigger, not a copy of their fix procedure.)

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
- Md-surface budget (net-byte ratchet over `skills/`+`agents/`): `bash scripts/check-md-surface-budget.sh`
- Run tests: `bash scripts/tests/run-all.sh`
- Lint test shell: `shellcheck scripts/tests/*.sh`
- Plugin reload after edits: `/reload-plugins`
- Smoke test: install plugin in a clean repo, run `/touchstone:init`, exercise stage skills. After deploying a new version (`/plugins update` → `/reload-plugins`), run `bash scripts/deployed-smoke.sh` to verify the cache.

## Versioning (the plugin is the deliverable)

The plugin is deployed from a **version-keyed cache** — an unchanged version string never reaches the user, no matter what merged. So **any PR that changes shipped surface (the path set defined in `.touchstone/shipped-surface.txt`) MUST bump `version` in `.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json`** (keep the two in lockstep). Bump **in the feature PR itself**, not as a separate release commit that is easy to forget (the `#27` precedent; the standalone `chore(release)` commit is also acceptable but only when it actually happens). Minor bump for new feature/skill content, patch for fixes. This is a Ship-Gate item (`CLAUDE.local.md`), and a mechanization candidate (a pre-push check: diff touches shipped surface AND `plugin.json` version == `origin/main` → fail).

## Stage Routing

Defer to global `~/.claude/CLAUDE.md`. The `touchstone:*` skills are this project's own subject matter — use them dogfood-style.
