---
injected-by: [design-review, deliverable-review]
kind: bridge
---

**design-soundness honor-check** — two arms: feedforward at `design-review` (subject =
the spec's `delta.blocks[]` and `invariants[]`); feedback at `deliverable-review`
(subject = delivered code vs those commitments). The architecture rubric arrives
injected alongside this text — apply it as given.

**Three-criterion rule.** A block carries a structural commitment if it:
- hides a non-trivial implementation decision, OR
- holds or mutates state, OR
- sequences operations a caller could otherwise mis-order.

A purely additive block adds behaviour within an existing module's established
interface without introducing any of the above.

**The lens question (both arms):** does every block meeting the three-criterion rule
have an AC or a checked invariant (`invariants[].check` of `test`,
`grep` or `review`)? At design-review a block meeting the rule with neither is a
design-soundness finding on that block's field path. At deliverable-review each
invariant's `check` is executed — `grep` and `test` run, `review` judged against the
delivered code with the injected rubric; a check the reviewer cannot decide is recorded
`unverified` on the invariant's field path, never passed silently.

Report only **declared-and-violated** — a commitment the spec declared and the delivery
violated; code with no governing spec commitment is not reported under this lens.
