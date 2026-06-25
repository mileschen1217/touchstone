---
slug: demo-intable-malformed
status: done
started: 2026-01-01
landed: 2026-06-01
---

# Demo In-Table Malformed Row

**Aim:** A non-pipe-delimited line inside the table region must fail loud (A2).

## Foundation

- **Intention (why):** In-table rows that break the pipe shape must not be silently skipped.
- **Out of scope:**
  - Nothing excluded.

## Phases

| # | Title | Status |
|---|---|---|
| 1 | Phase 1 | done |
This line is inside the table but not pipe-delimited.
| 2 | Phase 2 | done |

## Retrospective

**What worked**
- N/A
