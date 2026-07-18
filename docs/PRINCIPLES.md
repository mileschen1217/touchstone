# touchstone PRINCIPLES

The distilled constitution of the touchstone plugin. Ten principles (P) and four
standing rules (R). Everything else in this repo is an implementation of these and
may be rewritten freely; changing THIS file is a human decision. Decision history
lives in git and in the v1 ADR archive — this file states rules, not their story.

## Principles

**P1 — Claim ≤ evidence.** A claim never exceeds its evidence; gaps are marked
(`[unverified: reason]`, `[假設]`, `[NEEDS CLARIFICATION]`), never hidden. The one
defect every gate exists to prevent is the silent false-green: a claim that exceeds
its evidence and is caught by no mechanism.

**P2 — Builder ≠ reviewer.** Whoever produced a deliverable never judges it: reviews
go to fresh-context agents, high-stakes reviews to a different vendor, and a live
artifact is never authenticated by its own producer.

**P3 — Quality is measured at the point of use, not claimed at the point of
production.** Every artifact's quality signal is its downstream failure record —
code fails in tests and rework, specs fail as build-time deviations, skill prose
fails as in-session corrections and misreads. One line-format records them all:
`date | artifact | event | expected locus | actual locus | severity`.

**P4 — Every skill stands alone.** A skill must be fully usable by a cold agent
reading only its own SKILL.md: plain words, no repo-internal jargon, no required
detour through CONTEXT.md. The family shows up in shared artifacts and a few
injected fragments, never in prose cross-references. Test: delete CONTEXT.md and
every skill still works.

**P5 — One home per rule.** A rule lives at its most local authoritative owner; it
moves to `skills/_shared/` only when no single skill can own it (divergence would
be a bug). A pointer never coexists with a restatement.

**P6 — State the rule, not its history.** No ADR numbers, supersession notes, or
origin stories on execution surfaces. If a rule is worth following, its text
carries its own justification.

**P7 — Passing one lens never discharges another.** Design-soundness, verification
honesty, and contract compliance are separately tracked verdicts; no gate substitutes
for a sibling gate.

**P8 — Declare before, verify after.** A stage states up front what it will claim
and what evidence that claim needs (feedforward), and a later reader checks the
delivered evidence against the claim (feedback). A stage may run one-armed as long
as no claim it emits goes forever unchecked.

**P9 — Live-bearing behaviour needs live evidence.** An acceptance criterion whose
behaviour cannot be exercised offline is discharged only by a captured live artifact
with provenance (producer + freshness). When in doubt, treat it as live-bearing.

**P10 — Humans govern the irreversible.** Ship (push / merge / release) is a human
act, gated by comprehension: a buy-in explainer plus an understanding quiz —
approval never exceeds understanding.

## Standing rules

**R1 — Prose budget.** Shipped prose (skills + agents + CONTEXT.md + templates)
≤ 3,000 lines total, ≤ 200 lines per file. A hard ceiling, not a target: growth
lands only with matching deletion.

**R2 — Mechanism admission.** No new checker, schema, or pipeline until the pain it
addresses has ≥ 3 recorded occurrences (gate-miss ledger) AND the rule has run as
plain prose for at least one full epic. Rules first; machinery only after the rule
survives use.

**R3 — Dogfood cap.** When touchstone develops itself, its process artifacts stay
≤ 1× the shipped diff, and it uses the light contract path. The proving ground for
the full machinery is host projects, never touchstone itself.

**R4 — Vocabulary budget.** CONTEXT.md ≤ 80 lines. A term enters only when ≥ 2
skills need it and no plain phrase serves. Definitions carry their own negative
space inline — no appended avoid-lists, no inline history notes.
