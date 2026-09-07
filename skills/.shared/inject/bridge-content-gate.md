---
injected-by: [design-spec]
referenced-by: [lens-manifest.yaml]
kind: bridge
kill-on: lever-discipline-mechanisation
---

# Bridge content gate — three principles

Enforceable-rule. Every bridge claim must pass all three. Failure = defect.

- **P1 (non-duplication):** if source already encodes the claim (a type / function / test), the prose is duplicative. Delete or point at source. **Also rejects doc-as-workaround:** if prose explains why dead/duplicative source still exists, remove the source instead.
- **P2 (falsifiable):** every claim concrete enough to write a test / run a probe / grep against. The signal of failure is a claim whose truth conditions you cannot state — vagueness words ("usually", "complex", "careful", "elegant") mark those, but the test is the missing probe, not the word.
- **P3 (no single host):** if it fits in one symbol's `///` → rung 2; one function body's `// BRIDGE` → rung 3; **only** when no single host fits → rung 4 (`.md` bridge).

Composition: P1 → P2 → P3, in order. Failing one is a defect, not "needs work".
