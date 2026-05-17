---
type: spec
kind: bridge
date: YYYY-MM-DD
status: draft
revision: 1
epics: []
related: []
kill-on: <epic-slug>
---

# <Feature Name> — Design Spec

**Date:** YYYY-MM-DD
**Status:** Draft

## Intention

Restated from parent epic § Intention.

- **Goal (observable):** <one paragraph; what success looks like>
- **In scope:** <bullet list>
- **Out of scope (explicit):** <bullet list>
- **Fix vs. workaround:** <one sentence>
- **Smallest change:** <one sentence>

## Source-level Deposit

> Skip this section in projects without source-as-truth adoption.

- **Lever this spec advances:** `<lever-slug>` or `none`.
- **Bridge docs this spec creates:** <list with kill-on tags>
- **Bridge docs this spec retires on landing:** <list>
- **Three-principle audit (P1/P2/P3):** <one paragraph per principle>

## Problem

<What hurts today. Concrete, scoped, falsifiable.>

## Scope

**In scope:** <bullet list>

**Non-goals:** <bullet list>

## Acceptance Criteria

```
AC-1. <name>.

Given <context>
When <action>
Then <observable>
```

<More AC blocks as needed.>

## Architecture

<System shape. Mermaid diagram for non-trivial flows.>

## Interfaces / Contracts

<Function signatures, API shapes, message formats, config schemas.>

## Error Handling

| Scenario | Trigger | Behavior |
|---|---|---|
| ... | ... | ... |

## Invariants

<Cross-cutting correctness rules.>

## Risks / Open Questions

<Unknowns; status (resolved / partial / open); mitigation.>

## Related

<Links to exploration notes, prior specs, ADRs, ecosystem precedents.>
