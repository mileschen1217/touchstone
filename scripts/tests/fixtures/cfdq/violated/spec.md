---
type: spec
kind: bridge
date: 2024-01-01
status: accepted
epics: [fixture]
kill-on: fixture
---

# Fixture: violated commitment (SSP-shaped shallow module)

## Architecture

- **SspSession SHALL be deep** — it SHALL encapsulate the full session lifecycle
  (connect → authenticate → transact → disconnect) so callers invoke one method;
  it SHALL NOT leak its orchestration sequence to callers. Callers must not need
  to know or call individual protocol steps in order.
  (interface economy: callers need not know the internal state machine)
