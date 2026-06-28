# Multi-commitment fixture: CacheLayer (honored) + RateLimiter (violated)

## CacheLayer — HONORED (deep module)

```python
class CacheLayer:
    def get(self, key: str) -> object | None: ...
    def set(self, key: str, value: object) -> None: ...
    def delete(self, key: str) -> None: ...
```

TTL management, eviction policy, and expiry arithmetic are fully internal.
Callers cannot see or control these. The commitment is honored: callers
interact only via key+value; all cache internals are hidden.

---

## RateLimiter — VIOLATED (shallow module, split check/record)

```python
class RateLimiter:
    def check_limit(self, user_id: str) -> bool:
        """Returns True if under limit — but does NOT record the attempt."""
        ...

    def record_attempt(self, user_id: str) -> None:
        """Records an attempt. Callers MUST call this after check_limit."""
        ...
```

### Caller must sequence these manually

```python
limiter = RateLimiter()
if limiter.check_limit(user_id):
    # Must remember to record — the module does NOT do it atomically
    limiter.record_attempt(user_id)
    process_request()
else:
    reject_request()
```

The commitment is VIOLATED: callers must call check_limit + record_attempt
in sequence. The cycle is not atomic and not encapsulated. A caller that
forgets record_attempt silently bypasses the rate limit.
