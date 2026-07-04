# epic-driven-roadmap skill

Navigation pointer for this skill directory.

## Files

| File | Purpose |
|---|---|
| `SKILL.md` | Entry point — procedures for scaffold, close, audit, bootstrap |
| `references/close-and-doc-reckoning.md` | Close procedure + Doc Reckoning + Evidence Reckoning |
| `references/phase-ship.md` | Phase-ship step: data-point record + insight hand-off |
| `references/tasks.md` | Task convention (id, contract scope, status vocabulary) |
| `references/audit.md` | Bidirectional doc-graph integrity checks |
| `references/bootstrap.md` | Four-step convention bootstrap for new projects |
| `templates/epic-index.md` | Index template (copy verbatim; edit in place) |
| `templates/ROADMAP.md` | ROADMAP template |
| `templates/content-doc.md` | Frontmatter shape for research / spec / plan / ADR |
| `check-close-ready.sh` | Inline close-readiness check (runs at close, shows output) |
| `tests/` | Structural and contract tests over `.md` fixtures |

## Portability model

The local markdown index (`.touchstone/epics/<slug>/index.md`) is the single
source of truth for epic work-content. Shared trackers (GitHub Issues, GitLab,
Jira, Linear) are **downstream projections** of that index — one-way renders
of the shared subset (aim, phases-as-checklist, status, back-link to the repo)
produced at need by the agent. The back-link points to the repo (a clone-stable
public URL), not the local index path (which is machine-local and gitignored).

To project an epic to a tracker: render the index's shared subset onto a card
using `gh issue create` (for GitHub) or a community render skill. No renderer
is pre-built here — add one only when a real consumer exists.

Close-only internal artifacts (retrospective, Doc Reckoning, Evidence Reckoning)
are not projected.

**Full rationale:** `docs/adr/0024-agent-is-the-shim-epic-tracker-projection.md`
(supersedes ADR-0012).
