# Config Resolver (shared, single home)

Reads `touchstone.yaml` and derives the path bundle. Callers invoke it
with the pinned phrase; they do NOT inline its logic.

## 1. Read config

Read `${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml`.

- **Absent** → no config; use `workspace_root = .touchstone`
  (default). Continue.
- **Present but malformed (parse error)** → print the filename
  and the parse-error location; do NOT continue with defaults;
  exit non-zero.
- **Present + parseable** → continue.

## 2. Derive the path bundle (6 fields)

Let `W = workspace_root` (the parsed value, or `.touchstone` when
the key is absent). Derive:

    bundle.specs       = W/specs
    bundle.adr         = W/docs/adr
    bundle.epics       = W/epics
    bundle.plans       = W/plans
    bundle.archive     = W/archive/specs
    bundle.research    = W/research

Always return all six fields. A legacy `adopted_disciplines` yaml key is
ignored — `source-as-truth` is always on. Do NOT branch on which caller
invoked the resolver — every caller gets the same bundle.

**Epic-scoped placement rule.** When the caller names an epic, that work's
artifacts (specs, research, plans) live in the epic's own dir
`bundle.epics/<epic-dir>/` (dir = `YYYY-MM-DD-<slug>` for new epics;
grandfathered dirs may be undated) — they travel with the epic through
close's Disposition pass. `bundle.specs` / `bundle.research` / `bundle.plans` are
the standalone fallback for work with no epic.
