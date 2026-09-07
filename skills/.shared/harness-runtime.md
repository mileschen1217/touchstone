---
kind: bridge
---

# Harness runtime

Derive `<plugin-root>` from this skill. Run `scripts/resolve-harness.sh` for the
active host, never an installed CLI; apply its adapter to resolve
`<project-root>`, invoke skills, and dispatch reviews. A missing
capability follows the owning workflow's stop or degradation rule.
