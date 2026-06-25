---
slug: demo-status-nbsp
status: done
started: 2026-01-01
landed: 2026-06-01
---

# Demo Status Non-Breaking Space

**Aim:** `status:` followed by U+00A0 (non-breaking space) and `done` — must fail.

## Foundation

- **Intention (why):** A non-breaking space (U+00A0) after the colon is not
  a valid YAML ASCII separator; the check must treat status as missing/unrecognised.
- **Out of scope:**
  - Nothing excluded.

## Phases

| # | Title | Status |
|---|---|---|
| 1 | Phase 1 | done |

## Retrospective

**What worked**
- N/A
