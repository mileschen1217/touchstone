---
type: spec
status: accepted
---
# Fixture — Attested Nonattested (Architecture prose changed — digest must be invariant)

## Foundation

- **Intention:** Make the system do something useful.
- **Aim:** Users can complete the workflow end-to-end.
- **Out of scope:** Admin UI, analytics, third-party integrations.

## User Stories

- US-1: As a user I want to submit a form so that my data is saved.

## Acceptance Criteria

### Index

| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | submit saves data |

### Requirement: REQ-1 — the system SHALL save submitted data

#### AC-1 — submit saves data

```
Given a valid form
When the user submits
Then the data is persisted
```

traces-to: US-1

## Architecture

This section is non-attested. Changing it must NOT change the digest.
Extra sentence added to prove non-attested invariance.
