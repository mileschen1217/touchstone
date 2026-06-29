# utils addition — additive fixture

```python
# Added to existing utils.py
def format_timestamp(ts: float, fmt: str = "%Y-%m-%d %H:%M:%S") -> str:
    """Format a Unix timestamp as a human-readable string."""
    from datetime import datetime
    return datetime.utcfromtimestamp(ts).strftime(fmt)
```

This is purely additive — a new function added to the existing `utils` module
interface. No new state, no hidden decisions, no sequencing requirements.
The AC-2 sentinel in the spec is correct.
