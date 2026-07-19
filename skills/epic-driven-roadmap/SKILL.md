---
name: epic-driven-roadmap
kind: workflow
description: |
  Scaffold, maintain, and audit a project's epic-driven roadmap. Every project
  using this convention keeps a pure-tracker ROADMAP.md plus one tracker per
  epic under .touchstone/epics/YYYY-MM-DD-<slug>/index.md. Invoke when: starting a new
  epic, closing an epic (retrospective + evidence reckoning + move to
  Completed), or auditing status drift. Concrete paths come from the
  project's CLAUDE.md § Doc Routing; this skill owns the shape, templates,
  and procedures.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# epic-driven-roadmap

One pure-tracker `ROADMAP.md` at the project root; one tracker per epic at
`.touchstone/epics/YYYY-MM-DD-<slug>/index.md` (dir = start date + slug). Trackers are
shallow pointers — title, one-sentence aim, status, a phases table, links to
content docs (specs, plans, research). Design prose, rationale, and research
findings belong in a content doc, never in a tracker; any paragraph longer
than one sentence here is a rule violation — move it to a content doc and
link.

**Status vocabulary:** `proposed | active | paused | done | cancelled`.

Three procedures: **Scaffold** a new epic, **Close** an epic, **Audit**
status drift. Skip this skill entirely if the project has neither a
`ROADMAP.md` nor a `.touchstone/epics/` dir — nothing to maintain yet.

## Scaffold a new epic

Requires a live, responsive user — step 0 pauses for an answer before
anything is written.

0. **Foundation elicitation.** Open with: "Please describe the intended work
   in your own words." Sharpen the answer into three fields through a short
   back-and-forth — never ask a design question (architecture, files, APIs,
   effort; deflect those with "that's a design decision for a later stage"):
   **Intention (why)** — the motivation; **Aim** — the one-sentence
   observable outcome (reject vague tokens like "better"/"elegant" — ask
   what the user would observe when the work is done); **Out of scope** —
   up to three routes this epic will NOT take, even if related. Present the
   draft under those three exact labels and ask "Please confirm or edit this
   foundation." Do not proceed until confirmed.
1. Pick a slug — lowercase, hyphen-separated, names the deliverable surface
   (e.g. `port-statistics-stacking`), not a phase number. The epic DIR is
   `YYYY-MM-DD-<slug>` (today's date prefix); frontmatter `slug:` stays the
   pure slug — renderers key on frontmatter, dir name is only a fallback.
   Pre-existing undated epic dirs are grandfathered (rename optional at close).
2. Read the project's CLAUDE.md § Doc Routing for the concrete
   `.touchstone/epics/` path.
3. Read `templates/epic-index.md` and write `<epics-dir>/YYYY-MM-DD-<slug>/index.md`
   verbatim from it, filling in: frontmatter `slug`, `started` (today,
   YYYY-MM-DD), `status: proposed`; the `**Aim:**` headline; `## Foundation`
   (intention + out-of-scope from step 0); the Phase 1 row.
4. Add a row to `ROADMAP.md` § Active Epics (create the file from
   `templates/ROADMAP.md` first if it doesn't exist yet):
   `| <slug> | <aim> | proposed | [index](<epics-dir>/YYYY-MM-DD-<slug>/index.md) |`
5. New content docs for this epic (research, specs, plans, ADRs) get
   frontmatter `epics: [<slug>]` — see `templates/content-doc.md`.
6. Commit.

## Close an epic

Procedure plus Evidence Reckoning, docs-current, and eval-reckon detail →
[`references/close.md`](references/close.md).

## Audit

Status drift and doc-graph health — run on demand or weekly:

- **Status drift** — every `ROADMAP.md` row's status must match its epic
  index frontmatter `status:`. Mismatch → finding.
- **Staleness** — any `active` epic whose index is untouched
  (`git log -1 --format=%cs`) for >30 days → flag for push / pause / close.
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
