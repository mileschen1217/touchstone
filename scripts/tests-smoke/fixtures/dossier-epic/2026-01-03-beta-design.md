---
type: spec
status: accepted
epics: [fixture]
---

# Beta — Design Spec

## Foundation

- **Aim:** beta.

## Phase map

- **Position.** phase 2 of 2; previous explainer `2026-01-02-alpha-buyin.html`.
- **Structure before → after.** two files → three.
- **Interface delta.**

  | kind | surface | detail |
  |---|---|---|
  | shifted | `alpha.sh` | takes a flag |

- **Flow + scope.** touched: `a/`, `c/`; untouched: `b/`.

## User Stories

- US-1 — As a tester, I want beta, so that codes collide across phases.

## Acceptance Criteria

### Index

| Req | AC | Name | Live-bearing |
|---|---|---|---|
| REQ-1 | AC-1 | beta-one | |

### Requirement: REQ-1 — beta SHALL exist.

traces-to: US-1

#### AC-1 — beta-one

```
Given beta
When run
Then it exists
```
