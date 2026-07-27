---
kind: bridge
referenced-by: [assay, design-spec, design-review]
references: [ground-and-sweep]
kill-on: lever-discipline-mechanisation
---

**breadth-baseline method** — how a rule's case-domain, once enumerated and confirmed
with the live human in the interview, is carried forward so that the later contract
stages *verify* case coverage against it instead of re-partitioning the same domain
from scratch every run. Produced in assay's map arm, carried in the Consensus Scope,
consumed by the design-spec and design-review breadth axis.

**What "breadth" means is settled elsewhere.** The breadth axis itself, and the
saturation ruler that decides when any sweep may stop, are homed in
`ground-and-sweep.md`; this fragment cites that ruler and never rewrites it. What lives
here is the *baseline* — the artifact that lets a downstream stage verify rather than
re-derive.

## Terms (defined here; used by the consumers above)

- **case-partition** — a rule's case-domain split by a NAMED technique (equivalence
  partitioning, boundary-value analysis, a decision table, state transitions, Nagy's
  five), the human confirming the resulting rows one by one. The produced artifact is a
  single line:

  ```
  rule <content-phrase> → cases [...] (technique) [trace: ids]
  ```

  An enumeration the human never confirmed is not a partition at all, and is never
  carried anywhere.

- **entry identity** — an entry lives inside a dated `## Consensus` section of an assay
  record. Its identity is that section's date plus its full `[trace: ids]` set,
  order-insensitive; anything binding to the entry may cite any single id out of the
  set. Supersession runs per RULE and keys on the section date: the newest dated
  section's entry for a rule displaces the older one whether or not their id sets
  overlap.

- **partition-under-determined** — a partition whose production floor failed: the human
  did confirm the enumeration, but no technique was ever named for it. Render it by
  appending `(partition-under-determined)` to the entry line. Nothing verifies against
  it silently.

- **staleness** — a partition holds only for the rule it was confirmed for, under the
  intent that the readiness yes ratified. It goes stale when the downstream
  requirement's normative sentence no longer expresses the rule that the confirmed
  content-phrase named — a case the author adds, drops, or renames is a change and not a
  verification, so an author claiming the verify branch cites both texts — or when a
  newer dated Consensus section carries an entry for the same rule, only the newest
  being eligible as a baseline. Stale means say so and re-discover; it never means
  verify quietly.

## Flow — produce → carry → verify

**Produce.** The assay map arm captures a confirmed enumeration when one happens to
arise; no interview step exists to force one, and its absence is the ordinary case.

**Carry.** The Consensus Scope renders the entry in the shape above, ratcheted by the
same human readiness yes that ratchets the seam-map.

**Verify.** The design-spec and design-review breadth axis checks each requirement's
case coverage against the entry, degrading to full partition discovery whenever no
valid baseline is in hand.
