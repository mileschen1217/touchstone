# arch-evaluation rubric — substrate-neutral, three layers

This instrument is substrate-neutral: domain-agnostic — NOT filtered to one substrate
(e.g. markdown skills). It calibrates the human bet + the critique engine; it is
a **judgment calibration**, NOT a mandatory gate-checklist (the structural-fork case is a
judgment-comparator). Score against it to inform the bet, never to block.

## L1 — invariant (neutral)

**Minimize expected complexity** (= change-cost + cognitive load; Ousterhout). Mentions no
code / class / substrate. The root target — too abstract to score against directly, so it is
served through the L2 forces.

## L2 — forces (neutral; the rubric's axes, stated as forces, NOT named principles)

- **(a) interface economy / information-hiding** — minimize what a consumer must know to use or
  change a unit.
- **(b) cohesion** — a unit serves one reason-to-change.
- **(c) coupling** — minimize, and keep acyclic, what must change together.
- **(d) speculative cost / YAGNI** — don't pay complexity for improbable futures.

## L3 — named canon, substrate-PLUGGABLE adapter (NOT neutral; selected by the artifact's substrate)

| Substrate | Canon to invoke |
|---|---|
| OOP | SOLID (ISP, DIP, LSP, OCP) |
| Component / package | CCP, ADP, CRP, SDP |
| Distributed system | CAP, failure-domain, idempotency |
| DB schema | normalization |
| Doc / prompt-skill | deep-skill, locality (CCP), cohesion |

The executing agent names the L2 forces + invokes the L3 canon appropriate to the artifact's
substrate. If it cannot assess the substrate, it notes the gap (honest
engine-limit). SOLID etc. are NOT "rejected / stale" — they are the OOP adapter, simply not
active when the substrate is, say, markdown skills.

## Derivation discipline

Every L3 entry must either be **external canon** (cited) or **trace to an L2 force**. Coined
terms are L3 *applications*, never new L2 axes. Worked example: `deep-module` is L3 (Ousterhout's
named principle), derived from the L2 force *interface economy*; touchstone's own
`locality-first` = CCP + that same force applied to doc-placement; `deep-module-over-merge` =
the same force on the merge question. Few forces, many decisions tracing back — the rubric
working as intended.
