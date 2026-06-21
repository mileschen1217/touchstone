---
type: spec
status: accepted
---
# Fixture — Fenced Hash Guard
## Acceptance Criteria
### Index
| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | fence guard |
### Requirement: REQ-1 — the system SHALL handle fenced content
#### AC-1 — fence guard
```
Given a fenced block
## Inside fence
When the digest runs
Then this line does not terminate the section
```
## Architecture
