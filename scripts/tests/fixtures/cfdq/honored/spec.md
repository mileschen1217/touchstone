---
type: spec
kind: bridge
date: 2024-01-01
status: accepted
epics: [fixture]
kill-on: fixture
---

# Fixture: honored commitment

## Architecture

- **SessionStore SHALL be deep** — it SHALL hide all internal storage implementation
  details; it SHALL NOT leak its internal key-encoding scheme to callers. Callers
  supply a session-id and receive/store a value; the key layout is never visible.
  (interface economy: callers need know nothing about internal representation)
