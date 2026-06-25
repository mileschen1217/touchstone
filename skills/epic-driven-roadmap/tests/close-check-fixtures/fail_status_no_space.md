---
slug: demo-nospace
status:done
started: 2026-01-01
landed: 2026-06-01
---

# Demo Status No Space After Colon

**Aim:** `status:done` (no space after colon) is a YAML plain scalar, not a mapping entry — must fail.

## Foundation

- **Intention (why):** A hand-edit missing the space after the colon leaves status unset in valid YAML;
  the check must not accept it as a done stamp.
- **Out of scope:**
  - Nothing excluded.

## Phases

| # | Title | Status |
|---|---|---|
| 1 | Phase 1 | done |

## Retrospective

**What worked**
- N/A
