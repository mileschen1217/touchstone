# 0028 — Proposal layer: standalone deep skill over a scripts contract; close and phase-ship consume the same scripts

- **Status:** accepted
- **Date:** 2026-07-03
- **Deciders:** miles (bet owner), keystone critique engine (CC architect + Codex adversarial, both providers ran)
- **Triggered by:** /touchstone:keystone (self-evolving-workflow-loop Phase 2)
- **Related ADRs:** 0018 (keystone as judgment-comparator), 0019 (substrate-neutral rubric), 0020 (locality-first / deep-module-over-merge)

## Context

The self-evolving loop's proposal layer reads the machine-local gate-miss ledger
(`.touchstone/ledger/entries.jsonl`), generates ranked mechanization proposals
(dual-backtest admission: benefit witness = ledger entry ids; cost witness = cheap
git-history replay, fires-vs-hits), auto-installs deterministic checker scripts into the
project checker socket (`.touchstone/checker/<stage>/`) with a two-sided liveness
self-proof, appends resolution facts, and presents a top-N digest for human accept.

Three homes were viable:

- **A — extend `/touchstone:insight`.** Supported by a prior seam note ("the same skill
  later extends to produce improvement insight"). Opposed by substrate reality: insight's
  substrate is metrics (efficiency numbers, read-only `allowed-tools: [Bash, Read]`); the
  proposal layer's substrate is the ledger, and it writes files. Extending would break a
  declared read-only contract, not just grow a body. P(forced split later) ≈ 0.7 × high
  rename/reference-sweep cost.
- **B — inline step in the epic-close procedure.** Natural-looking cadence (right after
  the close-time ledger sweep), but a cadence category error: the sweep's *population* is
  epic-scoped, while the proposal layer reads the global cross-epic ledger. Close-only
  binding also delays mechanisms by a whole epic — a proposal born in phase N is most
  valuable at phase N+1 of the same epic. P(forced extraction later) ≈ 0.6 × medium-high
  cost.
- **C — standalone skill + own scripts.** One-time cost of one more skill; scripts are
  needed regardless.

A fourth shape surfaced mid-decision — a "phase retrospective" orchestrator verb chaining
insight + sweep + proposal report — and was rejected against the arch rubric: temporal
cohesion only (two substrates bound because they share a moment), pure pass-through
(shallow module), speculative cost (the ritual it compresses had run exactly once).

## Decision

**C, in thin-skill-over-scripts form:**

1. **Scripts are the stable contract.** All mechanism lives under `scripts/proposal/`
   with explicit per-mode subcommands split by write authority: `report` (generative:
   reads open entries + bounded git window, writes proposal facts + prose sidecars,
   emits the top-N digest), `record-resolution` (append-only facts), `install`
   (write + chmod + two-sided liveness self-proof, with rollback and grounded triage),
   `reconcile` (read-only follow-through audit: accepted-but-never-installed,
   post-resolution recurrence flags, checker fire counts, retention size).
2. **One deep skill wraps the scripts** — it owns the human-facing surface only: digest
   presentation and the accept/install interaction. It hides ranking, backtest, and
   self-proof mechanics behind that small interface. It is an elevated-trust skill
   (writes executable, exit-code-gating scripts); its frontmatter and body must say so
   explicitly, and must state the ownership boundary: the init scaffold creates the
   checker directories; this skill is the sole writer of check *content*.
3. **Two lifecycle moments consume the same scripts, one line each:**
   - *Phase-ship moment:* run insight (metrics data point; unchanged, merely invoked
     alongside) and `report` — two commands, one checklist line in the phase-ship list.
     No orchestrator wrapper.
   - *Epic close:* the existing close-time sweep stays the completeness backstop; a new
     close step runs `reconcile` only. **No install ever runs mid-close** — a freshly
     installed pre-commit checker could block the close's own commit.
4. **Insight is untouched.** Ranking stays ledger-grounded; metrics are advisory
   weighting at most. No data dependency in either direction.
5. **Phase-3 boundary (upstream redaction):** the local engine emits local facts only; a
   future redaction/export module consumes a sanitized intermediate and fails closed. It
   attaches as an additional script under the same contract, never as reach from the
   local paths into upstream surfaces.

## Alternatives considered

A and B as above; scripts-only-without-a-skill (Codex's fragmentation concern) — rejected
because the digest + accept/install interaction is precisely the human-facing trigger
that warrants a skill under existing plugin granularity norms, while the scripts contract
already answers the mechanism-stability concern.

## Consequences

- Skip-tolerance is by construction (pull-based, cursor/fact-based): late runs stay
  correct with three honest degradations — transcript-source retention windows bound
  how late a sweep can be, skipped metrics data points are never backfillable, and
  delayed installs let recurrences accumulate (which fattens their benefit witnesses).
- Replay (fires-vs-hits over git history) is not runtime developer flow; the residual is
  stated in the spec, mitigated by the conservative auto-install bar (fires == hits) and
  a cheap revoke path — no observe-only trial machinery in v1.
- The ledger writer stays single-schema; proposal/resolution facts get a sibling writer
  mirroring its lock/self-heal design.

## Amendment — naming reassigned; metrics reporting dissolves into the phase-ship gate (2026-07-03, same session)

The structural core above is unchanged (scripts contract, one deep skill, write-authority
split, no mid-close install). Two identity clauses are revised after a deterministic-vs-
semantic layering pass with the bet owner:

- **"Insight is untouched" is superseded.** The `insight` name transfers to the loop skill
  — honoring the original seam note that named this destination — because the current
  metrics reporter under that name over-promises (it reports numbers, not insights).
- **The metrics reporter does not survive as a skill.** It was a shallow pass-through
  wrapper (the same defect class as the rejected retrospective verb). Its content
  dissolves into a **deterministic phase-ship step**: run the (unchanged)
  `scripts/metrics-report.sh` — whose execution also closes the open run window, a
  cleaner stamp point than an arbitrary report moment — and append the phase's
  cost/time/token row to the epic's data-point record mechanically instead of by hand.
  When the OTel collector is absent the row records `[unverified]` cells honestly; no
  conditional branch.
- The phase-ship moment therefore carries two layers: the deterministic metrics record
  (script, no judgment) and the semantic `insight report` invocation (digest for human
  accept). They remain two checklist lines, not an orchestrator.

## Amendment 2 — subcommand contract refined at design-spec (2026-07-03)

The Decision's clause 1 named `report` as generative (writing proposal facts) and
`record-resolution` as a separate append mode. The design spec superseded that split with a
stricter one the review upheld: ALL facts (proposal and resolution) enter through a single
validated writer (`facts-append.sh`, the referential-integrity choke point), and `report.sh`
— like `reconcile.sh` and `replay-run.sh` — is strictly read-only. The write-authority
principle of clause 1 is unchanged; only the command-to-authority assignment moved. The
governing interface definition is the spec's Interfaces section (and, once built, the
scripts themselves).

## Flip-triggers

- **Wrapper verb:** if the two-command phase-ship ritual proves annoying across ≥3
  consecutive phases (real-demand evidence), wrap it then. Review owner: miles, at each
  epic close.
- **Home split:** if Phase-3 redaction cannot keep the fail-closed boundary inside the
  same scripts contract, it gets its own home; revisit this ADR at that spec's keystone.
