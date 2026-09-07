---
kind: bridge
---

# Harness runtime

Derive `<plugin-root>` from this skill. Run `scripts/resolve-harness.sh` for the
active host, never an installed CLI; apply its adapter to resolve
`<project-root>`. Before invoking a skill or dispatching an arm, rerun the
resolver with `--require skill-invocation`, `native-subagent`, or
`external-reviewer`. A missing invoke/native capability stops; a missing
external reviewer uses provenance's degraded native fallback.
