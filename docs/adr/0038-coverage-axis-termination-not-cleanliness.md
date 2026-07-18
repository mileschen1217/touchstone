# 0038 — Review loops terminate on coverage, not cleanliness

- **Status:** accepted
- **Date:** 2026-07-18
- **Deciders:** Miles Chen
- **Triggered by:** quality-spine P2 build (`.touchstone/specs/2026-07-17-quality-spine-p2-loop-hardening-design.md`) — the spec's own review loop churned ~8 rounds of plausible-per-round fixes, and only a lagging net-byte baseline caught the accreted bloat.
- **Related ADRs:** 0015, 0026, 0027

## Context

A bounded AI review loop in this suite (the design-spec **challenge-pass** and
the **design-review** re-verify loop) conflates two axes that have opposite
convergence behaviour:

- **Coverage axis** — does every requirement × technique × party have an AC?
  A finite set: partitions, boundaries, decision-table columns, state
  transitions, entity×operation cells, touching parties. It **exhausts** —
  when every one is covered, the work is done. The methodology's per-technique
  "Enough" heuristics ("every partition ≥ 1 AC", "every touching party has
  ≥ 1 AC", …) are already coverage-phrased.
- **Cleanliness axis** — can this prose be made more precise / more complete /
  better-worded? Natural language **never exhausts**: there is always one more
  edge to split, one more clamp to add.

At the finding level the two are indistinguishable. "REQ-5 has no sad-path AC"
(a coverage gap) and "this SHALL could state the empty-input case more
precisely" (a cleanliness refinement) are equally plausible, both get fixed,
the fix adds text, and the next round finds a fresh refinement of the text the
previous round just added (fix-induced churn). **Every round shows real local
improvement; the aggregate is bloat — because the cleanliness axis has no
floor.** Source-code specs are partly protected here: an over-constrained code
spec fails downstream (a test that cannot be written, behaviour that will not
match), so the build/test oracle pushes back. A prose deliverable (an agent
skill) has no such downstream oracle at author time, so refinement-axis churn
runs unchecked to the byte-baseline — which is a lagging signal that fires too
late.

The suite already half-recognised this. Two lines forbid stopping on emptiness:
`severity-tiered-stopping-rule.md` says *"'Zero new findings' is a stopping
criterion nowhere in the suite,"* and the challenge-pass methodology says
*"never self-declare saturation ('no new cards emerged' is a sampling
artifact)."* Those lines are correct **for the blanket case** — findings-in-
general never reach zero, precisely because the cleanliness axis never
exhausts. But the suite's only fallback was a hard round-count (2), with no
early signal distinguishing a converging loop from a churning one.

The research synthesis (`.touchstone/research/2026-07-18-prose-oracle-and-skill-eval.md`,
primary sources: Anthropic / OpenAI / practitioner blogs) confirms the direction:
termination for a prose deliverable is **measured convergence / signal
exhaustion**, and its true oracle is **downstream** (the behavioural eval of what
gets built), not the text review itself.

## Decision

**We will bind every gating decision in a review loop to the coverage axis, and
structurally demote cleanliness-axis findings so they cannot gate.**

Three commitments follow from that one principle:

1. **Finding provenance is the convergence signal, not finding count.** A
   finding is one of: `new-scope` (points at a requirement / behaviour / party
   with zero AC — a real coverage gap), `refinement` (points at an existing
   AC/SHALL, asking for more precision), or `fix-induced` (points at text a
   previous round added). Convergence is **`new-scope` → 0**, not
   findings → 0. This refines — does not contradict — the "zero new findings is
   nowhere a stop criterion" line: blanket zero-findings is correctly rejected
   (the cleanliness axis never zeroes); provenance-filtered **zero-new-scope**
   is achievable because the coverage axis is finite.

2. **Only a coverage-gap or a real defect can be Critical/High.** A pure
   refinement — one whose fix changes no behaviour boundary — is Low by
   construction: its marker rides to the human, it never blocks, and it never
   enters the re-verify budget. This is the direct anti-gold-plating clamp; it
   is what closes the design-review re-verify churn.

3. **The classifier already exists — the subtraction test.** The Transition-A
   anti-redundancy tests (subtraction / new-constraint / SHALL-gate /
   quantifier) are all one instrument: "does this introduce a new observable
   behaviour boundary?" Today they are pointed at *requirements* (to catch
   restatement-requirements). Pointed at *findings*, the same test discriminates
   `new-scope` from `refinement`. No new instrument is invented.

**Immediate mechanization (this decision's committed scope):** the
Critical/High qualification (commitment 2) is written into
`severity-tiered-stopping-rule.md` now — the smallest edit that shuts off the
churn's main source. The full `new-scope|refinement|fix-induced` provenance
field on the challenge-result record (commitment 1) is **deferred** to the
eval-anchored skill-development redesign (the still-open strategic fork), so the
field ships once, in its final shape, rather than twice.

## Alternatives Considered

- **Keep the hard round-count as the only bound (status quo).** Rejected: a
  fixed count neither detects churn early nor distinguishes it from convergence;
  it let P2 run to the byte-baseline. It treats the symptom (round count), not
  the axis.
- **Stop when a round produces no new findings of any kind.** Rejected — this is
  exactly the criterion the suite already, correctly, forbids: refinement
  findings never reach zero, so the loop would never stop.
- **Add a net-byte budget as the primary loop gate.** Rejected as *primary*: it
  is a lagging proxy (fires after the bloat is written). It stays as a
  backstop / ratchet, not the convergence signal.
- **Leave the spec loop deep and rely on a human to call bloat.** Rejected: the
  P2 evidence is that a human calls it only at the byte-baseline, after the cost
  is sunk. The mechanism must give an early, cheap signal (regression-ratchet:
  a human-caught gap is not closed until a mechanism prevents recurrence).

## Consequences

- **Easier:** a review loop now has a principled, early stop — coverage climbed,
  refinement demoted — instead of churning on plausible-but-unbounded polish.
  The spec-side loop is deliberately shallow, pushing verification weight to the
  downstream behavioural eval where the real oracle lives.
- **Harder / new obligation:** a reviewer must now classify each finding's
  provenance (coverage-gap vs refinement) rather than emit it flat. The
  subtraction test is the tool, but the judgement is not free.
- **New risk:** mis-classifying a genuine coverage gap as "refinement" would
  suppress a real High. Mitigation: the classifier is the already-battle-tested
  subtraction test, and the human still owns the completeness call (ADR-0015 —
  critique never discharges the gate) and sees every demoted marker.
- **Bounded scope:** the Critical/High qualification (change A) is mechanized in
  the stopping rule. The finding-classification schema field was initially
  deferred here, but the addendum below (ratified 2026-07-18) un-defers it — the
  termination structure needs it to be auditable, so it becomes a record schema
  field now, not later.

## Addendum (2026-07-18) — loop-level termination and finding classification

The severity qualification above governs a single finding's grade. It does not,
by itself, make a *multi-arm* review loop terminate. Practice (P2, round 6)
showed why: dispatching N parallel lens-arms (boundary / cross-REQ consistency /
reach-both-ends / term-definition) is excellent for **discovery** — the arms'
findings were near-disjoint (16 = 6+3+2+5), and per-context attention, not
instruction breadth, is the binding resource. But that same disjoint-breadth
property, combined with small local fixes, **drives non-convergence**: each fix
adds prose, the next round re-reviews the moving surface, and every arm
legitimately finds something new in the just-added text — a chain reaction with
no floor. Breadth and convergence pull in opposite directions.

**Decision — split discovery from convergence; discovery happens once.**

1. **One-shot multi-arm discovery.** The N-arm parallel challenge runs **once**,
   against the frozen original artifact. The union of all arms' findings is the
   **backlog**, and the backlog is frozen. This is the only divergent (breadth)
   step, and it keeps the full multi-arm discovery benefit.

2. **Everything after is burn-down, not re-discovery.** Fix the backlog, then run
   **one** re-verify that checks only: (a) is each backlog item resolved, and
   (b) did any fix introduce a genuine contradiction / defect (subtraction-test
   positive, not polish). The re-verify does **not** re-run multi-arm discovery
   on the fixed text — the moving-surface chain reaction is cut at its source.

3. **A gate governs what may re-open a round.** Only a coverage-gap or real-defect
   **not already in the backlog** may re-enter, and only under recorded human
   authorization once the budget is spent. Refinement and fix-induced findings
   are marked, ride to the human, and never spawn a round.

4. **Termination** = backlog cleared **and** the re-verify surfaces no genuine
   new coverage-gap/defect. Budget is a hard bound: **multi-arm initial + one
   re-verify**. A genuine new gap at re-verify means discovery was incomplete →
   escalate to the human (the blocked three-path menu), never auto-loop. The
   early (~80%) convergence signal is the **provenance mix** of the re-verify's
   findings: mostly fix-induced/refinement → converged, stop; genuine-new
   coverage → under-discovered, authorize one more or escalate.

This is the research's capability-eval → regression-eval graduation made
concrete: round 0 climbs the hill (find the gaps); re-verify guards it (no
open-ended re-editing).

**Finding classification (the operational crux — becomes a schema field).**
Every gate above is a function of a per-finding classification, so each finding
now carries two tags on the challenge-result record, decided by the subtraction
test (delete the finding's target — does any pass/fail behaviour change?):

- **type** ∈ { `coverage-gap` (an uncovered behaviour / party / path — gates,
  enters backlog), `real-defect` (contradiction, undefined term, wrong value,
  broken reference — gates, enters backlog), `refinement` (existing covered text,
  no behaviour-boundary change — never gates, Low, rides to human) }.
- **provenance** ∈ { `original` (against the frozen artifact — a normal backlog
  item), `fix-induced` (against a prior round's fix text — may not re-open a
  round unless it is a genuine real-defect the fix introduced, which is the rare
  human-authorized exception) }.

The classification is itself an ~80% judgement, not ground truth (LLM-as-judge
is imperfect; the subtraction test makes it semi-mechanical). The safety net is
that **no finding is silently dropped** — every demoted refinement rides to the
human as a marker, so a mis-classification costs one extra human glance, never a
lost gap.
