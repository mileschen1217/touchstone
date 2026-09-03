---
referenced-by: [assay]
load-when: "writing the terminal record after the readiness yes"
kind: bridge
---

## Durable record — the terminal deliverable

Write `<epics-dir>/<slug>/assay-<YYYY-MM-DD>-<subject>.yaml` — top-level `subject:`
(one line; the contract author maps intention from it), `date:`, `epics:`. One record
per subject; a re-run APPENDs new dated entries, never overwrites. Entries stay at
digest density: one line per resolved row, full text only for rows still open and
load-bearing — the record is a handoff surface, not a transcript. Structured keys,
id families and order fixed — consumers key on these names:

- `term_sheet[]` — rows `T-n`
- `alignment[]` — rows `A-n`/`B-n`: dual tags + leaning + planned handling; bold-pass rows marked
- `extraction[]` — rulings `Q-n`; predict / probe rounds `R-n` (dated)
- both `alignment[]` and `extraction[]` items carry `rulings: [{date, stage, text}]` —
  the design-review write-back target
- `consensus` — four subsections `scope[] / invariants[] / contract_facts[] /
  out_of_scope[]`; every entry carries `trace: [<stable-ids>]` — stable ids only. A
  triggered cross-boundary-artifact intent's `scope[]` carries the seam-map as
  `artifact → {party: file:line}` entries (a zero-party plateau rendered explicitly);
  a confirmed case-partition rides that same `scope[]` in its own fixed shape
  (`breadth-discovery.md`)
- `flip_triggers[]` — observable signal + revisit point per row
- `deferred[]` — the non-load-bearing unknown stubs
- `readiness` — explicit yes + date + the clean round's `R-n`
- (deviations found downstream are `D-n` entries in the epic's `deviation.yaml`, never a key here)

**Existing `.md` records stay frozen read-only until epic archive** — every record
authored from this change forward is `.yaml`; no new `.md` record is written.

**The consensus section IS the handoff** — an implementation of the confirmed-facts source contract (`skills/_shared/inject/confirmed-facts-source.md`). The contract author derives Scope and Invariants facts from Consensus rows and itself authors the seam / AC layer — assay emits no contract-material packaging beyond the consensus section. Every disposition names its file (and line or anchor where applicable) so a later session executes it without re-derivation.

**Honest ceiling.** The interview narrows unknown-unknowns; it never proves them zero. Gap size is measured downstream by the deviation log — never claimed at interview end.
