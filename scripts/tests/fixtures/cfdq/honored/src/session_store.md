# SessionStore — honored (deep module)

## Interface

```python
class SessionStore:
    def get(self, session_id: str) -> dict | None: ...
    def set(self, session_id: str, data: dict) -> None: ...
    def delete(self, session_id: str) -> None: ...
```

## Implementation note

Internally uses a prefixed key scheme (`"sess:" + session_id`) but this is
fully hidden. Callers interact only via `session_id` + `data`. The key
encoding is never exposed in the public interface.

This fixture demonstrates a DEEP module: the interface is simple (3 methods),
the implementation hides the key-encoding decision, and callers cannot
mis-order operations.
