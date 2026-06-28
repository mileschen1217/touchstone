# SspSession — violated (shallow module, SSP-shaped)

## Implementation

```python
class SspSession:
    # Fine-grained mutators that expose the orchestration sequence:
    def connect(self, host: str, port: int) -> None: ...
    def set_timeout(self, seconds: int) -> None: ...
    def authenticate(self, user: str, password: str) -> bool: ...
    def set_session_id(self, sid: str) -> None: ...
    def begin_transaction(self) -> None: ...
    def set_transaction_mode(self, mode: str) -> None: ...
    def execute_command(self, cmd: str) -> str: ...
    def commit(self) -> None: ...
    def rollback(self) -> None: ...
    def disconnect(self) -> None: ...

    # Same-name-two-meaning fields:
    status: str  # "connected" | "authenticated" | "in_transaction" | "error"
    # callers must read `status` before each call to know which calls are valid
```

## Handler (caller must know the sequence)

```python
# Callers are responsible for the sequence — the module leaks its
# orchestration order to every handler:
session = SspSession()
session.connect(host, port)
session.set_timeout(30)
session.authenticate(user, password)
session.set_session_id(generate_id())
session.begin_transaction()
session.set_transaction_mode("READ_COMMITTED")
result = session.execute_command("GET balance")
session.commit()
session.disconnect()
```

This fixture is UNAMBIGUOUSLY SHALLOW:
- 10 fine-grained mutators expose the internal protocol sequence
- Callers must orchestrate the sequence themselves
- The `status` field has same-name-two-meaning (valid operations depend on current status)
- The spec commitment is clearly violated
