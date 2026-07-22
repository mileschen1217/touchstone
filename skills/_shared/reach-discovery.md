---
kind: bridge
referenced-by: [crucible, assay, design-spec, design-review]
references: [ground-and-sweep]
kill-on: lever-discipline-mechanisation
---

**reach-discovery method** — how to sweep a cross-boundary artifact's *reach* (its
full party/site set) to saturation at the explore phase, so a saturated **seam-map**
is produced up front instead of leaving reach to a late gate. Consumed by crucible's
explore phase (produce) and assay's territory arm (confirm into the Consensus Scope);
the design-spec / design-review reach axis later verifies against that baseline.

**Terms (defined here; used by the consumers above):**

- **seam-map** — the artifact→party mapping a sweep produces: `artifact → {party:
  file:line}` for every party that touches the artifact, plus the channels swept and
  any declared-unavailable channel.
- **cross-boundary artifact** — an artifact that crosses an actor/module boundary so
  that ≥2 distinct parties must agree on it (record / schema / message / wire-format /
  config / shared skill-fragment). The trigger test is party-count > 1, not a
  file-type list — it is `ground-and-sweep.md`'s own shared-artifact test.
- **channel** — one orthogonal way of discovering parties (below). *Orthogonal* means
  **distinct blind spots**: a party invisible to one channel is not thereby invisible
  to the others.

**Saturation is not defined here.** The stop condition — the **multi-channel plateau**
and its ≥2-channel floor — is homed in `ground-and-sweep.md`; this fragment cites that
one ruler and never restates its definition.

## The three orthogonal channels

| channel | probe | finds | blind spot |
|---|---|---|---|
| **structural** | call-site grep / AST — grep the symbol, resolve references | static references by exact name | renamed / re-exported / dynamically-dispatched uses |
| **textual** | naming-kin match — sibling names, doc mentions, string keys | parties named by convention, not by import edge | parties sharing no lexical kinship with the artifact |
| **historical** | co-change — `git log -S<token>`, `git log -- <path>` | parties that changed together in history | anything outside history (shallow clone / just-added) |

Structural and textual share one blind spot: an identifier **composed or dynamic at
runtime** (concatenated, templated, reflected) appears in neither a name-grep nor a
lexical-kin scan. Only the historical channel — co-change — surfaces it.

## Under-sweep failure-mode catalog

Each row: the observable risk-signature in the artifact, and the channel it makes
**mandatory** (beyond the structural default).

| risk-signature (observable) | mandatory channel | why |
|---|---|---|
| dynamic / composed / reflected identifier (name assembled at runtime) | **historical** | structural + textual share this blind spot; only co-change sees it |
| artifact renamed / re-exported under an alias | textual + historical | structural keys on the old exact name and misses the alias |
| config / schema key consumed by string lookup (no import edge) | textual | no call-site edge exists for the structural channel to follow |
| new consumer in a sibling module, no shared history yet | textual | historical is empty for a just-added party; naming-kin catches it |

A sweep that runs only the structural channel is a **single-search first-hit** — the
named failure mode `ground-and-sweep.md` forbids: one channel cannot observe a plateau
(the ≥2 floor there), so a one-channel "done" is reach-under-determined, not saturated.

## Availability degradation

A channel can drop out (shallow clone / no history → historical empty). Record which
channel is missing in the seam-map. As long as two or more channels remain usable,
reach the plateau over those — the omission is stated, not skipped in silence. If fewer
than two survive, no plateau can be observed at all: flag the seam-map
**reach-under-determined** and hand it up with the gap named, rather than dressing an
unfinished sweep as a settled result.

**Precision option (never required).** An external repo-graph tool (Aider / SCIP /
stack-graphs / LSP) can sharpen the structural channel, but `grep` + `git` are the
floor — the method runs with no external dependency.
