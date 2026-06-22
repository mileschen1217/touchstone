---
type: spec
status: accepted
---
# Fixture — story extract
## User Stories
- US-1 — As a dev, I want X, so that Y
- US-2 — As a dev, I want Z, so that W
- US-1abc — malformed, must be excluded
- See US-9 (prose, not an entry — excluded)

```
US-8 inside a fence — excluded
```
## Acceptance Criteria
### Index
| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | a |
### Requirement: REQ-1 — the system SHALL do X
traces-to: US-1, US-2
#### AC-1 — a
```
Given x
When y
Then z (US-7 fenced — excluded)
```
