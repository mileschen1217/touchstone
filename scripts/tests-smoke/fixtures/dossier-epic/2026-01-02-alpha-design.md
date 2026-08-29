---
type: spec
status: accepted
epics: [fixture]
---

# Alpha — Design Spec

## Foundation

- **Aim:** alpha.

## Phase map

- **Position.** phase 1 of 2.
- **Structure before → after.** one file → two files.
- **Interface delta.**

  | kind | surface | detail |
  |---|---|---|
  | new | `alpha.sh` | entry point |

- **Flow + scope.** touched: `a/`; untouched: `b/`.

## User Stories

- US-1 — As a tester, I want alpha, so that the renderer has a phase.

## Acceptance Criteria

### Index

| Req | AC | Name | Live-bearing |
|---|---|---|---|
| REQ-1 | AC-1 | alpha-one | |
| REQ-1 | AC-2 | alpha-two | |

### Requirement: REQ-1 — alpha SHALL exist.

traces-to: US-1

#### AC-1 — alpha-one

```
Given alpha
When run
Then it exists
```

#### AC-2 — alpha-two

```
Given alpha
When run twice
Then still exists
```
