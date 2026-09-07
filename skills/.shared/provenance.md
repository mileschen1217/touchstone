---
kind: bridge
referenced-by: [design-review, deliverable-review, assay]
---

# Dispatch provenance — canonical reference

Sole home of review-round provenance.

**Lens** — one review perspective. **Arm** — one fresh-context execution keyed
by harness id. Provider diversity requires different `provider_family` values.

## Where provenance lives

`review.yaml` (field set: `skills/.shared/schemas/review.schema.yaml`) is a round's single output; there is no envelope file.

| Field | Meaning |
|---|---|
| `host` | the registered harness id running the gate; absent only on legacy artifacts |
| `providers` | one entry per declared lens: `{lens, arms, fragments_read}` — only arms that produced parsable content and their adapter-defined liveness artifacts |
| `providers[].fragments_read` | the fragment ids the arm reported reading (its report's opening `fragments_read: <ids>` line); compare-target: the ids the assembler printed for that lens. Absent only alongside a degraded round — its absence on a non-degraded round, or an empty list, is a validator error (review.schema.yaml's cross-field rule) |
| `findings[].found_by` | the arms whose output carried this finding (same field + same type across arms → one finding, both arms listed) |
| `findings[].refs` | the spec ids the finding's `field` path resolves to; `[]` only when `file`/`line` locate it outside the spec |
| `degraded` | true iff a lens ran fewer declared arms, a fallback lost provider independence, the vendor rule was waived, or an arm could not prove it read its lens |
| `degraded_reason` | required when degraded; the admitted literal shapes are the schema pattern on this field (review.schema.yaml — single home); `partial` = an arm ran but its output carried no parsable finding or verdict; the read-back class — an arm ran but could not prove it read its lens — is `lens <name>: read-back missing` (no fragment ids reported) or `lens <name>: read-back incomplete — missing <space-separated ids>` (a proper subset reported) |
| `challenger` | design-review: the arm that ran the challenger lens |
| `waiting_on_human` | the complete current list of `W-n` items for this gate — presence = still waiting; a resolved item is removed |

No lens produced content → no review.yaml; the gate surfaces the failure and stops.

## Arm dispatch mechanics (one home for every gate's transport; a dispatch site states only its deltas)

Lens composition is declared once in the lens manifest, which only the assembler
(subprocess) and the load map read — the dispatching session reads neither it nor the
fragments it declares.

- Resolve each arm and compare `provider_family` before claiming diversity;
  probe an external arm's CLI before dispatch.
- Per lens × arm, build the arm's two round-dir files:
  `bash "<plugin-root>/scripts/assemble-arm-task.sh" --arm <label> --round-dir <dir> --lens <name> (--subject-file <path> | --subject-cmd "<cmd>")`
  — it prints the lens path, the subject path, and the fragment ids; record the ids for
  the merge's read-back comparison. `--arm` label = `<lens>-<vendor>` wherever two
  same-vendor arms share a round dir.
- Run one adapter `dispatch_review_arm` per arm; pass role and paths, never file
  content. Liveness: Codex external `raw_codex.jsonl` + `last-message.txt`;
  Claude external `raw_claude.json` + `last-message-claude.txt`; native dispatch
  record (Claude: `raw_cc.md`).
- A failed complementary provider may fall back to another native fresh
  context only as degraded, with presentation duty.
- A re-dispatched arm (fallback or liveness re-try) reuses the SAME two assembled files — never re-assemble.

## Merge rules (shared by every gate; a gate's own section carries only its delta)

- Same `field` + same `type` across arms → ONE finding, `found_by` listing every arm that carried it; otherwise `found_by` = the one arm.
- `counts` is computed from the merged findings' severities, never copied from an arm's own tally.
- `fragments_read` vs the ids the assembler printed for that lens: equal → the lens is applied; a proper subset or empty → the round is degraded, the reason naming the lens and the missing ids; an id outside the manifest entry → the merge fails naming the id.

## Presentation duty

`degraded: true` → the presenting gate shows the reason VERBATIM and gets explicit human acknowledgement before reporting ready, even at C+H = 0.
