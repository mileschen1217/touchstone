---
type: spec
status: accepted
---
# Fixture — Body With DUP String (literal __DUP__ in body must NOT trigger dup-block)

## Foundation

- **Intention:** Make the system do something useful.
- **Aim:** Users can complete the workflow end-to-end.
- **Out of scope:** Admin UI, analytics, third-party integrations.

## User Stories

- US-1: As a user I want to handle error code __DUP__ gracefully.

## Acceptance Criteria

### Index

| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | handles dup string |

### Requirement: REQ-1 — the system SHALL handle __DUP__ in body text

#### AC-1 — handles dup string

```
Given a spec with __DUP__ in the body
When digest is computed
Then it succeeds (exit 0) and returns a 64-hex hash
```

traces-to: US-1

## Architecture

Non-attested section.
