---
name: design-spec
kind: workflow
description: |
  Generate the contract (spec.yaml) — the one contract shape crucible's full and short
  forms both produce. Invoked by crucible after assay, or directly for a spec revision.
  Skip when no assay record exists yet (crucible first) or the work is a one-shot edit
  outside the workflow.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Skill
user-invocable: false
---

# design-spec

Apply `../.shared/harness-runtime.md` before any host-dependent operation.

Produce `spec.yaml` — fields, not prose — and write it as Draft. Promotion (accept,
build) is downstream; the challenge pass runs inside `design-review` round 1.

**When to invoke** — crucible chooses the contract form (full or short); both
forms produce this same `spec.yaml`, so this skill runs for every contract.

**Load vocabulary** — follow
`<plugin-root>/skills/.shared/config-resolver.md`, then load
`<plugin-root>/skills/.shared/inject/bridge-content-gate.md`. The field set
and every enum live in the spec schema — `check-artifact.sh` is the validation
authority; the skeleton to fill: `template.yaml` beside this file.

## Draft Mode

### 1. Foundation & facts intake

Interface: **facts sources in → spec.yaml out.** Sources are those the caller
or user supplies, or already in context — never glob or hunt for epic indexes
or interview records yourself.

Read `<plugin-root>/skills/.shared/inject/confirmed-facts-source.md`
and follow it exactly for qualification and citation granularity. Delta: a
validation failure (any trigger class) is dispositioned by asking the human or
by a `waiting_on_human[]` entry (a `W-n` object per the schema, the question shaped per
`<plugin-root>/skills/.shared/inject/human-question-template.md`) —
never a silent scope or invariant entry. The
AC layer is authored HERE — a source hands over confirmed facts, never pre-drafted ACs.

**Foundation is inherited, never re-elicited.** Write `foundation: inherit`; the
inherited fields (`foundation.intention` / `aim` / `foundation.out_of_scope`, plus
any owner rulings in `foundation.rulings`) are read from the `epic.yaml` of the
epic the caller names. No `epic.yaml` → stop with one line: "scaffold the epic
first (`invoke_skill(epic-driven-roadmap, scaffold)`) — the foundation is elicited
there."

**Reframe exit** (user reframes during intake, e.g. "this should be a fixture,
not a spec"): STOP, write no file, report "Scope reframed to [X] — a design
spec is not needed. Exiting Draft Mode."

**Ledger.** `facts_source.record` names the assay record; `facts_source.consensus`
lists every ledger id the spec draws on. Any value not derivable from the consensus
cites a ledger id in `basis` (REQ or AC) or `why_ref` (invariant, risk); an
observation or ruling that arises while drafting is APPENDED to the ledger with
`stage: design-spec` and then cited.

### 2. Human-facing fields

`reader: human` fields (`title`, `phase_map`, `user_stories`, `non_goals`, `risks`,
`waiting_on_human`) are written in the owner's language; `reader: agent` fields in
English; identifiers are never translated. `phase_map` — four panels in the reader's
problem vocabulary, ≤3 sentences each, no paths (checker-enforced). `touch_set` — the
agent-facing path lists. `user_stories[]` — one actor-facing want each; authoring
rules: `references/authoring.md § Want-layer authoring`.

### 3. Delta — the structural commitments

`delta.blocks[]` carries every component this spec adds, changes or removes, each with
`purpose`; `edges` / `interfaces` / `contracts` / `flows` carry the dependency,
party-facing, schema and sequence deltas. A structural commitment (a block that hides a
decision, owns state, or sequences calls) is expressed as an AC when a test can
discharge it, otherwise as an `invariants[]` entry with `check: test | grep | review`.
Grade against `<plugin-root>/skills/assay/references/arch-rubric.md` (load it).

### 4. Requirements and acceptance criteria (feedforward ground-and-sweep)

`shall` is ONE normative sentence; every disambiguation lives in the AC layer: an
error path becomes an error-path AC, a cross-cutting rule an invariant, an
interface a `delta.contracts[]` entry cited from the REQ. No key under a REQ or AC
beyond the schema's.

> Read `<plugin-root>/skills/.shared/ground-and-sweep.md` before
> generating ACs. Application: `requirement × current-repo-state` — ground
> each AC in concrete repo facts (file path, line, value); sweep the true
> subject set to saturation, not first-hit. Drafting conventions (ids,
> live_bearing): `references/authoring.md`.

**Baseline-conditional axes (three states, both axes).** A *valid baseline* is a
Consensus entry confirmed for THIS artifact and rule under the intent now in force,
carrying no under-determined mark. Valid → verify the ACs against it (confirm
saturation). Absent or stale → discover at full width (the sweep-to-saturation role
stays). Under-determined → discover AND record the under-determination in
`waiting_on_human[]`.

- **Reach axis** — baseline = the Consensus Scope seam-map, carried on disk by the
  epic's `explore-<date>-<subject>.yaml` where crucible's explore wrote one
  (*seam-map* / *reach-under-determined*:
  `<plugin-root>/skills/.shared/reach-discovery.md`); what is verified = the
  party set.
- **Breadth axis** — baseline = the Consensus case-partition (*case-partition* /
  *partition-under-determined* / the staleness test:
  `<plugin-root>/skills/.shared/breadth-discovery.md`); the claim binds only when
  the REQ or one of its ACs cites the entry's ledger id in `basis` and the REQ's `shall`
  expresses the rule its confirmed content-phrase named — without that citation you are
  partitioning.

**Home-miss (valid-baseline path only).** A party absent from the seam-map is covered
now (added to this spec's party set) AND logged as a `D-n` entry in the epic's
`deviation.yaml` with `which_stage_could_have_caught: explore`; a case the
case-partition omitted routes the same way with `assay`, the entry naming the missing
case, the rule or REQ it belongs to, and the source entry's ledger id. Fix + attribute;
never fix-only nor defer-only.

**5. Internal coverage audit** — for each US-N: if every requirement tracing
to it also traces to ≥1 other want, surface it as a demote-to-invariant
candidate for human judgment — never auto-demote. If none, emit "Coverage
audit: no demote-to-invariant candidates."

## Output

- One file at `YYYY-MM-DD-<feature-name>.spec.yaml`, homed by the
  config-resolver's epic-scoped placement rule: the caller-named epic's dir
  when one is named, else `<specs_dir>`.
- Before reporting, run and show:
  `bash "<plugin-root>/scripts/check-artifact.sh" spec <file> --root <dir>` —
  exit 0 is the floor; a `warn:` line rides to the reviewer.
- **Weight calibration.** The spec's weight is the REQ/AC layer; `phase_map` and
  `user_stories` are the only human-read prose — prose beyond them is cut.
- Terminal summary: spec path, `status: draft`
- Next: crucible writes `accepted-candidate`, then runs `invoke_skill(design-review, …)`
  runs the lens × arm gate before human accept; its rounds converge under the
  gate's own stopping rule — a meaning-changing edit re-enters that gate

## Related

- Skeleton: `<plugin-root>/skills/design-spec/template.yaml`; drafting
  inputs and want-layer authoring: `references/authoring.md`.
- Floor checked downstream by
  `<plugin-root>/scripts/design-review-precheck.sh` (schema validation;
  `--attest` at anvil entry).
