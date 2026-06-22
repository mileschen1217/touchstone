---
name: keystone
description: |
  Pillar-2 structural-commitment construct. Before a design spec: decide + record
  a structural fork (2+ viable approaches, durability stakes) over code, docs, or
  suite structure. Produces a human-owned ADR with a flip-trigger. Advisory only.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - Skill
kind: workflow
---

# touchstone:keystone

Pillar-2 structural-commitment: decide + record a structural fork before a spec.

**Invariant target:** `CONTEXT.md § Design+review control axis` — arch invariant.
Gloss: minimize expected complexity (P×cost-weighted); YAGNI-on-cost bounds it.
The invariant is the comparator — not a checklist. Judgment-comparator: advisory only.

## When to invoke

A structural fork with durability stakes: 2+ viable approaches where the choice
constrains future deliveries across code, docs, or suite structure.

**NOT a trigger:** multi-actor / pre-spec system-model alignment (the former
`arch-discovery` trigger) — see ADR-0018 for the revisit path if that need resurfaces.

Skip when: direction is clear → go to `/touchstone:design-spec`; tactical
implementation choice → resolve inline.

## Procedure

Every run produces a **normative decision record** containing: the fork, alternatives
considered, assumptions, expected durability downside, rationale, human bet-owner,
and a durable ADR with a flip-trigger.

Two elements are adaptable — skip each only with the reason recorded in the ADR:

- **Numeric P×cost estimate** (adaptable) — probability × complexity-cost for each
  approach; calibrates against the arch invariant. Omit only when stakes are
  obviously asymmetric and the record says so.
- **Critique-engine dispatch** (adaptable) — see Engine below. Omit only when no
  suitable engine exists for the artifact type; note the no-engine-evidence gap in the ADR.

This is an invariant-aimed procedure, not a gate-checklist.

### Engine dispatch

Default: `touchstone:cross-provider-architect` (CC `architect` + Codex adversarial
reviewer, Pattern A parallel).

**Limit stated:** this engine is software-arch-tuned and may under-serve non-code
artifacts (docs, skill suite structure). Provider choice (`with cc` / `with codex`)
selects the backend only — critique doctrine is identical across providers.

**For non-code artifacts:** human bet + invariant carry the judgment. Fallback:
route to an artifact-appropriate reviewer, or proceed noting the no-engine-evidence
gap in the ADR.

If the composite returns a ⚠️ DEGRADED or ⚠️ PARTIAL banner, present it verbatim
and get explicit acknowledgement before advancing.

### ADR record

See `adr-authoring.md` (same directory). The ADR must name an observable flip-signal
and a review owner per recorded bet. Write to `docs/adr/` only when a decision is made.

## Hand off

Decision recorded → `/touchstone:design-spec` (reference the ADR in Related).

**Related:** `adr-authoring.md` · `CONTEXT.md § Design+review control axis`
