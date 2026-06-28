---
type: spec
kind: bridge
date: 2024-01-01
status: accepted
epics: [fixture]
kill-on: fixture
---

# Fixture: multi-commitment (one honored, one violated)

## Architecture

- **CacheLayer SHALL be deep** — it SHALL hide all TTL management and eviction
  logic; callers get/set by key and value only. The cache MUST NOT expose
  internal eviction policy selection or TTL arithmetic to callers.
  (interface economy: callers need not know when entries expire)

- **RateLimiter SHALL encapsulate its entire check-and-record cycle** — a single
  `check(user_id)` call SHALL return allowed/denied and record the attempt
  atomically; callers SHALL NOT need to call separate check and record methods
  in sequence.
  (cohesion: one reason to change — the rate-limiting algorithm)
