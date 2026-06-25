---
slug: demo-closed
status: done
started: 2026-04-01
landed: 2026-06-01
---

# Demo Closed Epic

**Aim:** Deliver the adapter removal cleanly.

## Foundation

- **Intention (why):** Remove premature abstraction that serves no external consumer.
- **Out of scope:**
  - Tracker renderers (GitHub/GitLab/Jira/Linear).

## Phases

| # | Title | Spec | Plan | Status | Landed |
|---|---|---|---|---|---|
| 1 | Delete adapter | — | — | done | 2026-05-15 |
| 2 | Rewrite tests | — | — | done | 2026-06-01 |

## Open Questions

*(none)*

## Retrospective

**What worked**
- Deleting the adapter made the skill dramatically smaller.

**What pivoted**
- Tests shifted from CLI-driven to structural/contract.

**What to do differently**
- Identify premature abstractions earlier.
