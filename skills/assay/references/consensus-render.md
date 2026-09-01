---
referenced-by: [assay]
load-when: "the alignment table has converged and the consensus render is due"
kind: bridge
---

## Consensus render — the object of the yes

After the table converges (no open contradiction, every unknown dispositioned) and BEFORE the consequence probes, render the `## Consensus` section as a pre-yes end-turn message: four subsections — Scope / Invariants / Contract facts / Out-of-scope — every entry traced to its stable ids (`[trace: <ids>]`).

- Reuse the Presentation rules from `SKILL.md`; the depth-tier axis here is the entry's load-bearing STATUS — Scope / Invariants / Contract-facts entries get full text, Out-of-scope entries get one line. The render covers exactly the four subsections, never the record's `deferred[]` key.
- **Seam-map in Scope (triggered intent).** When the intent changed a cross-boundary artifact, the Scope carries its saturated seam-map as `artifact → {party: file:line}` entries, each ending with a `[trace:]` to its confirmed row. A **zero-party** result — the sweep found no other party — is NOT dropped: it lands as an explicit `no other parties (swept via <channels>)` Scope entry (a valid zero-party plateau), so a mis-fired trigger (an artifact that was not actually cross-boundary) stays visible for review.
- **Case-partition in Scope (opportunistic).** Scope MAY carry, for a rule whose case list the interview confirmed, one entry of the fixed shape `rule <content-phrase> → cases [...] (technique) [trace: ids]` — shape and terms homed in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/breadth-discovery.md`. A list confirmed with no technique named still lands, marked `(partition-under-determined)`: the human's ruling is preserved instead of discarded, and no consumer may treat the marked entry as a valid baseline. Where the interview confirmed no such list there is no entry and no placeholder — that absence is the ordinary case rather than a gap, and nothing further is asked of the human on account of it.
- **A carried baseline is human-confirmed.** The plateau-declared seam-map, and any case-partition entry beside it, becomes a verify-against baseline for any downstream stage ONLY after the human confirms it at the readiness yes (the standard Consensus yes covers both). That human yes — not the sweep or the enumeration on its own — is the ratchet.
- **Render before persist.** The record's `consensus` key is written only at or after the yes; while not yet persisted, keep the render's digest tier inline rather than collapsing to a record-file pointer.
- **Re-render on a correction** (a falsified probe, or a correction at the readiness ask): re-converge and re-render on the corrected state — the eventual yes never lands on a stale render.
