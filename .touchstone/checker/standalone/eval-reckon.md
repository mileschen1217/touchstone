# Eval reckon — touchstone-local (runs only in this repo's own epics)

Not shipped: consumer projects write no stamps and run no reckon. The product axis
(`gate-miss.md`, `deviation.yaml`) stays in the shipped skills.

## Gate stamp (mechanism axis)

After each gate run in THIS repo's epics, append one line to
`.touchstone/eval/stamps.jsonl` (create if absent) — the counts read from the
round's `review.yaml`:

```
{"date":"<ISO8601 UTC>","gate":"<design-review|deliverable-review>","target":"<subject>","findings":{"C":n,"H":n,"M":n,"L":n},"fixed":n,"rounds":n}
```

One line per resolved run (a verdict was reached; degraded outcomes included);
an aborted run owes no stamp and, discovered later, becomes a gate-miss line.
Re-reviewing the same target is a new run.

## Reckon page (at epic close, after Evidence Reckoning)

Three sources: `stamps.jsonl`, `.touchstone/gate-miss.md`, the epic's
`deviation.yaml` — any absent one reads as empty. Append `## Eval Reckon` to the
epic index:

- One verdict row per gate (`design-review`, `deliverable-review`): keep / adjust /
  kill, each citing ≥1 source line; zero relevant lines → `keep — no data`.
- Flag, never skip: unparseable stamp lines, gate-ids outside the roster,
  byte-identical duplicates.
- An adjust/kill verdict names its concrete follow-up (path to edit or delete);
  kill executes within the close or is recorded blocked + reason + owner.
- A script/automation proposal names its pain class and lists the ≥3 same-class
  gate-miss lines it groups plus the epic index where the rule already ran as
  prose — otherwise mark it inadmissible.
