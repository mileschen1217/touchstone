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
| `providers` | one entry per declared lens: `{lens, arms, fragments_read}` — the arms that actually produced content for that lens; an arm that failed, timed out, or returned nothing parsable is absent from `arms`. **Liveness:** `codex` is listed only when the round dir holds its `raw_codex.jsonl` and `last-message.txt`; a Codex-wrapper return without them counts as a `cc` arm |
| `providers[].fragments_read` | the fragment ids the arm reported reading (its report's opening `fragments_read: <ids>` line); compare-target: the ids the assembler printed for that lens. Absent only alongside a degraded round — its absence on a non-degraded round, or an empty list, is a validator error (review.schema.yaml's cross-field rule) |
| `findings[].found_by` | the arms whose output carried this finding (same field + same type across arms → one finding, both arms listed) |
| `findings[].refs` | the spec ids the finding's `field` path resolves to; `[]` only when `file`/`line` locate it outside the spec |
| `degraded` | true iff any lens ran fewer arms than the gate declared for it, the vendor rule was waived (deliverable-review: the quality lens's arm set holds only the builder's vendor), or an arm ran but could not prove it read its lens (the read-back class, below) |
| `degraded_reason` | required when degraded; the admitted literal shapes are the schema pattern on this field (review.schema.yaml — single home); `partial` = an arm ran but its output carried no parsable finding or verdict; the read-back class — an arm ran but could not prove it read its lens — is `lens <name>: read-back missing` (no fragment ids reported) or `lens <name>: read-back incomplete — missing <space-separated ids>` (a proper subset reported) |
| `challenger` | design-review: the arm that ran the challenger lens |
| `waiting_on_human` | the complete current list of `W-n` items for this gate — presence = still waiting; a resolved item is removed |

No lens produced content → no review.yaml; the gate surfaces the failure and stops.

## Arm dispatch mechanics (one home for every gate's transport; a dispatch site states only its deltas)

Lens composition is declared once in the lens manifest, which only the assembler
(subprocess) and the load map read — the dispatching session reads neither it nor the
fragments it declares.

- Health probe before any codex arm: `codex --version >/dev/null 2>&1 && echo codex_healthy=1 || echo codex_healthy=0`.
- Per lens × arm, build the arm's two round-dir files:
  `bash "${CLAUDE_PLUGIN_ROOT}/scripts/assemble-arm-task.sh" --arm <label> --round-dir <dir> --lens <name> (--subject-file <path> | --subject-cmd "<cmd>")`
  — it prints the lens path, the subject path, and the fragment ids; record the ids for
  the merge's read-back comparison. `--arm` label = `<lens>-<vendor>` wherever two
  same-vendor arms share a round dir.
- One `Agent` call per arm, all calls in ONE assistant message, each arm a fresh context:
  - **cc** — `Agent(subagent_type: "touchstone:code-reviewer", description: "<lens>", prompt: "lens_file: <lens path>\nsubject_file: <subject path>\n" + the caller context lines the arm needs — target id, round dir)`. No fragment, spec, or diff text in the prompt.
  - **codex** — `Agent(subagent_type: "touchstone:codex-reviewer", description: "<lens>", prompt: envelope {task_file: <subject path>, task_dir: <round dir>, system_prompt_file: <lens path>, role: <the gate's role string>})`. No inline lens text.
- A re-dispatched arm (fallback or liveness re-try) reuses the SAME two assembled files — never re-assemble.

## Merge rules (shared by every gate; a gate's own section carries only its delta)

- Same `field` + same `type` across arms → ONE finding, `found_by` listing every arm that carried it; otherwise `found_by` = the one arm.
- `counts` is computed from the merged findings' severities, never copied from an arm's own tally.
- `fragments_read` vs the ids the assembler printed for that lens: equal → the lens is applied; a proper subset or empty → the round is degraded, the reason naming the lens and the missing ids; an id outside the manifest entry → the merge fails naming the id.

## Presentation duty

`degraded: true` → the presenting gate shows the reason VERBATIM and gets explicit human acknowledgement before reporting ready, even at C+H = 0.
