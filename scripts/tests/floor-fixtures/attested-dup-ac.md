---
type: spec
status: accepted
---
# Fixture — Attested Dup-AC (duplicate Acceptance Criteria heading — must exit non-zero)

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

## Acceptance Criteria

### Requirement: REQ-2 — duplicate heading — must block

#### AC-2 — duplicate heading blocks

```
Given a duplicate Acceptance Criteria heading
When digest is called
Then exit non-zero
```

## Architecture

This section is non-attested and must not affect the digest.
