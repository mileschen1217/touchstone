# Dispatch provenance — canonical reference

Sole canonical home of who-actually-reviewed provenance.

## Where provenance lives

`review.yaml` (field set: `skills/_shared/schemas/review.schema.yaml`) is the single
output of a review round; there is no separate envelope file.

| Field | Meaning |
|---|---|
| `providers` | who produced content — `cc`, `codex`; an arm that failed or timed out is absent. **Liveness:** `codex` is listed only when the round dir holds its `raw_codex.jsonl` and `last-message.txt`; a Codex-wrapper return without them counts as a `cc` arm (`degraded_reason: vendor: …`) |
| `degraded` | true iff fewer providers ran than the gate expected, OR the vendor rule failed (deliverable-review: reviewer vendor = builder vendor; design-review: only one vendor across both contexts) |
| `degraded_reason` | required when degraded: `codex unavailable` · `codex timeout (<n>s)` · `codex error: <detail>` · `partial` (a provider ran but its output carried no parsable finding or verdict) · `vendor: builder=<v> reviewer=<v>` |
| `challenger` | design-review: the provider that ran the challenger context |

Total failure (no provider produced content) → no review.yaml is written; the gate
surfaces the failure and stops.

## Presentation duty

`degraded: true` → the presenting gate shows the reason VERBATIM and gets explicit
human acknowledgement before reporting ready — even at C+H = 0. A clean round
triggers nothing.
