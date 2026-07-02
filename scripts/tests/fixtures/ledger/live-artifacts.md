# Live-bearing AC discharge artifacts — AC-11 / AC-15 (+ AC-22 see transcript-shapes/provenance.md)

- **Producer session:** a3b7eedf-353c-4fe8-b464-095bb6da7517 (this build session). **Date:** 2026-07-03 (UTC 2026-07-02 late). **Commit at run:** d2f517611e284d7d7dfc75d194eb9a1cb7b16c48
- Producer ≠ judge: these artifacts are for the fresh-context reviewer at Evidence Reckoning.

## AC-11 — live deployed-hook block appends a fire event

- Active cache hook patched from the repo copy under install-pointer discovery, WITH backup + before/after shas; restored after; before-sha re-verified identical.
  - before-sha: 2e07003f2b60e20fdf425f558d236012cf5a45ebccb64df984c48b0974ca6d80 (v0.10.4 cache copy)
  - patched-sha (== repo copy): 3c3d9c1fb5b7924b72fd993cb4d8b17a888bcffde2654ef4d0739915055976b1
- A REAL `git -C <scratch> commit` via the Bash tool was BLOCKED (exit-2, named check; `git log` count stayed 0), and the fire log gained exactly this line (verbatim):

```json
{"schema":"fire-event/v1","ts":"2026-07-02T18:27:57Z","check":"check-ac11.sh","repo":"/private/tmp/claude-501/-Users-miles-claude-code-touchstone/a3b7eedf-353c-4fe8-b464-095bb6da7517/scratchpad/ac11-probe","stage":"pre-commit"}
```

## AC-15 — real-history sweep

- Run 1: `collect` 26.0s wall over ~600MB of real transcripts + git history + both epics' reckoning artifacts + fire log → digest 7743 records (5.57MB); 29 L1 haiku dispatches (subagent_type general-purpose, model haiku, ≤200KB chunks; in==out==7743); validate-candidates rc=0; 92 is_miss candidates; 1 L2 sonnet dispatch → 69 staged entries; finalize OK → **entries: 69 (52571 bytes)**.
- The five documented misses, matched entries (ids + truncated whats + refs):

```
known-miss entries:
{"id":"ledger-20260703-015","what":"User asked whether setup-otel.sh had actually been live-tested; a brew-install failure (no formula, ","refs":["transcript:/Users/miles/.claude/projects/-Users-miles-claude"]}
{"id":"ledger-20260703-022","what":"User noticed there was no CC-subagent metrics data at all; an activation gap in the metrics-capture ","refs":["transcript:/Users/miles/.claude/projects/-Users-miles-claude"]}
{"id":"ledger-20260703-023","what":"User asks why the metrics epic's live-bearing verification missed the CC-subagent gap entirely and r","refs":["transcript:/Users/miles/.claude/projects/-Users-miles-claude"]}
{"id":"ledger-20260703-046","what":"metrics-capture v1 spec (owned-writer design) silently diverged from the shipped v2 mechanism (hook-","refs":["transcript:/Users/miles/.claude/projects/-Users-miles-claude","transcript:/Users/miles/.claude/projects/-Users-miles-claude","reckoning:/Users/miles/claude_code/touchstone/.touchstone/ep","reckoning:/Users/miles/claude_code/touchstone/.touchstone/ep","reckoning:/Users/miles/claude_code/touchstone/.touchstone/ep","reckoning:/Users/miles/claude_code/touchstone/.touchstone/ep","reckoning:/Users/miles/claude_code/touchstone/.touchstone/ep","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp","reckoning:/Users/miles/claude_code/touchstone/.touchstone/sp"]}
{"id":"ledger-20260703-065","what":"The Phase 2 project-registered-checks anchor needed 4 follow-up fixes (insight session-id, rtk-wrapp","refs":["git:14c16a92dd885b6dd16b9c7645dd50ea05200258"]}
{"id":"ledger-20260703-065","what":"The Phase 2 project-registered-checks anchor needed 4 follow-up fixes (insight session-id, rtk-wrapper classifier miss, hooks exec bit, metrics manifest leak); the rtk-wrapper miss was found only via a live re-probe.","evidence":[{"kind":"git","ref":"git:14c16a92dd885b6dd16b9c7645dd50ea05200258"}]}
```

  (insight session-id env-var, rtk-wrapper classifier bypass, hooks exec-bit are merged into the git fix-chain incident ledger-20260703-065 per the L2 merge rule; OTel built-not-deployed = -022/-023; metrics v1→v2 drift = -046.)
- **Live negative control** (own-gate catches classified is_miss:false; verbatim samples captured BEFORE run-2 truncation):

```
{"schema":"candidate/v1","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/097307ff-f4be-4ded-a298-85a4a19f2620.jsonl#9976-10493","is_miss":false}
{"schema":"candidate/v1","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/25ab4310-01d8-4c9e-ab3e-7dc17c2e4b08.jsonl#19164-19747","is_miss":false}
{"schema":"candidate/v1","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/25ab4310-01d8-4c9e-ab3e-7dc17c2e4b08.jsonl#20852-21941","is_miss":false}
```

- Run 2 (idempotence + bounded rescan): `collect` **1.4s vs 26.0s (≈18.5x faster)**; only 144 tail records (80KB) re-read; cursor-bound join over run-1 scan-state:

```
checked=104 violations=0
JOIN OK (non-vacuous): all 104 run-2 transcript refs start >= run-1 cursors
```

  Full run-2 pipeline: L1 (144/144, 5 is_miss — all reckoning re-reads), validate rc=0, L2 WITH the 69 current entries → staged=0 dropped=5 (each matched ledger-20260703-046's verbatim reckoning refs), finalize OK → **N1=69, N2=69: zero new entries**.
- Note (honest scope): the sweep dir contains sessions beyond the two epics' window; the extractor scanned all (unfiltered cursor mode per procedure); entry.epic is best-effort. The rtk-pipeline gotcha struck once during verification (jq vanished inside a rewritten inline loop → vacuous JOIN OK) — re-run via script file, non-vacuous result above; itself candidate ledger material for a future sweep.
