---
name: crucible
description: Front-end contract orchestrator — chains explore (ground the intent in the system) → assay (unconditional pre-contract interview — interviews the human against the explored system, hands back a guardrail contract block) → design-spec into one invocation so the AI forges the contract spine (why → requirements → ACs) and the human accepts once. Use at the start of a feature that needs a design spec.
---

# /touchstone:crucible — Front-End Contract Orchestrator

Forges raw intent into a precise, accepted contract in ONE invocation; the human accepts once at the end.

**Applicability boundary:** crucible forges a contract by grounding the stated intent in the system and then interviewing the map-territory gap before the contract is authored. **Exploration is a phase of the chain, not a precondition.** The one exception is work where you cannot state the intent until you have looked — the router below front-loads exploration for that case.

## Before the chain — which role does exploration play?

The answer sets where exploration sits.

- **Solution-grounding (default)** — you can state the intent now; exploration grounds that intent in the system (feasibility, what-to-touch). → proceed into the chain; exploration is the chain's **explore** phase.
- **Problem-finding** — you cannot state the intent without first looking (an audit / heavy refactor where the work's shape depends on what is actually there). → run a discovery exploration **first**, let its findings surface the intent, then enter the chain (the in-chain explore phase is then light / confirmatory). Do not interview→design-spec on intent you could not yet form.

This routing is orthogonal to story recognition: a story can be recognized (≥1 US-N aligned) while the system is unexplored — recognized intent does not settle which exploration role applies.

## What it chains (in order)

1. **explore** — ground the intent in the system: read the code paths, existing patterns, and constraints the contract must respect, scoped by that intent. Light when the system is already understood; heavier for an unfamiliar surface. For problem-finding work (per the router above) the heavy discovery already ran before the chain, so this phase is confirmatory. Findings feed the interview and the requirement → AC contract; they do not author it. The interview cannot lay out assumptions about a map that has not been drawn — explore always precedes it.

2. **`touchstone:assay`** — the unconditional pre-contract interview (proportionality lives INSIDE assay — a small subject compresses its rounds; it is never a chain skip-condition). It interviews the human against the system that explore just grounded, and hands back the guardrail contract block design-spec consumes. If it surfaces a structural fork, it produces an ADR that design-spec inherits via its Related field. Crucible invokes assay at this boundary and does not know its stage internals. **Progression gate: do NOT advance to design-spec until assay's readiness ruling line (the explicit human yes) exists in the assay record.**

3. **`/touchstone:design-spec`** — chain tail. Authors the requirement → AC contract, consuming assay's guardrail block (head → Scope / Invariants / Foundation facts; tail scenario skeletons → the AC layer). Its Load-vocabulary / Foundation-elicitation phase elicits intention / aim / out-of-scope from context; US-N assignment and story→requirement trace are design-spec's responsibility, not crucible's.

4. **Set `status: accepted-candidate`** on the spec frontmatter, then invoke `/touchstone:design-review <spec>` — the consolidated design-review gate (the union of design-soundness ∪ verification-honesty lenses). This is the 3→2 front-load: the gate runs pre-accept here, not separately after.

## Standing-decision conflict

When a change's alignment touches a ratified ADR or standing decision, **surface the conflict for human resolution** — do not assume a clear slate where a prior decision can be silently overwritten. Two dispositions:

- **True structural fork** (≥2 viable paths remain after the conflict): route it to assay (the structural-fork case of its interview — it produces an ADR) before design-spec.
- **Decisively-resolved conflict** (the ratified decision still stands; no viable alternative remains): the **note-and-proceed disposition** — proceed, and record one inline line naming the standing decision and why it still holds. Do NOT silently proceed past a standing decision without naming it.

## Mid-chain halt (design-review Critical/High)

- If the consolidated `/touchstone:design-review` returns **Critical or High** findings, **halt and surface** them to the human to clear (resolve inline and re-invoke `/touchstone:design-review`). The spec stays `accepted-candidate` until a clean pass. No auto-loop.
- Do NOT silently fold findings into Open Questions; do NOT auto-advance.

## Terminal step — human accept

- After a clean design-review (Critical+High = 0), present the `accepted-candidate` spec for **terminal human-accept** — the single human gate of the whole spine. Human accept promotes `accepted-candidate → accepted`.
- Name the **build phase** as the next stage (today: the existing Stage-5 build workflow; `/build` once it lands).
- Do NOT auto-invoke the build-phase gate or the build. The front-end stops at the contract.

## What it does NOT do

- Reimplement any sub-skill (it orchestrates them).
- Emit requirements itself (design-spec authors those).
- Assign US-N ids (design-spec's responsibility).

## Output

An accepted `/touchstone:design-spec` carrying `## User Stories` (US-N) → `### Requirement` (traces-to: US-N) → `#### AC`. The story→requirement trace is checked by `check-spec-floor.sh`. If assay surfaced a structural fork and produced an ADR, the spec's Related field references it.
