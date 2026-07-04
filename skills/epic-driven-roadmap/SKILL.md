---
name: epic-driven-roadmap
kind: workflow
description: |
  Scaffold, maintain, and audit a project's epic-driven roadmap. Every project
  using this convention keeps a pure-tracker ROADMAP.md plus one tracker per
  epic under .touchstone/epics/<slug>/index.md. Invoke when: starting a new epic,
  closing an epic (retrospective + move to Completed), auditing status drift,
  or bootstrapping the convention in a new project. Concrete paths come from
  the project's CLAUDE.md § Doc Routing; this skill owns the shape, templates,
  and procedures.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# touchstone:epic-driven-roadmap

## Step 0 — Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/config-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, read
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/bridge-content-gate.md` and
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/standing-vs-transient-bridge.md`,
plus § "Four doc kinds" from `${CLAUDE_PLUGIN_ROOT}/CONTEXT.md` — which
define the rules Doc Reckoning applies. This skill does not dispatch
to other skills, so no envelope handoff is needed.

If `source-as-truth` is not adopted: Doc Reckoning runs in default mode (mechanical mtime-based bridge audit only, no frontmatter kind: classification, no distill-or-archive recommendation).

## When to Invoke

- **Scaffold a new epic** — user starts work on a new initiative not yet tracked.
- **Close an epic** — all phases done, needs retrospective + move to Completed table.
- **Audit** — weekly or on demand: status drift between ROADMAP row and epic frontmatter, stale epics, orphans, scope overlap.
- **Bootstrap** — new project adopts this convention (ROADMAP.md + `.touchstone/epics/README.md` + first epic).

Skip if: the project doesn't use this convention (no `ROADMAP.md` or `.touchstone/epics/`).

## The Rule

**Trackers are shallow pointers; content docs hold the detail.**

Trackers (ROADMAP row + epic index) may contain: title, one-sentence aim, status fields, links to content docs, phases table (one row per shippable increment), pivots (one line each), open questions (one line each), retrospective bullets on close.

Trackers may **not** contain: design prose, rationale, research findings, architectural content. Any paragraph longer than one sentence is a rule violation — move it to a content doc and link.

**Status vocabulary:** `proposed | active | paused | done | cancelled`.

## Question-per-stage pipeline

Maps to the 6-stage workflow in `~/.claude/CLAUDE.md`. Concrete paths come from the project's CLAUDE.md § Doc Routing; projects may adjust paths — the convention is the shape, not the directory names.

| Q (stage) | Home (abstract) | Example concrete path |
|---|---|---|
| Why at all? (0) | Project vision / scope | `.touchstone/vision.md`, `ROADMAP.md` scope block |
| Why this epic? (1) | Epic tracker index | `.touchstone/epics/<slug>/index.md` |
| What might work? (2) | Research note | `.touchstone/research/YYYY-MM-DD-<slug>.md` |
| What contract? (3, GWT) | Design spec | `.touchstone/specs/YYYY-MM-DD-<slug>.md` |
| How, in order — epic-level? (4a) | **Epic master plan** (lives with the epic) | `.touchstone/epics/<slug>/<name>-roadmap.md` (only when epic spans 2+ specs) |
| How, in order — per-spec? (4b) | Implementation plan (one per design spec) | `.touchstone/plans/YYYY-MM-DD-<slug>.md` |
| Did it work? (5) | Commits, MRs | Commits, MRs |
| What did we learn? (6) | Retrospective on epic index | Retrospective on epic index |
| Did docs catch up? (7) | Doc Reckoning block on epic index (see "Close an epic + Doc Reckoning") | Doc Reckoning block on epic index |

### Master plan vs. task plan

Two distinct artifacts; do not conflate.

- **Epic master plan (Q4a)** — sequences the epic's phases, locks cross-spec decisions (e.g. "primary gate is X, deprecate Y"), states effort + acceptance per phase, freezes scope so reactive expansion is rejected. Lives **with the epic**: `.touchstone/epics/<slug>/<short-name>.md` (e.g. `v6-3-roadmap.md`, `roadmap.md`, or `master-plan.md`). The epic index links to it. One per epic — not per phase.
- **Task plan (Q4b)** — per-spec implementation plan for a single design spec. Lives under `docs/superpowers/plans/` (or the project's plan path). One per spec.

**When to write a master plan:** an epic that crosses 2+ design specs, locks methodology decisions that bind multiple specs, or needs effort sequencing across phases. Skinny epics (single spec, one PR) skip the master plan and go straight from epic index → spec → plan.

**Master plan vs. epic index:** the index is a **tracker** (one-liners, links). The master plan is **prose with tables** (decisions, phase effort, dependency graph, acceptance criteria). The index links to the master plan; it does not absorb it.

## Procedures

### Scaffold a new epic

Pre-scaffold candidates — ideas not yet shaped into an epic — belong in
`<epics-dir>/_draft-brainstorm.md`; the render script lists them as a Backlog
section in ROADMAP.html.

0. **Foundation elicitation (Baseline — always runs)** — before slugging
   anything, run the 3-field elicitation gate per
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/foundation-gate.md` (read it and
   follow it exactly; reuse check, from-scratch opener, sharpening,
   synthesise, confirm — all canonical emit strings live there). Epic
   scaffold is the ORIGIN of the foundation — no parent to inherit, so always
   run the shared gate from its from-scratch opener (no inheritance pre-step).
   On confirm, record per the template below: aim into the **Aim:** headline,
   intention + out-of-scope into `## Foundation`.
1. Pick a slug — lowercase, hyphen-separated, names the **deliverable surface** (e.g. `port-statistics-stacking`), not a phase number.
2. Read the project's CLAUDE.md § Doc Routing to get the concrete `.touchstone/epics/` path.
3. Write the new epic index directly from the template:

   Read `templates/epic-index.md`, then create `<epics-dir>/<slug>/index.md` by
   writing the template verbatim with the Edit/Write tool. Fill in:
   - frontmatter `slug`, `started` (today's date YYYY-MM-DD), `status: proposed`
   - `**Aim:**` headline
   - `## Foundation` (intention + out-of-scope from the elicitation)
   - Phase 1 row in the `## Phases` table
4. Update `ROADMAP.md` and `ROADMAP.html`.
   - If `${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-render.sh` exists, regenerate both
     ROADMAP files (picks up the new epic automatically):
     ```bash
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-render.sh" --root <project-root>
     ```
   - Otherwise (host without the render script): append the row manually to
     `ROADMAP.md` § Active Epics:
     `| <slug> | <aim> | proposed | — | <epics-dir>/<slug>/index.md |`
5. When creating content docs (research, specs, plans, ADRs) for this epic, add frontmatter `epics: [<slug>]` so the backlink exists from day one. See `templates/content-doc.md`.
6. Commit.

### Close an epic + Doc Reckoning

Procedure (mark phases done, retrospective, ROADMAP move) + the full Doc Reckoning inventory and output template → [`references/close-and-doc-reckoning.md`](references/close-and-doc-reckoning.md).

### Tasks (scaffold / contract scope / close / status)

Task-id convention, contract-scope heuristics (one-contract-vs-split, executor distribution), close steps, and task status vocabulary → [`references/tasks.md`](references/tasks.md).

### Audit

Bidirectional doc-graph integrity — epic-level, link-health, and task-level checks, running them, and report format → [`references/audit.md`](references/audit.md).

### Bootstrap a new project

Four-step convention bootstrap → [`references/bootstrap.md`](references/bootstrap.md).

## Templates

- `templates/ROADMAP.md` — pure-tracker ROADMAP
- `templates/epic-index.md` — epic tracker
- `templates/content-doc.md` — research / spec / plan / ADR / reflection (frontmatter shape only; body is free-form)

Copy verbatim; edit in place.
