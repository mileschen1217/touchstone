---
referenced-by: [design-spec]
injected-by: [design-review]
kind: bridge
kill-on: lever-discipline-mechanisation
---

**ground-and-sweep doctrine** — dual-use fragment; used by design-spec when **generating** a spec's checks, and by design-review when **reviewing** one. One rule, two orthogonal per-unit tests:

- **ground-before-assert:** each unit must name concrete repo facts — file path, line number, value, or AC-id; a generic placeholder ("the system should…", "code has issues") fails.
- **sweep-to-dry:** the work unit is the AC's true-subject full set; stop only at saturation (a full pass surfaces nothing new), never at first-hit — first-hit is the named failure mode. The true-subject set spans **two orthogonal dimensions**, and a sweep is dry only when **both** are saturated:
  - **breadth** — the rule's case-domain: every branch / case, partitioned EP/BVA/Nagy-style.
  - **reach** — every party / site the change touches: producer / consumer / all call-sites (the Scope-resolution bullet below). **Forcing question (run it per unit, not optional): for each thing the unit asserts *present / named*, name its consumer and check the unit covers what that consumer must be able to *do* with it — presence ≠ usability.** (e.g. an AC that asserts a review *lens is named* but not *defined for the cold reviewer that consumes it* is reach-incomplete — the named lens is unusable by its consumer.)
  Saturating one axis while leaving the other (e.g. all cases enumerated but only the validator updated, not the producer; or a thing named but not made usable by its consumer) is a first-hit false-green — the most common real miss.
- **Root — intension-extension floor:** a requirement's intension does not finitely enumerate its extension; coverage is asymptotic and saturation is the only honest stopping criterion.
- **Scope-resolution (the reach axis):** when an AC's true subject set is a superset of the delivery diff, the reviewer/author must cover the full subject set, not just the diff. **Shared-artifact case** (the most common violation): when a requirement changes an artifact that crosses an actor/module boundary — a record / schema / message / file / wire-format / config — its true subject is *every party that touches that artifact*, not the one party in the diff. Sweep the party set to saturation; producer / consumer / migrator are common roles to jog the sweep, NOT an exhaustive checklist (a logger, cache, replicator, or downstream transformer may also touch it). First-hit on the validator-only (or producer-only) party is the named failure.

Each arm's unit identity and saturation criterion live in that consumer's wrapper (design-spec / design-review), not here.
