---
name: crucible
description: Front-end contract orchestrator — chains explore → assay → design-spec → design-review into one invocation; the human accepts once at the end. Use at the start of a feature that needs a contract.
user-invocable: true
---

# /touchstone:crucible — Front-End Contract Orchestrator

Forges raw intent into an accepted contract in ONE invocation; the human
accepts once at the end — the **contract accept**, the first of the two human
accepts a unit of work passes (the second is the ship informed-accept at
phase-ship). Requires a live responsive user (assay interviews; the terminal
step is a human accept). Skip when no full chain is needed — a spec revision
goes straight to `/touchstone:design-spec` + `/touchstone:design-review`.

## Exploration's role (decide first)

- **Solution-grounding (default)** — the intent is stateable now; exploration
  grounds it in the system and runs as the chain's explore phase.
- **Problem-finding** — the intent cannot be stated until you look (audit,
  heavy refactor): run discovery FIRST, let findings surface the intent, then
  enter the chain with a light confirmatory explore. Never interview toward an
  intent that could not yet form.

## Contract form — full or short (decide before assay; name it to the human)

Default = **short**. Escalate to **full** iff any of the three triggers holds:

1. the intent adds or changes a party-facing contract (API / CLI / schema /
   skill interface);
2. a structural fork (≥2 viable paths) is open;
3. the intent is problem-finding (audit, heavy refactor).

Otherwise short. Breadth alone never escalates: a fixed-invariant sweep is
short however many files it touches. Anchor examples — the branch a reader is
in is decidable from the triggers alone:

| intent | trigger | form |
|---|---|---|
| add a field to a schema another skill reads | 1 — party-facing schema change | full |
| tighten one skill's prose; no interface, no fork, intent stated | none | short |

Both forms produce the same `spec.yaml` (one schema) and pass the same
design-review gate; the form sets how much of assay and of the gate runs:

| | full | short |
|---|---|---|
| assay | the whole instrument | its short form (assay § Short form) |
| design-review | full mode (three lenses, the injected rule's budget) | short-chain mode (one round, two lenses) |

## The chain

1. **explore** — read the code paths, patterns, and constraints the contract
   must respect, scoped by the intent. Findings feed the interview and the
   contract; they never author it. When the intent changes a cross-boundary
   artifact (>1 party must agree on it), apply
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/reach-discovery.md` as the method to
   sweep the artifact's reach and write the saturated seam-map here at explore
   into the epic dir as `explore-<date>-<subject>.yaml`, for the interview to
   confirm into Consensus Scope.
2. **`touchstone:assay`** — the unconditional interview, in the form chosen
   above. **Progression gate: do not advance until the assay record's
   readiness ruling — the explicit human yes — exists.** A structural fork it
   surfaces produces an ADR (and is itself trigger 2); the ledger row that
   produced it is what design-spec cites.
3. **`/touchstone:design-spec`** with the assay record path as its facts
   source; US-N ids and story→requirement traces are design-spec's to author.
4. Set `status: accepted-candidate`, invoke `/touchstone:design-review <spec>`
   — the gate runs pre-accept, here, in the mode the form selects. The gate
   governs its own convergence; crucible only surfaces its terminal outcome —
   a clean close advances, a blocked line halts at `accepted-candidate` for
   the human. Never fold findings into Open Questions, never auto-advance.

## Standing-decision conflict

Alignment touching a ratified ADR or standing decision surfaces the conflict —
never silently overwrite. A true structural fork (≥2 viable paths remain)
routes to assay's fork case; a decisively-resolved conflict proceeds with one
inline line naming the standing decision and why it still holds.

## Terminal — the contract accept

Present the clean-gated spec for the single terminal accept; the accept
promotes `accepted-candidate → accepted` for both forms. Name
`/touchstone:anvil` as next. Crucible stops at the contract — it never invokes
the build, never emits requirements, never assigns US-N ids.
