# Step-0 Resolver (shared, single home)

Canonical Step-0 for every touchstone reader skill. Callers invoke
it with the pinned phrase; they do NOT inline its logic.

## 1. Read config

Read `${CLAUDE_PROJECT_DIR}/.claude/touchstone.yaml`.

- **Absent** → no config; use `workspace_root = .touchstone`
  (default) and `disciplines = []`. Continue. (But first check
  migration detection §3 — a stale plugin `.swarm/` with no yaml
  is an old-config case.)
- **Present but malformed (parse error)** → print the filename
  and the parse-error location; do NOT enter migration; do NOT
  continue with defaults; exit non-zero.
- **Present + parseable** → continue.

## 2. Derive the path bundle (7 fields)

Let `W = workspace_root` (the parsed value, or `.touchstone` when
the key is absent). Derive:

    bundle.specs       = W/specs
    bundle.adr         = W/docs/adr
    bundle.epics       = W/epics
    bundle.plans       = W/plans
    bundle.archive     = W/archive/specs
    bundle.research    = W/research
    bundle.disciplines = <adopted_disciplines list or []>

Always return all seven fields. Do NOT branch on which caller
invoked the resolver — every caller gets the same bundle.

## 3. Legacy state detection → propose → confirm → execute

Canonical state for this version: `workspace_root = .touchstone`,
cfg = `.claude/touchstone.yaml`, `schema_version: 2`.

Detection: observed project state doesn't match the canonical. The
agent reads the Lineage section below to recognize what the observed
shape was (which previous canonical) and constructs a concrete
migration proposal.

On detection: PRESENT the proposal to the user and execute ONLY on
explicit confirmation. On decline, abort with no destructive action.
Edge cases (target exists, partial migration, multiple legacy markers)
are surfaced in the proposal for the human to decide. This is a
one-time per consumer operation; the human gate, not a state machine,
owns correctness.

### Lineage (data, not control)

<!-- LINEAGE-PROTECTED: literal legacy names below. Do NOT sed-sweep this block during future renames; legacy strings must persist verbatim for detection to work. -->

Newest-first list of previous canonicals; agent reads to recognize
observed legacy state:

- **v0.1.x**: `workspace_root = .m-workflow`, cfg = `.claude/m-workflow.yaml`, `schema_version: 2` (yaml shape unchanged from canonical; legacy is the path names).
- **pre-v0.1**: `workspace_root = .swarm`, no cfg (recognized by `.swarm/` substructure with `.swarm/epics/`, `.swarm/specs/`, `.swarm/docs/adr/`). Legacy yaml keys if any cfg ever existed: `specs_dir`, `adr_dir`, `epics_dir`, `plans_dir`, `archive_specs_dir`, `discovery_dir`, `created_by_plugin_version`, `template`, `lenses`, `matrix`. `schema_version: 1` is the pre-v0.1 marker.
