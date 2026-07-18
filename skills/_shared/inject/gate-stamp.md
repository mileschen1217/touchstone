---
injected-by: [anvil, design-review, code-review]
kind: bridge
kill-on: eval-reckon-kills-stamps-or-mechanises
---

**Gate stamp** — the single home of the stamp schema. A gate skill's stamp
step reads this file and follows it; no skill restates the field set.

Append exactly ONE line per **resolved run** to
`<project>/.touchstone/eval/stamps.jsonl` (create the dir/file if absent):

```
{"date":"<ISO8601 UTC>","gate":"<gate-id>","target":"<subject>","findings":{"C":n,"H":n,"M":n,"L":n},"fixed":n,"rounds":n}
```

- **Gate roster** (`gate-id` enum, also the adjudication set epic-close
  reckons over): `design-review` · `code-review-batch` · `anvil-final-review`.
  A schema change edits this file once; a new gate adds its id here plus its
  own stamp step pointing back.
- **Resolved run** = the gate reached a verdict/outcome report (zero-finding,
  DEGRADED, and fallback outcomes included). An aborted run (session death,
  human interrupt before verdict) owes no stamp; discovered later, it is
  recorded as a gate-miss line (event: un-stamped run).
- **Run identity** = the execution, not the target: re-reviewing the same
  target is a new run and stamps again; double-stamping one run is a defect
  the reckon reader flags — no run-id machinery (R2).
- **Failure duty**: if the append still fails after creating the path, the
  failure MUST appear in the gate's terminal report — silently skipping the
  stamp un-instruments the gate (the named defect: silent un-instrumentation).
