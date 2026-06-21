---
type: spec
status: accepted
---
# Fixture — req-self-trip (AC-7 harness assertion)

## Problem

This section is NOT the Acceptance Criteria section.
It intentionally contains tokens that could trip the parser if scope-guarding fails.

### Requirement: REQ-99 — a prose heading outside AC section

The following text contains markers that must NOT be flagged:

[NEEDS CLARIFICATION: this is outside AC section and must not be counted]

#### AC-99 — a body heading outside AC section

```
Given a fenced block outside AC section
When the checker runs
Then it must not flag anything here
```

## Acceptance Criteria

### Index

| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | first requirement |
| REQ-2 | AC-2 | second requirement |

### Requirement: REQ-1 — the system SHALL do X

#### AC-1 — first requirement

```
Given the fenced block contains [NEEDS CLARIFICATION: inside fence, not flagged]
When the checker strips fenced content
Then no marker violation is reported

### Requirement: REQ-99 — inside fence, not a real heading
#### AC-99 — inside fence, not a real AC
```

### Requirement: REQ-2 — the system SHALL do Y

#### AC-2 — second requirement

```
Given p
When q
Then r
```

## Architecture

### Heading after AC section

[NEEDS CLARIFICATION: this is after AC section and must not be counted]

#### AC-99 — heading after AC section, must not be parsed
