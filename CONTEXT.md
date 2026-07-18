# touchstone CONTEXT

Shared vocabulary for the touchstone skill family. Reference, not prerequisite:
every skill works without this file (PRINCIPLES.md P4). One line per term; a
pointer names the single home of any longer rule.

## Spine

- **`claim ≤ evidence`** — the plugin's constitution; see `docs/PRINCIPLES.md` P1.
- **silent false-green** — a claim exceeding its evidence that no mechanism catches;
  the defect every gate exists to prevent.

## Contract vocabulary

- **user-story (US-N)** — the user-faced need ("As an actor, I want X, so that Y");
  deliberately under-specified for verification.
- **requirement (REQ-N)** — one SHALL sentence carrying a partitionable rule domain;
  `traces-to: US-N` links it to its story. A requirement that merely rewords its
  story collapses into it.
- **AC (AC-N)** — an agent-checkable Given/When/Then under a requirement; the unit
  all evidence accounting keys on. Each requirement has ≥1 AC (happy + sad).
- **`[NEEDS CLARIFICATION: q]`** — authoring-gap marker (not enough info to write
  the requirement/AC); count > 0 blocks "ready for build".
- **`[unverified: reason]`** — verification-gap marker on an AC whose Then no
  evidence confirms; never co-occurs with the authoring marker on one AC.
- **structural completeness** — the mechanical floor: every US has ≥1 requirement,
  every requirement ≥1 AC, zero unresolved clarification markers. Semantic
  completeness (is it the RIGHT set) has no mechanical oracle and stays human.

## Review vocabulary

- **batch review** — cross-vendor review of a logical commit group; the mandatory
  deliverable review layer, backed by the pre-push C/H blocker.
- **final review** — anvil's closing cross-provider review of the whole deliverable
  against the accepted spec, including per-AC honesty (`[unverified]` forcing).
- **review envelope** — dispatch-provenance record of who actually reviewed;
  single home: `skills/cross-provider-reviewer/references/provenance.md`.
- **live-bearing AC / live artifact** — an AC undischargeable offline, and the
  captured real-boundary output (with producer + freshness provenance) that
  discharges it; single home: `skills/_shared/inject/live-bearing-predicate.md`.
- **Evidence Reckoning** — at epic close every AC is reckoned covered or carries an
  enumerated `[unverified: reason]`; live-bearing ACs may not use `[unverified]`.

## Eval vocabulary

- **gate stamp** — one line a gate skill appends after each run (findings ×
  severity, fixes, rough cost) to `.touchstone/eval/stamps.jsonl`; the
  which-gate-pays-rent axis.
- **use-point failure event** — one line recorded when an artifact fails in use
  (`date | artifact | event | expected locus | actual locus | severity`); instances:
  `gate-miss.md` (human catches what a gate missed), build deviation logs,
  post-build quiz misses. The did-the-chain-produce-quality axis.
- **reckon** — the epic-close page where a human reads both axes and rules
  keep / adjust / kill per gate; includes the recall question "what did you catch
  that the gates missed?". Capture is soft (~80% + recall backstop), consumers are
  threshold/trend-based.

## Build vocabulary

- **crucible** — front-end orchestrator: explore → assay → design-spec →
  design-review, terminating at one human accept of the contract.
- **anvil** — back-end orchestrator: entry check → conductor orchestration-mode →
  final review → human final-accept. Task decomposition, grading, dispatch, and
  per-task acceptance belong to conductor; task-contract/result schemas have their
  single home in the conductor plugin.
- **AC-coverage floor** — before dispatch, every AC-N maps to ≥1 conductor task
  contract (or an explicit deferred row); blocks industrialising a dropped AC.
- **light loop** — the no-orchestrator path (direct work + dispatch) used when
  conductor is absent or the contract is a PRD+seams light contract.

## Fragment index

Injected doctrine for cold reviewers lives in `skills/_shared/` (one home each);
each fragment's frontmatter declares its consumers. This index is the map, the
fragments are the law.
