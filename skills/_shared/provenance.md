---
kind: bridge
referenced-by: [design-review, deliverable-review, assay]
---

# Dispatch provenance — canonical reference

Sole home of review-round provenance.

**Lens** — one review perspective (a prompt with its own subject and finding types). **Arm** — one execution of a lens in its own context: `cc` (a fresh agent) or `codex`. A gate declares its lens set and, per lens, its arms; vendor diversity is a property of the arm set.

## Where provenance lives

`review.yaml` (field set: `skills/_shared/schemas/review.schema.yaml`) is a round's single output; there is no envelope file.

| Field | Meaning |
|---|---|
| `providers` | one entry per declared lens: `{lens, arms}` — the arms that actually produced content for that lens; an arm that failed, timed out, or returned nothing parsable is absent from `arms`. **Liveness:** `codex` is listed only when the round dir holds its `raw_codex.jsonl` and `last-message.txt`; a Codex-wrapper return without them counts as a `cc` arm |
| `findings[].found_by` | the arms whose output carried this finding (same field + same type across arms → one finding, both arms listed) |
| `findings[].refs` | the spec ids the finding's `field` path resolves to; `[]` only when `file`/`line` locate it outside the spec |
| `degraded` | true iff any lens ran fewer arms than the gate declared for it, OR the vendor rule was waived (deliverable-review: the quality lens's arm set holds only the builder's vendor) |
| `degraded_reason` | required when degraded; the six admitted literal shapes are the schema pattern on this field (review.schema.yaml — single home); `partial` = an arm ran but its output carried no parsable finding or verdict |
| `challenger` | design-review: the arm that ran the challenger lens |
| `waiting_on_human` | the complete current list of `W-n` items for this gate — presence = still waiting; a resolved item is removed |

No lens produced content → no review.yaml; the gate surfaces the failure and stops.

## Merge rules (shared by every gate; a gate's own section carries only its delta)

- Same `field` + same `type` across arms → ONE finding, `found_by` listing every arm that carried it; otherwise `found_by` = the one arm.
- `counts` is computed from the merged findings' severities, never copied from an arm's own tally.

## Presentation duty

`degraded: true` → the presenting gate shows the reason VERBATIM and gets explicit human acknowledgement before reporting ready, even at C+H = 0.
