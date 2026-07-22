---
name: crucible
description: Front-end contract orchestrator — chains explore (ground the intent in the system) → assay (the pre-contract interview; its consensus section is what the contract author consumes) → design-spec into one invocation, so the AI forges the contract spine and the human accepts once. Use at the start of a feature that needs a design spec.
---

# /touchstone:crucible — Front-End Contract Orchestrator

Forges raw intent into an accepted contract in ONE invocation; the human
accepts once at the end. Requires a live responsive user (assay interviews;
the terminal step is a human accept). Skip when no full chain is needed — a
spec revision goes straight to `/touchstone:design-spec` +
`/touchstone:design-review`.

## Exploration's role (decide first)

- **Solution-grounding (default)** — the intent is stateable now; exploration
  grounds it in the system and runs as the chain's explore phase.
- **Problem-finding** — the intent cannot be stated until you look (audit,
  heavy refactor): run discovery FIRST, let findings surface the intent, then
  enter the chain with a light confirmatory explore. Never interview toward an
  intent that could not yet form.

## The chain

1. **explore** — read the code paths, patterns, and constraints the contract
   must respect, scoped by the intent. Findings feed the interview and the
   contract; they never author it. When the intent changes a cross-boundary
   artifact (>1 party must agree on it), apply
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/reach-discovery.md` as the method to
   sweep the artifact's reach and produce a saturated seam-map here at explore,
   for the interview to confirm into Consensus Scope.
2. **`touchstone:assay`** — the unconditional interview (proportionality lives
   inside it, never as a chain skip-condition). **Progression gate: do not
   advance until the assay record's readiness ruling — the explicit human
   yes — exists.** A structural fork it surfaces produces an ADR that
   design-spec inherits via its Related field.
3. **Contract form — an explicit two-way choice** (name it to the human;
   default = full spec):
   - **Full `/touchstone:design-spec`** — a new contract (API / CLI / IPC /
     schema / skill / agent), or design decisions expensive to reverse across
     modules. Breadth alone never forces this: a fixed-invariant mechanical
     sweep belongs to the light form however many files it touches. Invoke
     design-spec with the assay record path as its facts source; US-N ids and
     story→requirement traces are design-spec's to author.
   - **PRD+seams light contract** — batch-shaped work (sweeps, migrations):
     problem + batches + acceptance seams (≥1 per load-bearing ruling) +
     unbreakable invariants, the problem/invariant fields citing the facts
     source's rows. It skips step 4; before its terminal accept run the light
     check in `references/light-check.md`.
4. **(Full form only.)** Set `status: accepted-candidate`, invoke
   `/touchstone:design-review <spec>` — the gate runs pre-accept, here. The
   gate governs its own convergence; crucible only surfaces its terminal
   outcome — a clean close advances, a blocked line halts at
   `accepted-candidate` for the human. Never fold findings into Open
   Questions, never auto-advance.

## Standing-decision conflict

Alignment touching a ratified ADR or standing decision surfaces the conflict —
never silently overwrite. A true structural fork (≥2 viable paths remain)
routes to assay's fork case; a decisively-resolved conflict proceeds with one
inline line naming the standing decision and why it still holds.

## Terminal — human accept

Present the contract (clean-gated spec, or light-checked PRD+seams) for the
single terminal accept; accept promotes `accepted-candidate → accepted`. Name
the build phase (`/touchstone:anvil` for a full spec; the light loop for
PRD+seams) as next. Crucible stops at the contract — it never invokes the
build, never emits requirements, never assigns US-N ids.
