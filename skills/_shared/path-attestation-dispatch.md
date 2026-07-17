# Path+attestation dispatch (single home)

The orchestrator-side dispatch form for a large doctrine fragment, under the graded
injection policy (fragment size decides verbatim vs path). A consumer names this file
and its own fragment + duty; it does not restate the mechanics below.

- **When:** a >20-line doctrine fragment reachable by the reviewer (a resolvable
  absolute path AND the agent has a Read tool — CC `code-reviewer` has Read, Codex
  reads paths). A ≤20-line fragment is injected verbatim instead.
- **How:** give the reviewer the absolute `${CLAUDE_PLUGIN_ROOT}/...` path and require
  it to read the fragment FIRST and emit a READ witness line for it; the body is not
  pasted into the prompt.
- **Shared fallback:** a dispatch that fails its attestation is re-dispatched once,
  then the gate halts loudly — never a silent fallback to pasted text, never a
  silently-dropped doctrine. A reviewer that genuinely cannot read the path falls back
  to pasted content for that one dispatch.
