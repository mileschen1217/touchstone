# Dispatch provenance — canonical reference

Sole canonical home of the `review-envelope/v1` contract (per CONTEXT.md
§ Dispatch provenance "canonical contract: provenance.md wins"). The
`cross-provider-reviewer` and `code-review` skill bodies and the
`codex-reviewer` agent POINT here and never restate any of the below.

## review-envelope/v1 schema

On-disk filename: `review.result.json` (never bare `result.json` — that is the
separate task-result artifact). All six fields top-level and required. Liveness:
a dispatch given a `task_dir` that returns with no `review.result.json` on disk
is not accepted regardless of what was reported (reader: code-review Phase 3).

| Field | Type | Notes |
|---|---|---|
| `schema` | string | Literal `"review-envelope/v1"` |
| `status` | string | `"ok"` / `"partial"` / `"failed"` — was content produced. `partial` = a provider ran but its output is unreliable (Codex arm trigger: `-o` last-message file missing or empty with no terminal failure in the event stream). |
| `fallback_reason` | string or null | Why a provider was absent. Null when all expected ran. |
| `builder_vendor` | string or null | Pattern B only: vendor that built the code (`"cc"`/`"codex"`; builder detection = code-review Phase 1). Null for Pattern A. |
| `providers_expected` | string[] | Intended set. Pattern A default `["cc","codex"]`; Pattern B swap = single opposite-of-builder vendor; `with X` = `["X"]`. Never empty — populated even on total failure. |
| `providers_used` | string[] | Who produced content. `[]` on total failure. Values `"cc"`, `"codex"`. |

## No-derived-fields negative list

`review.result.json` MUST NOT contain any of: `quantity_ok`, `quantity_correct`,
`vendor_ok`, `vendor_correct`, `degraded`. These are derived at read/banner time,
never stored.

## Banner operations (derived at read/banner time, never stored)

- `quantity_correct` := `len(providers_used) == len(providers_expected) AND len(providers_used) > 0`. `vendor_correct` := false when `providers_used` empty; true under `force_reviewer` (runtime parameter, set when a `with X` modifier governed the invocation — never a stored field); Pattern B (`builder_vendor` non-null) → true iff `providers_used[0] != builder_vendor`; Pattern A → true iff `providers_used` has ≥2 distinct vendors.
- DEGRADED iff `(!quantity_correct || !vendor_correct) AND len(providers_used) > 0` — total failure (`providers_used == []`) is `status: failed`, NOT degraded, no banner varnish. Banner: `⚠️ DEGRADED — <reason-clause>`; reason-clause — if `!quantity_correct`: `"quantity: {len(providers_used)} of {len(providers_expected)} expected providers"`; if `!vendor_correct` and `builder_vendor` non-null (Pattern B): `"vendor: builder={builder_vendor} and reviewer={providers_used[0]}; cross-vendor swap failed"`; if `!vendor_correct` and `builder_vendor` null (Pattern A): `"vendor: cross-vendor scrutiny incomplete: only {join(providers_used, ", ")} ran"`; both → join with `"; "`.
- PARTIAL (orthogonal to DEGRADED; fires only when `status == "partial"`): one line per unreliable provider — `⚠️ PARTIAL — <provider> contribution unreliable: <reason>`, e.g. `⚠️ PARTIAL — codex contribution unreliable: last-message file empty with no terminal failure`. Ordering when both fire: DEGRADED first, PARTIAL second, blank line, body. Banners are PREPENDED to the synthesis text and `review.md`.
- Ack duty: any banner present → the presenting gate shows it VERBATIM and gets explicit human acknowledgement before reporting ready — even at Critical+High = 0.
