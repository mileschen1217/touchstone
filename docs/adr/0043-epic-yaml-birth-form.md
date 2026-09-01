# 0043 — epic.yaml as the epic's birth form; index.md retired to projection

- **Status:** Accepted 2026-09-01 — via the owner's contract accept of the phase-6 spec that builds on this decision (revised the same day after two-arm critique: cc validation 1H/2M/2L + codex pressure-test 2C/3H/4M/2L, both verdict revise; all findings incorporated below); promoted from the local draft area at phase ship
- **Date:** 2026-09-01
- **Deciders:** owner (miles)
- **Triggered by:** `/touchstone:assay` (phase 6, epic human-facing-comm — alignment row A-1, ruling Q-1)
- **Related ADRs:** 0024 (superseded in form, upheld in essence), 0012 (stays dead), 0040
- **Flip-trigger:** (1) a real bidirectional tracker consumer appears — an external tool that *writes* epic state — reopening the storage-adapter question (ADR-0024's original kill-on transfers here unchanged); (2) the owner — or a downstream plugin user — hand-edits epic files and YAML authoring friction becomes observable (authoring-error entries in gate-miss.md; downstream reports). Revisit point: epic-close Evidence Reckoning; the gate-miss ledger is the watch surface.
- **Bet-owner:** the owner — never the AI.
- **Assumptions:** (a) the owner never hand-edits the epic tracker (interview ruling Q-1, 2026-09-01); (b) a schema-validated birth form eliminates the drift class the markdown form permits (exemplar: status enum diverged 5-vs-3 values between `templates/epic-index.md` and `epic-driven-roadmap/SKILL.md:32`); (c) the renderer's legacy dual-read cost is bounded and temporary (archived epics only). Assumption (a) is scoped to this repo's owner; downstream plugin users may differ — see Consequences.

## Context

S1 (the epic index) is the last of the six workflow stations without a structured birth
form: phase 5 gave quiz/assay/explore schema-validated `.yaml` homes, while the epic's own
facts live in hand-authored markdown (`.touchstone/epics/<slug>/index.md`) plus a second
hand-maintained copy (`ROADMAP.md` rows) that an agent must audit for drift.

Observed costs of the unstructured form (2026-09-01 sweep, explore record
`explore-2026-09-01-phase6-s1-agent-load.yaml`):

- **Two-number ambiguity**: the dossier renders index-table row numbers (1–9) beside spec
  phase numbers (1–6); the owner misread the row count as the phase count (gate-miss
  2026-09-01). No single home for phase identity exists.
- **Enum drift defect**: the status enum differs between the template and the skill body
  (5 vs 3 values); prose has no checker.
- **Manual twin**: ROADMAP.md rows are written by hand at scaffold and edited at close;
  an Audit procedure exists solely to detect their drift from index frontmatter.
- **Hook asymmetry**: `hooks/render-on-write.sh` regenerates the dossier only on `.yaml`
  writes — index.md edits never trigger a render.
- `epic.yaml` has **zero readers today** (whole-tree grep) — the name is unclaimed.

Standing decision in force: **ADR-0024 "the agent is the shim"** — tracker portability by
one-way projection, no storage adapter (killed ADR-0012's ~1100-LOC adapter); its text
also fixes *index.md* as the single source of truth.

## Decision

**Full migration.** For live and future epics, the epic's facts are authored in
`epic.yaml` (schema `skills/_shared/schemas/epic.schema.yaml` — new file, ships with the
implementing spec — validated by `check-artifact.sh` kind `epic`): slug/status/started/
landed, aim, foundation (intention, out-of-scope), `phases[]` (the *only* home of phase
number, title, spec link, status, landed), pivots, open questions, docs[]. Close-time
evidence (Evidence Reckoning rows, Disposition) is **structured fields, not markdown
block scalars** — block scalars are reserved for display-only prose (Retrospective
buckets), so the loose-section parsing problem is not recreated inside a scalar.

### Migration order — gated, reader-first (critique C-1/H-1)

1. **Reader first**: `dossier-render.sh` learns to read `epic.yaml`; its hard gate
   (`:73`, exit 1 when `index.md` absent) and every epic-level `index.md` field read
   (`:261-264`, `:728-729`, `:1566`, `:1720`) gain the yaml-born path.
2. **Prove**: a smoke fixture of an epic dir containing `epic.yaml` and **no**
   `index.md` renders green.
3. Only then: stop authoring `index.md`; the live pilot (this epic) migrates.

**Precedence is deterministic** (critique H): an active epic that has `epic.yaml`
ignores `index.md` entirely; an archived epic without `epic.yaml` uses the legacy read
path; an active epic carrying BOTH authored forms is a checker error unless `index.md`
carries a generated-projection marker.

### Projection mechanism — named (critique H-2/M-3)

`ROADMAP.md` becomes the output of a projection script (`scripts/roadmap-render.sh`,
new) over the epic.yaml set: generated header naming source + content hash, atomic
temp-file rename, and a pre-commit/pre-push freshness check (re-render + diff = clean,
the mechanical replacement for the dissolved status-drift audit). Staleness/orphan
checks move into this script; the hand-written twin and its agent-run audit retire.

### Retirement list — blockers, not cleanup (critique H-3/M-2)

The operating prose that today instructs the agent to author/edit `index.md` is part of
the migration's **blocking** change set, named file:line: `epic-driven-roadmap/
SKILL.md:60,66,94` (scaffold steps, ROADMAP row, templates list), `references/
close.md:28,32` (close edits), `check-close-ready.sh` + close-ready fixtures (retire
into `check-artifact.sh` kind `epic`), `templates/epic-index.md` (replaced by
`templates/epic.yaml` — a birth template with green + minimal fixtures; the schema alone
is not the authoring guide), `templates/ROADMAP.md` (retired into the projection
script). A repo-wide sweep retires residual "index.md is the single source" language
(historical ADR context exempt).

### The close gate keeps its cross-file teeth (critique C-2)

`check-artifact.sh epic --root <epic-dir>` is a **cross-file close gate**, not shape
validation: it enumerates every accepted `*.spec.yaml`'s ACs, requires each reckoned,
enforces live-bearing provenance and waiver-row rules, and carries a red fixture per
blocking rule. The close-readiness honesty floor moves without weakening — "done ⇒
retrospective present" must not degrade into "block scalar non-empty". It also verifies
**phase-identity consistency across files** (critique M-1): `phases[].number` ↔ the
linked spec's top-level `phase:` ↔ deviation/quiz phase references.

**ADR-0024 disposition: upheld in essence, superseded in form.** The essence — the agent
projects, one-way, no storage adapter, no bidirectional sync — is untouched. Only the
clause naming *index.md* as the single source transfers to *epic.yaml*. Distinction from
0024's rejected alternative 3 (the "typed index-validator" that would re-create a mini
adapter): that rejected shape *translated prose into a typed form*; here the birth form
**is** typed — there is no translation layer to maintain, which is exactly the adapter
0024 refused to build. Not a 0012 revival: no adapter, no second backend; consumers read
the one YAML source directly.

## Alternatives considered

- **Sidecar** (index.md stays the human surface; a parallel epic.yaml carries machine
  fields): rejected. Two homes for overlapping facts is the drift machine this decision
  kills, and it re-approaches the 0012 adapter shape. Its sole benefit — a markdown
  authoring surface — is moot here: the owner never hand-edits (Q-1); the human surface
  is the dossier, a projection either way.
- **Status quo + point fixes** (renderer prints phase numbers; enum fixed by hand):
  rejected. Leaves S1 the only station where the drift class has no mechanical detector.
- **Full migration including archived epics**: rejected (A-2) — retro-converting frozen
  dirs is zero-reader engineering.

## Consequences

- (+) Epic facts join the same validation rail as every station (schema + checker +
  render hook fires on epic.yaml writes + green/red fixtures).
- (+) Phase identity single-homed; the row-vs-phase ambiguity class closes mechanically.
- (+) One fact-home fewer: the ROADMAP twin and its drift audit dissolve into a
  freshness-checked projection.
- (−) Migration touches every index.md consumer — bounded by the retirement list above,
  each item retired or re-pointed in the same change, ordered by the reader-first gate.
- (−) The renderer carries a legacy dual-read path until archives retire — accepted.
- (±) **Downstream plugin users** (critique M-2): the shipped skill documents the YAML
  birth form with template examples; legacy index.md mode remains readable
  (grandfathered dirs), so a downstream repo can keep markdown epics until it opts in.
  Hand-editing downstream users are a flip-trigger (2) watch source, not an assumption
  violation.
