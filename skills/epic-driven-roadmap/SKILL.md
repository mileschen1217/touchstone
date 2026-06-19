---
name: epic-driven-roadmap
kind: workflow
description: |
  Scaffold, maintain, and audit a project's epic-driven roadmap. Every project
  using this convention keeps a pure-tracker ROADMAP.md plus one tracker per
  epic under .touchstone/epics/<slug>/index.md. Invoke when: starting a new epic, <!-- phase-2-carve-out -->
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

# m-epic-driven-roadmap

## Step 0 — Load vocabulary

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/step0-resolver.md`
> with the Read tool and follow it exactly.

If `source-as-truth` is in `bundle.disciplines`, read 3 sections of
`${CLAUDE_PLUGIN_ROOT}/CONTEXT.md` — § "Bridge content gate", § "Standing
vs transient bridge", § "Four doc kinds" — which define the rules Stage 7
doc reckoning applies. This skill does not dispatch to other skills, so no
envelope handoff is needed.

If `source-as-truth` is not adopted: Stage 7 doc reckoning runs in default mode (mechanical mtime-based bridge audit only, no frontmatter kind: classification, no distill-or-archive recommendation).

Pure-tracker roadmap + per-epic tracker convention. CLAUDE.md routes here; this skill owns the rule and the templates.

## When to Invoke

- **Scaffold a new epic** — user starts work on a new initiative not yet tracked.
- **Close an epic** — all phases done, needs retrospective + move to Completed table.
- **Audit** — weekly or on demand: status drift between ROADMAP row and epic frontmatter, stale epics, orphans, scope overlap.
- **Bootstrap** — new project adopts this convention (ROADMAP.md + `.touchstone/epics/README.md` + first epic). <!-- phase-2-carve-out -->

Skip if: the project doesn't use this convention (no `ROADMAP.md` or `.touchstone/epics/`). <!-- phase-2-carve-out -->

## The Rule

**Trackers are shallow pointers; content docs hold the detail.**

Trackers (ROADMAP row + epic index) may contain: title, one-sentence aim, status fields, links to content docs, phases table (one row per shippable increment), pivots (one line each), open questions (one line each), retrospective bullets on close.

Trackers may **not** contain: design prose, rationale, research findings, architectural content. Any paragraph longer than one sentence is a rule violation — move it to a content doc and link.

**Status vocabulary:** `proposed | active | paused | done | cancelled`.

## Question-per-stage pipeline

Maps to the 6-stage workflow in `~/.claude/CLAUDE.md`:

| Q (stage) | Home (abstract) |
|---|---|
| Why at all? (0) | Project vision / scope |
| Why this epic? (1) | Epic tracker index |
| What might work? (2) | Research note |
| What contract? (3, GWT) | Design spec |
| How, in order — epic-level? (4a) | **Epic master plan** (lives with the epic) |
| How, in order — per-spec? (4b) | Implementation plan (one per design spec) |
| Did it work? (5) | Commits, MRs |
| What did we learn? (6) | Retrospective on epic index |
| Did docs catch up? (7) | Doc Reckoning block on epic index (see "Close an epic") |

Concrete paths live in the project's CLAUDE.md § Doc Routing.

### Master plan vs. task plan

Two distinct artifacts; do not conflate.

- **Epic master plan (Q4a)** — sequences the epic's phases, locks cross-spec decisions (e.g. "primary gate is X, deprecate Y"), states effort + acceptance per phase, freezes scope so reactive expansion is rejected. Lives **with the epic**: `.touchstone/epics/<slug>/<short-name>.md` (e.g. `v6-3-roadmap.md`, `roadmap.md`, or `master-plan.md`). The epic index links to it. One per epic — not per phase. <!-- phase-2-carve-out -->
- **Task plan (Q4b)** — per-spec implementation plan for a single design spec. Lives under `docs/superpowers/plans/` (or the project's plan path). One per spec.

**When to write a master plan:** an epic that crosses 2+ design specs, locks methodology decisions that bind multiple specs, or needs effort sequencing across phases. Skinny epics (single spec, one PR) skip the master plan and go straight from epic index → spec → plan.

**Master plan vs. epic index:** the index is a **tracker** (one-liners, links). The master plan is **prose with tables** (decisions, phase effort, dependency graph, acceptance criteria). The index links to the master plan; it does not absorb it.

## Procedures

### Scaffold a new epic

0. **Foundation elicitation (Baseline — always runs)** — before slugging
   anything, run the 3-field elicitation gate per
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/foundation-gate.md` (read it and
   follow it exactly; reuse check, from-scratch opener, sharpening,
   synthesise, confirm — all canonical emit strings live there). Epic
   scaffold is the ORIGIN of the foundation — no parent to inherit, so always
   run the shared gate from its from-scratch opener (no inheritance pre-step).
   On confirm, record per the template below: aim into the **Aim:** headline, <!-- phase-2-carve-out -->
   intention + out-of-scope into `## Foundation`. <!-- phase-2-carve-out -->
   This is the highest-ROI step — it prevents a spec being written for the
   wrong scope.
1. Pick a slug — lowercase, hyphen-separated, names the **deliverable surface** (e.g. `port-statistics-stacking`), not a phase number.
2. Read the project's CLAUDE.md § Doc Routing to get the concrete `.touchstone/epics/` path. <!-- phase-2-carve-out -->
3. Write the new epic index via the adapter:

   ```bash
   python skills/epic-driven-roadmap/adapters/local-markdown/cli.py write --slug "$SLUG" \
     --field slug="$SLUG" \
     --field started="$(date +%Y-%m-%d)" \
     --field status=proposed
   ```

   Then populate `**Aim:**`, `## Foundation`, `owner_teams`, and Phase 1 into the created <!-- phase-2-carve-out -->
   `<epics-dir>/<slug>/index.md`. If exit code is non-zero, surface the typed error class <!-- phase-2-carve-out -->
   from stderr and stop — do not proceed with partial data.
4. Add a row to `ROADMAP.md` § Active Epics: `| <slug> | <aim> | proposed | [index](<epics-dir>/<slug>/index.md) |`. <!-- phase-2-carve-out -->
5. When creating content docs (research, specs, plans, ADRs) for this epic, add frontmatter `epics: [<slug>]` so the backlink exists from day one. See `templates/content-doc.md`.
5. Commit.

### Close an epic + Stage 7 Doc Reckoning

Procedure (mark phases done, retrospective, ROADMAP move) + the full Stage-7 doc-reckoning inventory and output template → [`references/close-and-stage7.md`](references/close-and-stage7.md).

### Tasks (scaffold / contract scope / close / status)

Task-id convention, contract-scope heuristics (one-contract-vs-split, executor distribution), close steps, and task status vocabulary → [`references/tasks.md`](references/tasks.md).

### Audit

Bidirectional doc-graph integrity — epic-level, link-health, and task-level checks, running them, and report format → [`references/audit.md`](references/audit.md).

### Bootstrap a new project

Four-step convention bootstrap → [`references/bootstrap.md`](references/bootstrap.md).

## Path schema (project CLAUDE.md § Doc Routing)

Each project fills in concrete paths for the Q-per-stage pipeline:

| Q (stage) | Example concrete path |
|---|---|
| Why at all? (0) | `.touchstone/vision.md`, `ROADMAP.md` scope block |
| Why this epic? (1) | `.touchstone/epics/<slug>/index.md` | <!-- phase-2-carve-out -->
| What might work? (2) | `.touchstone/research/YYYY-MM-DD-<slug>.md` |
| What contract? (3) | `.touchstone/specs/YYYY-MM-DD-<slug>.md` |
| How, in order — epic? (4a) | `.touchstone/epics/<slug>/<name>-roadmap.md` (only when epic spans 2+ specs) | <!-- phase-2-carve-out -->
| How, in order — per-spec? (4b) | `.touchstone/plans/YYYY-MM-DD-<slug>.md` |
| Did it work? (5) | Commits, MRs |
| What did we learn? (6) | Retrospective on epic index |

Projects may adjust paths; the convention is the shape, not the directory names.

## Templates

- `templates/ROADMAP.md` — pure-tracker ROADMAP
- `templates/epic-index.md` — epic tracker <!-- phase-2-carve-out -->
- `templates/content-doc.md` — research / spec / plan / ADR / reflection (frontmatter shape only; body is free-form)

Copy verbatim; edit in place.
