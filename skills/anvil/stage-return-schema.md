# stage-return/v1 Schema

The `stage-return/v1` artifact is the normalized envelope that anvil reads after each dispatched stage
completes. It is produced by `scripts/normalize-stage-return.sh` (the adapter) and validated by
`scripts/check-stage-return.py` (the validator). **anvil proceeds to the next stage ONLY from the
validator's normalized `status`** — never from raw stage text, never from liveness inference.

## Shape

```json
{
  "schema":    "stage-return/v1",
  "stage":     "entry-precondition | plan-review | final-review",
  "status":    "DONE | NEEDS_HUMAN | BLOCKED",
  "reason":    "<non-empty string>",
  "artifacts": ["<path>", "..."],
  "source":    "<path to the native output this was normalized from>"
}
```

## Field cardinality

| Field       | Required          | Type           | Constraint                                                      |
|-------------|-------------------|----------------|-----------------------------------------------------------------|
| `schema`    | always            | string         | must equal `"stage-return/v1"`                                  |
| `stage`     | always            | string         | must be one of the three allowed stages (see below)             |
| `status`    | always            | string         | `DONE`, `NEEDS_HUMAN`, or `BLOCKED` (no other values)           |
| `reason`    | iff non-DONE      | string         | non-empty string; MUST be absent or empty iff DONE              |
| `artifacts` | iff DONE          | array of str   | non-empty; each element is a non-empty string path; MUST be absent or `[]` for NEEDS_HUMAN/BLOCKED |
| `source`    | optional          | string         | path to the native output file this envelope was normalized from |

## Allowed stages

- `entry-precondition` — the Phase-3.1 spine-integrity gate (`design-review-precheck.sh`)
- `plan-review` — the cross-provider review of the plan produced by `writing-plans`
- `final-review` — the cross-provider review of the delivered artifact

## Validator semantics (`scripts/check-stage-return.py`)

- **Fail-closed**: any malformedness → prints `status=BLOCKED`, exits 0. Never raises, never upgrades.
- Unknown or missing `schema` → `BLOCKED`.
- Unknown `stage` value → `BLOCKED`.
- Unknown `status` value → `BLOCKED`.
- Unknown top-level field (not in `{schema, stage, status, reason, artifacts, source}`) → `BLOCKED`.
- `DONE` + non-empty `reason` → `BLOCKED` (exclusion direction: DONE carries no reason).
- `DONE` + missing/empty/non-list `artifacts` → `BLOCKED` (DONE MUST produce ≥1 artifact).
- `NEEDS_HUMAN` or `BLOCKED` + missing/empty `reason` → `BLOCKED` (reason is required for non-DONE).
- `NEEDS_HUMAN` or `BLOCKED` + non-empty `artifacts` → `BLOCKED` (non-DONE carries no artifacts).
- Missing file or unparseable JSON → `BLOCKED`.

## Adapter mapping (`scripts/normalize-stage-return.sh`)

The adapter maps each stage's EXISTING native output to the envelope without requiring the stages to
speak a new protocol.

| Stage | Native output | Mapping |
|---|---|---|
| `entry-precondition` | `precheck.out` (stdout) + `precheck.rc` (exit code) | exit 0 → `DONE`; non-zero → `BLOCKED` (reason = BLOCK line from stdout) |
| `plan-review`, `final-review` | `review.result.json` (raw status/provenance) + `review.md` (free-text synthesis with `STAGE-REVIEW-SUMMARY` sentinel) | sentinel missing → `BLOCKED`; `status: failed` → `BLOCKED`; `degraded=true` or `status: partial` → `NEEDS_HUMAN`; `critical+high == 0` → `DONE`; `critical+high ≥ 1` → `BLOCKED` |

> `degraded` is NOT stored in `review.result.json` — it is derived per
> `cross-provider-reviewer/references/provenance.md` Operation 3 and written into the
> `STAGE-REVIEW-SUMMARY` sentinel by the reviewer composite. The adapter trusts the sentinel.
