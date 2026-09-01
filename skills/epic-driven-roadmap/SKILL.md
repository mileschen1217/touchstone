---
name: epic-driven-roadmap
kind: workflow
description: |
  Scaffold, maintain, and audit a project's epic-driven roadmap. Invoke when: starting a
  new epic, closing an epic, or auditing status drift.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
user-invocable: true
---

# epic-driven-roadmap

One generated `ROADMAP.md` at the project root — a projection, never
hand-edited; one tracker per epic at
`.touchstone/epics/YYYY-MM-DD-<slug>/epic.yaml` (dir = start date + slug), the
schema-validated birth form and the status enum's single home. Trackers are
shallow: facts plus pointers to content docs (specs, plans, research). Design
prose, rationale, and research findings belong in a content doc, never in the
tracker.

Three procedures: **Scaffold** a new epic, **Close** an epic, **Audit**
tracker health. Skip this skill entirely if the project has no
`.touchstone/epics/` dir — nothing to maintain yet.

## Scaffold a new epic

Procedure (foundation elicitation first — requires a live, responsive user) →
[`references/scaffold.md`](references/scaffold.md).

## Close an epic

Procedure plus Evidence Reckoning and the Disposition pass →
[`references/close.md`](references/close.md).

## Audit

`bash "${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-render.sh" --root <project-root> --audit`
— staleness and invalid-dir findings; a stale generated `ROADMAP.md` is caught
on the commit rail's freshness check. The status-drift and broken-link classes
dissolved with the hand-written tracker (generated output cannot drift).

