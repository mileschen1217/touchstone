---
type: spec
status: accepted
---
# Fixture — story dangling
## User Stories
- US-1 — a
## Acceptance Criteria
### Index
| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | a |
| REQ-2 | AC-2 | b |
### Requirement: REQ-1 — SHALL X
traces-to: US-1
#### AC-1 — a
```
Given x
When y
Then z
```
### Requirement: REQ-2 — SHALL Z
traces-to: US-9
#### AC-2 — b
```
Given p
When q
Then r
```
