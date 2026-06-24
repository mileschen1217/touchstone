---
name: crucible
description: Front-end contract orchestrator — chains brainstorming (conditional) → grill-with-docs (unconditional) → keystone (conditional structural-fork) → design-spec into one invocation so the AI forges the contract spine (why → requirements → ACs) and the human accepts once. Use at the start of a feature that needs a design spec.
---

# /touchstone:crucible — Front-End Contract Orchestrator

Forges raw intent into a precise, accepted contract in ONE invocation. Chains existing skills; the human accepts once at the end (human accept); hands the accepted contract to the build phase. Auto-invokes neither the build-phase gate nor the build.

**Applicability boundary:** crucible is the front-end for work whose contract is authorable after light exploration; explore-dominant work does not run through crucible's single chain.

## Step 1 — Explore-dominant precondition gate (run before the chain)

Is this work explore-dominant?

- **Light-exploration** (design-spec's own source-reading suffices — e.g. a new feature or targeted change where the existing system is already understood) → proceed with the chain.
- **Explore-dominant** (an audit / refactor / heavy reckoning with the existing system — where the shape of the work itself depends on discovering what is actually there) → **STOP**: run the exploration as its own phase first, then feed its findings into the contract. Crucible's chain has no slot for an open-ended audit. Do not silently grill→design-spec on unexplored ground.

This check is orthogonal to story recognition. A story can be fully recognized (≥1 US-N aligned) while the system remains unexplored — recognized intent does not imply system explored.

## What it chains (in order)

1. **`superpowers:brainstorming`** — conditional. Skip-signal: story already recognized ⟺ ≥1 US-N already supplied or aligned in context (parent epic or prior alignment) → skip brainstorm (intent recognition cleared); otherwise run it to surface user-stories before grilling. Note: this skip-signal clears intent recognition only — it does not clear the Step 1 system-explored check, which is a separate precondition.

2. **`grill-with-docs`** — unconditional. Sharpens vocabulary against CONTEXT.md / ADRs. This inline run **discharges the CLAUDE.md mandatory pre-spec grill gate** — no separate standalone grill is required when authoring via crucible.

3. **`touchstone:keystone`** — conditional structural-fork step. Trigger: a not-yet-ratified architectural fork with ≥2 viable options whose choice constrains future deliveries. Keystone is a judgment-comparator — fork-driven, NOT a fixed question-bank (ADR-0018). It produces an ADR that design-spec inherits via its Related field. Skip-path: if direction is clear and no fork is open, proceed directly to design-spec (record "no fork" inline — do not silently proceed).

4. **`/touchstone:design-spec`** — chain tail. Authors the requirement → AC contract. Step 0 elicits intention / aim / out-of-scope from context; US-N assignment and story→requirement trace are design-spec's responsibility, not crucible's.

## Standing-decision conflict (non-greenfield)

On a non-greenfield change whose alignment touches a ratified ADR or standing decision, **surface the conflict for human resolution** — do not assume greenfield. Two dispositions:

- **True structural fork** (≥2 viable paths remain after the conflict): route to keystone (step 3) before design-spec.
- **Decisively-resolved conflict** (the ratified decision still stands; no viable alternative remains): proceed noting the conflict inline (F-1 disposition). Do NOT silently proceed past a standing decision without naming it.

## Mid-chain halt (design-spec Step-5 critique)

- If the chained `/touchstone:design-spec` Step-5 critique returns a **Critical or High** finding, **halt and surface** it to the human to clear (resolve or dismiss) before continuing.
- Do NOT silently fold it into Open Questions; do NOT auto-advance.
- After the human clears it, proceed to the terminal human-accept step. design-spec's Step-5 was the chain's last design-spec step — crucible does not re-loop the chain; any post-clear edit is re-judged downstream.

## Terminal step — human accept

- Present the resulting design-spec draft (Status: Draft) for **human accept** — the single human gate of the whole spine.
- Name the **build phase** as the next stage (today: the existing Stage-5 build workflow; `/build` once it lands).
- Do NOT auto-invoke the build-phase gate or the build. The front-end stops at the contract.

## What it does NOT do

- Reimplement any sub-skill (it orchestrates them).
- Emit requirements itself (design-spec authors those).
- Assign US-N ids (design-spec's responsibility).

## Output

An accepted `/touchstone:design-spec` carrying `## User Stories` (US-N) → `### Requirement` (traces-to: US-N) → `#### AC`. The story→requirement trace is checked by `check-spec-floor.sh`. If keystone ran, the spec's Related field references the produced ADR.
