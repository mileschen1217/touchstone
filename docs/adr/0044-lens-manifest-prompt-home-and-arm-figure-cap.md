---
kind: workflow
adr_id: 0044
status: accepted
date: 2026-09-02
amends: 0042 (per-lens prompt home), 0032 (how the review-prompt surface cap is enforced)
---

# ADR-0044: The lens manifest is the per-lens prompt home, and the ratcheted arm figure enforces the review-prompt surface cap

- **Status:** accepted
- **Date:** 2026-09-02
- **Deciders:** miles (owner)
- **Triggered by:** `/touchstone:assay` (assay-2026-09-01-load-instrument, rows A-4, A-15, A-17, Q-6) → `/touchstone:design-spec (2026-09-02-phase7-host-context-diet.spec.yaml)`
- **Related ADRs:** 0042 (lens × arm review — the gate-body lens declaration), 0032 (plugin boundary — the review-prompt surface's token cap), 0017 (injectable doctrine fragments home)

## Context

Two accepted decisions stop meaning what they say once a review arm's lens and
subject stop travelling as prompt content.

**ADR-0042** put three things in one place: "A gate declares its lens set
(`lenses: [{name, arms, prompt_home}]`) in its body". The routing half — which
lenses, to which arms — is genuinely the gate's. The `prompt_home` half is not:
it is the composition of the lens itself, and it must be readable by a script
outside any gate session, because that is the only way the lens text can reach
an arm without first passing through the dispatching session's context. Leaving
`prompt_home` in the gate body would leave two homes for one fact the moment a
manifest exists.

**ADR-0032** capped "the review-prompt surface's total token count … at the
2026-07-04 baseline — net growth only by matching deletion". That cap was
written when every lens fragment was loaded by the gate session, so the
stage-load ratchet measured it. Once arm-destined sections move into dispatched
contexts, they leave the in-session figure entirely — and the clause becomes
silently unenforceable: a lens could double in size and no gate would notice.

## Decision

We will make two amendments.

1. **`skills/_shared/lens-manifest.yaml` is the single home of each lens's
   section composition and destination.** A gate body keeps ADR-0042's routing
   half (`lenses: [{name, arms}]`) and drops `prompt_home`. The manifest
   declares, per lens, each section as a repo-relative path with an optional
   heading, its fragment id, and whether it lands on the arm side or the host
   side of the dispatch. It is read by `scripts/assemble-arm-task.sh` in a
   subprocess and by `scripts/plugin-map.sh` at measurement time, never by a
   gate session, so its own bytes are charged to no context.

2. **The ratcheted arm figure `arm_load_tokens` is how ADR-0032's
   review-prompt surface cap is enforced.** It is the sum, over a stage's
   dispatched contexts, of their bytes ÷ 4, maxed across stages, ratcheted
   against a committed baseline. The sum — not the maximum — is deliberate:
   a maximum would make splitting one lens across more arms free. The per-arm
   maximum is emitted alongside as a secondary figure and is not ratcheted.
   ADR-0032's clause keeps its force ("net growth only by matching deletion");
   what changes is the instrument that measures it, because the surface it
   named no longer sits where the old instrument was looking.

## Alternatives Considered

- **Leave `prompt_home` in the gate body and have the assembler parse the gate
  body for it.** Rejected: the gate body is prose read by a session; making a
  script parse it for a machine-consumed declaration is the fragile half of
  both jobs, and it keeps the composition inside a file a session loads.
- **Give each lens its own manifest file beside its prompt.** Rejected: the
  checks that make the manifest worth having — no duplicate lens name, no lens
  named at a dispatch site without an entry, no fragment whose declared
  destination contradicts where the map finds it — are cross-lens questions,
  and they need one file to ask them of.
- **Retire ADR-0032's cap instead of re-instrumenting it.** Rejected: the force
  behind it (review-prompt surfaces grow by accretion, and review cost rises
  with them) is unchanged by where the bytes are now charged. Moving the bytes
  out of the host is exactly the move that would let the cap rot unnoticed.
- **Ratchet the per-arm maximum rather than the sum.** Rejected: it prices
  fan-out at zero. Adding a fourth arm carrying the same lens would leave the
  gated figure untouched while trebling what is actually spent.

## Consequences

- A lens's text and its routing now live apart. Adding a lens means a gate-body
  row *and* a manifest entry; `check-lens-manifest.sh` fails a gate that names
  a lens with no entry, so the two cannot drift silently.
- The stage-load ratchet's existing key keeps its meaning and its committed
  baseline: it is now explicitly defined over in-session contexts only, so
  bytes moved into an arm cannot fold back into it and cannot be mistaken for
  a reduction.
- Two new ratchets exist to maintain (`arm_load_tokens`,
  `conditional_load_tokens`). Both are seeded from a post-change measurement,
  never from a mid-flight one.
- A future lens addition names its deletion against the arm figure rather than
  against the stage figure. Someone reading ADR-0032 alone will reach for the
  wrong instrument; this ADR is the pointer, and ADR-0032 carries no copy of it.
