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

One pure-tracker `ROADMAP.md` at the project root; one tracker per epic at
`.touchstone/epics/YYYY-MM-DD-<slug>/index.md` (dir = start date + slug). Trackers are
shallow pointers — title, one-sentence aim, status, a phases table, links to
content docs (specs, plans, research). Design prose, rationale, and research
findings belong in a content doc, never in a tracker; any paragraph longer
than one sentence here is a rule violation — move it to a content doc and
link.

**Status vocabulary:** `proposed | active | done`.

Three procedures: **Scaffold** a new epic, **Close** an epic, **Audit**
status drift. Skip this skill entirely if the project has neither a
`ROADMAP.md` nor a `.touchstone/epics/` dir — nothing to maintain yet.

## Scaffold a new epic

Procedure (foundation elicitation first — requires a live, responsive user) →
[`references/scaffold.md`](references/scaffold.md).

## Close an epic

Procedure plus Evidence Reckoning and the Disposition pass →
[`references/close.md`](references/close.md).

## Audit

Status drift and doc-graph health — run on demand or weekly:

- **Status drift** — every `ROADMAP.md` row's status must match its epic
  index frontmatter `status:`. Mismatch → finding.
- **Staleness** — any `active` epic whose index is untouched
  (`git log -1 --format=%cs`) for >30 days → flag for push / close.
- **Orphans** — an epic dir with no `ROADMAP.md` row, or a row pointing at a
  missing index → finding.
- **Broken links** — every `[text](path)` in an epic index must resolve;
  dangling → finding naming the source file and the missing target.

Report one line per finding, grouped by check. If a check passes clean, say
so in one sentence; skip sections with no findings.

## Templates

- `templates/epic-index.md` — epic tracker (copy verbatim; edit in place)
- `templates/ROADMAP.md` — pure-tracker ROADMAP
- `templates/content-doc.md` — frontmatter shape for research / spec / plan
  / ADR (body is free-form)
