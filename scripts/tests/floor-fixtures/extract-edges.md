---
type: spec
status: accepted
---
# Fixture — Edge Cases for spec-extract

## Foundation

- **Intention:** Verify edge-case extraction behaviour.
- **Aim:** Fenced blocks, nested headings, and CRLF lines do not corrupt parsing.
- **Out of scope:** Runtime performance, UI concerns.

## User Stories

- US-1 — As a parser I want fenced blocks ignored so that false positives do not occur.
- US-2 — As a parser I want nested headings to not break section boundaries.

### Notes

Nested ### heading must not terminate the User Stories section.

#### Detail

Deeper #### heading also must not terminate the section.

## Acceptance Criteria

### Index

| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | fenced block ignored |
| REQ-2 | AC-2 | nested headings ok |

### Requirement: REQ-1 — the extractor SHALL ignore fenced blocks

traces-to: US-1

#### AC-1 — fenced block ignored

```
## User Stories
- US-99 — must not parse
```

### Requirement: REQ-2 — the extractor SHALL handle nested headings

traces-to: US-2

#### AC-2 — nested headings ok

```
Given a spec with nested ### and #### headings
When extraction runs
Then only top-level ## terminates the section
```

## Architecture

Non-attested section — must not affect the digest.
