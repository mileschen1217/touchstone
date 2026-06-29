---
type: spec
kind: bridge
date: 2024-01-01
status: accepted
epics: [fixture]
kill-on: fixture
---

# Fixture: ambiguous honor (AC-8 — [unverified] on ambiguous commitment)

## Architecture

- **ConfigManager SHALL be deep** — it SHALL hide the configuration source
  selection logic; callers request a config key and receive a value without
  needing to know whether the value came from environment variables, a file,
  or a remote config server. The source precedence order SHALL NOT be visible
  to callers.
  (interface economy: callers need not know where config values originate)
