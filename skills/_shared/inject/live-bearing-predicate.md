---
injected-by: [design-review, code-review]
referenced-by: [design-spec]
kind: bridge
---

**live-bearing predicate** — operational classification; the shared text both `design-review` and `code-review batch` **load-and-inject** into their cold dispatched reviewer (the per-stage application is each skill's own delta).

- **Predicate:** An AC is **live-bearing** ⟺ its Given/When/Then asserts a behaviour that **cannot be discharged offline** — it depends on an un-owned, wired, deployed, real-scale, or otherwise non-offline-dischargeable boundary. Classify by behaviour, not wording (not a closed keyword list).
- **Signals:** a network/API call, a DB/filesystem write, device I/O, a real `Agent()`/sub-process dispatch, or a deployed/wired target are common signals, but each counts ONLY when the predicate holds.
- **Ownership counter-example:** invoking the project's OWN deterministic in-repo script/CLI, or a test writing to its own temp fixture dir, is owned + offline + deterministic → NOT live-bearing (even though it spawns a process or touches the filesystem); a non-deterministic in-repo script (e.g. one making a real network call) is NOT exempt — apply the predicate.
- **Tie-breaker:** If ambiguous, treat as live-bearing (default stricter).
- **Avoid:** a closed keyword list — the predicate is behavioural; a fixed keyword set drifts.
- **Live artifact (evidence rule):** a live-bearing AC is discharged only by a **live artifact** — captured output of actually exercising the behaviour against the real boundary. A static proxy (grep / mock / env-faked condition / deployed-file read) never satisfies it. The artifact carries **provenance**: (1) which producer/invocation made it (re-runnable command or identifiable session) + (2) freshness (commit/timestamp tying it to current code).
- **Producer ≠ judge:** the artifact is produced before the gate by a script/session/build run — never by the reviewer authenticating it. Authentication burden scales with fakeability: a hand-pasteable perf log demands strong provenance; a real `Agent()` transcript is largely self-attesting and demands less. Do NOT require cryptographic signing of artifacts (over-spec — a human is in the loop at close). Examples: real-device run → serial log; headless browser vs a real build → screenshot/DOM snapshot; perf script → timing log; build session dispatching `Agent()` → subagent transcript.
