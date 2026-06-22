---
type: spec
status: accepted
---
# Fixture — traces-to separator variants
## User Stories
- US-1 — a
- US-2 — b
- US-3 — c
- US-4 — d
## Acceptance Criteria
### Index
| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | a |
| REQ-2 | AC-2 | b |
### Requirement: REQ-1 — SHALL X
traces-to: US-1 US-2
#### AC-1 — a
```
Given x
When y
Then z
```
### Requirement: REQ-2 — SHALL Z
traces-to: US-3,US-4
#### AC-2 — b
```
Given p
When q
Then r
```
