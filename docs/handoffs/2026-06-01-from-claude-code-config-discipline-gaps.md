---
type: handoff
direction: inbound
date: 2026-06-01
from_repo: claude_code_config
from_doc_audit_pointer: claude_code_config/.touchstone/handoffs/2026-06-01-touchstone-discipline-gaps.md
to_epic: doc-discipline-gates
kind: diagnostic
related:
  - .touchstone/epics/doc-discipline-gates/index.md
---

# Inbound handoff — discipline gaps surfaced at AOS Phase 3 close (claude_code_config)

**Stub epic:** `.touchstone/epics/doc-discipline-gates/index.md` (local-only, status: proposed)
**Sender:** `claude_code_config/.touchstone/epics/aos-scan-scaling` (AOS Phase 3 close, 2026-06-01)
**Originating session:** Obsidian project, 2026-06-01 epic-close turn
**Sender's audit pointer:** `claude_code_config/.touchstone/handoffs/2026-06-01-touchstone-discipline-gaps.md` (sender keeps an outbound record; this doc here is the canonical content)

## What this handoff is

Three independent touchstone-tool gaps surfaced at one epic close, in one
sitting. Each is small in isolation but together they reveal that
touchstone's discipline (source-as-truth `kind:`, spec promotion lifecycle,
floor-check enumerability) is enforced at *review time* but not at
*commit time*, and one gate's regex prevents a legitimate spec
convention. The downstream project (`claude_code_config`) has shipped a
working local defense (the pre-commit hook in `scripts/git-hooks/`); this
handoff requests touchstone to consider absorbing the durable parts
upstream.

## The three drifts (evidence)

### 1. Spec promotion gate gap

**Evidence:** `claude_code_config` commit `8cf4f18 docs(aos-backfill):
SKILL.md /m-aos backfill + spec Accepted` (2026-06-01 05:03). The commit
message claimed "spec Accepted" but the actual diff added the spec file
with frontmatter `status: draft` — the promotion claim and the
file content disagreed.

**Discovery:** Stage 8 close ran `scripts/check-spec-floor.sh` on the spec
file. The floor checker exempts draft specs and exited 0 with
`"skipped: draft spec"`. Drift was hidden for 6 days. Only because the
close procedure says "fix the spec — before continuing" did we realize
the spec had never been formally accepted despite shipping 21 tasks
against it.

**Local fix landed:** `claude_code_config/scripts/git-hooks/pre-commit`
Rule 1 (HARD) — if commit message contains "spec Accepted" /
"design Accepted" / "status: accepted", every staged spec under
`.touchstone/specs/` must have frontmatter `status: accepted`, else
block the commit.

**Touchstone-side ask:** `touchstone:design-spec` (or a new helper
sub-action) owns the promote-to-accepted action so the lifecycle is
guarded by tool, not by author memory. Three implementation
sketches in the stub epic Phase 2 (require explicit `accepted_at:` field
/ new promote sub-action / git commit-msg convention). Pick one.

### 2. `kind:` frontmatter absent on shipped docs

**Evidence:** of 11 new `.md` files created under the AOS Phase 3 epic
range, **all 11** have frontmatter `kind:` absent:

- `2026-05-31-aos-lazy-backfill-design.md` (local-only spec draft, source project)
- `2026-06-01-aos-lazy-backfill.md` (local-only plan draft, source project)
- `2026-05-30-aos-scan-bookmark-phase-2.md` (local-only plan draft, source project)
- `docs/adr/0019-bounded-staleness-scan-under-load.md`
- `docs/adr/0020-aos-engine-behavioral-metrics-instrument-at-event.md`
- `docs/adr/0021-aos-lazy-backfill-via-sessionstart-breadcrumb.md`
- `.touchstone/research/backfill-{plan,spec}-review-{v1,v2}/review.md` (4)
- `.touchstone/research/backfill-live-bearing/README.md`

The `source-as-truth` discipline in touchstone's `CONTEXT.md § Bridge
content gate` lists `kind:` as a required frontmatter field for bridge
docs, but no tool enforces it. The discipline was adopted in this project
(`.claude/touchstone.yaml` has `adopted_disciplines: [source-as-truth]`)
but the implicit enforcement is "author remembers" — which failed for
11 consecutive docs over 1 week.

**Local fix landed:** `pre-commit` Rule 2 (SOFT, warn-only) — any `.md`
under `.touchstone/(research|specs|plans|docs)/` should declare
frontmatter `kind:`. Warn-only initially to avoid blocking workflow until
existing docs backfill.

**Touchstone-side ask:** Either extend `scripts/check-spec-floor.sh` to
assert `kind:` (so it runs as part of the floor gate at close), or add a
separate `scripts/check-doc-kind.sh` invoked by `epic-driven-roadmap`
Doc Reckoning. Adoption gate via `.claude/touchstone.yaml` toggle.
(Note: `scripts/check-doc-kind.sh` was never created and is not implemented — gap identified, not built.)

### 3. Floor checker incompatible with lettered sub-AC ids

**Evidence:** `check-spec-floor.sh` run on the AOS spec (after status
flip to `accepted`):

```
VIOLATION: AC-13 has more than one '### AC-13' body block (AC ids must be unique)
VIOLATION: AC-13 has a body block but no index row
RED: 2 violation(s)
rc=1
```

The spec uses `### AC-13a — Commit order observable on clean run`,
`### AC-13b — Kill between bookmark-write and merge-commit`,
`### AC-13c — Kill between merge-commit and pending-record-delete` —
one AC with three independently-testable scenarios (kill windows).
The floor regex `/^### AC-[0-9]+/` strips the letter suffix and
collapses the three to one duplicate `AC-13`.

The lettered convention IS deliberate — these three scenarios share an
AC theme (kill recovery) but each is an independent test target. Forcing
them into AC-13/AC-14/AC-15 would touch 88+ references across the spec,
ADR, code comments, tests, research artifacts, and (historical, immutable)
commit messages and committed codex review artifacts — net negative.

**Local fix:** None — we shipped accepting the floor violation, noting
it in the epic-close retrospective.

**Touchstone-side ask:** Update the body-block regex to
`^### AC-[0-9]+[a-z]?` (or equivalent); index-row regex similarly.
Regression: lettered ACs WITH matching index rows pass; lettered AC
body WITHOUT matching index row still fails (enumerability preserved).
Stub epic Phase 1.

## Recommendation

Pick up the stub epic at maintainer's cadence. Local hook is a working
short-term defense; once Phases 1-3 land, the local hook can be slimmed
or removed.

If you decide NOT to absorb upstream (e.g., the gaps are too project-
specific), close the stub epic with status `cancelled` + a one-line
reason; the local hook stays in `claude_code_config` indefinitely as
the durable solution.

## Provenance

- AOS Phase 3 epic close: `2026-06-01 08:21Z` UTC
- Stub epic created: `2026-06-01` at `.touchstone/epics/doc-discipline-gates/` (local-only per touchstone's `CLAUDE.local.md § Local Doc Routing`)
- Sender's local pre-commit hook commit: `dfe849c` in `claude_code_config` (`feat(git-hooks): pre-commit doc-discipline gate`)
- This handoff lives in touchstone's `docs/handoffs/` (committed, durable across clones); the sender keeps a one-line outbound pointer at `claude_code_config/.touchstone/handoffs/2026-06-01-touchstone-discipline-gaps.md` for audit-trail symmetry.
