---
name: crucible
description: Front-end contract orchestrator — chains brainstorming → grill-with-docs → to-prd → design-spec into one invocation so the AI authors the whole contract spine (why → user-stories → requirements → ACs) and the human accepts once. Use at the start of a new feature that needs a design spec.
---

# /touchstone:crucible — Front-End Contract Orchestrator

Forges raw intent into a precise, accepted contract in ONE invocation. Chains four existing skills; the human accepts once at the end (human accept); hands the accepted contract to the build phase. Auto-invokes neither the build-phase gate nor the build.

## What it chains (in order)

1. **`superpowers:brainstorming`** — recognise the user-stories (story-rung generative step: recognition, not adversarial partition).
2. **`grill-with-docs`** — sharpen vocabulary against CONTEXT.md / ADRs. This inline run **discharges the CLAUDE.md mandatory pre-spec grill gate** — no separate standalone grill is required when authoring via crucible.
3. **`to-prd`** — synthesise the PRD (why + user-stories + out-of-scope). **touchstone addition: assign each user-story a unique US-N id** (`US-[0-9]+`).
4. **`/touchstone:design-spec`** — author the requirement → AC contract; Step 0 inherits the PRD's why + stories (precedence PRD > parent-epic Foundation > from-scratch).

## Mid-chain halt (design-spec Step-5 critique)

- If the chained `/touchstone:design-spec` Step-5 critique returns a **Critical or High** finding, **halt and surface** it to the human to clear (resolve or dismiss) before continuing.
- Do NOT silently fold it into Open Questions; do NOT auto-advance.
- After the human clears it, proceed to the terminal human-accept step. design-spec's Step-5 was the chain's last design-spec step — crucible does not re-loop the chain; any post-clear edit is re-judged downstream.

## Terminal step — human accept

- Present the resulting design-spec draft (Status: Draft) for **human accept** — the single human gate of the whole spine.
- Name the **build phase** as the next stage (today: the existing Stage-5 build workflow; `/build` once it lands).
- Do NOT auto-invoke the build-phase gate or the build. The front-end stops at the contract.

## What it does NOT do

- Reimplement any sub-skill (it orchestrates the four).
- Emit requirements itself (design-spec authors those).
- Trim the PRD (the PRD is the `to-prd` skill's output; only its why + stories are inherited; Impl/Testing Decisions from the PRD are inert — not inherited by `/touchstone:design-spec`).

## Output

- A PRD intermediate (published wherever the PRD skill writes) + an accepted `/touchstone:design-spec` carrying `## User Stories` (US-N) → `### Requirement` (traces-to: US-N) → `#### AC`. The story→requirement trace is checked by `check-spec-floor.sh`.
