# ConfigManager — ambiguous honor fixture

The code provides a ConfigManager but its internals are not shown in this
fixture — only the public interface and a partial implementation note:

```python
class ConfigManager:
    def get(self, key: str) -> str | None: ...
    def get_all(self) -> dict: ...
    def reload(self) -> None: ...
```

## Implementation note (ambiguous)

The implementation uses multiple sources. The `reload()` method triggers
re-reading from all sources. Whether the source precedence logic is hidden
from callers or accessible via some metadata method is not documented here.

The `get_all()` method returns all config values — but it is unclear whether
the returned dict keys reveal the source provenance (e.g. keys prefixed with
`env:` or `file:`) or are source-neutral.

This ambiguity makes it impossible to determine from code inspection alone
whether the commitment to hide source selection is honored. A reviewer cannot
determine honor without running the code or seeing the full implementation.
