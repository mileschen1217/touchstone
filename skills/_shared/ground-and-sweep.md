---
referenced-by: [design-spec]
injected-by: [design-review]
kind: bridge
kill-on: lever-discipline-mechanisation
---

**ground-and-sweep doctrine** — dual-use fragment; loaded warm by `design-spec` (FF arm) and cold-injected by `design-review` (FB arm). One rule, two orthogonal per-unit tests. **ground-before-assert:** each unit (FF: each generated AC; FB: each emitted finding) must name concrete repo facts — file path, line number, value, or AC-id; a generic placeholder ("the system should…", "code has issues") fails. **sweep-to-dry:** the work unit is the AC's true-subject full set; stop only at saturation (a full pass surfaces nothing new), never at first-hit — first-hit is the named failure mode. Root — **intension-extension floor:** a requirement's intension does not finitely enumerate its extension; coverage is asymptotic and saturation is the only honest stopping criterion. **Scope-resolution:** when an AC's true subject set is a superset of the delivery diff, the reviewer/author must cover the full subject set, not just the diff.

Per-arm deltas (FF: every subject element has ≥1 AC = generation-coverage; FB: a full pass surfaces nothing new = search-saturation) are carried by each consumer's wrapper, not restated here.

_Avoid_: restating the per-arm saturation criterion or unit identity in this file — those deltas belong to the consumer wrapper; a hardcoded copy here is the drift surface this homing removes.
