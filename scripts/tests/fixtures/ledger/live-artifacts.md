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
- The five documented misses — FULL verbatim `catch-miss/v1` lines as they landed in
  `.touchstone/ledger/entries.jsonl` (re-extracted at fix-wave time via
  `jq -c 'select(.id=="ledger-20260703-015" or .id=="ledger-20260703-022" or
  .id=="ledger-20260703-023" or .id=="ledger-20260703-046" or
  .id=="ledger-20260703-065")' .touchstone/ledger/entries.jsonl`; evidence
  arrays are complete, not truncated):

```json
{"schema":"catch-miss/v1","id":"ledger-20260703-015","dedupe_key":"c7aa4657c3175d4f88ccaf27a2911fbb14f8b44cf5c4dc8303ccc735ed9e2a0e","ts":"2026-07-03T12:00:00Z","epic":"workflow-mechanization","caught_by":"human","should_have":"live-probe","gap_class":"false-green","what":"User asked whether setup-otel.sh had actually been live-tested; a brew-install failure (no formula, contrib-only binary) surfaced only after that prompt.","evidence":[{"kind":"transcript","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/5fda56cd-a9bd-4484-9296-def271681341.jsonl#38589470-38590100"}],"source":"sweep:transcript","candidate_mechanism":"mandatory end-to-end live run before claiming a setup script works"}
{"schema":"catch-miss/v1","id":"ledger-20260703-022","dedupe_key":"70462a14bc9e618853940c7aeb7677a930cf949c0f8b64d153c19a1b1309797e","ts":"2026-07-03T12:00:00Z","epic":"workflow-mechanization","caught_by":"human","should_have":"design-review","gap_class":"missing-AC","what":"User noticed there was no CC-subagent metrics data at all; an activation gap in the metrics-capture epic surfaced only post-ship.","evidence":[{"kind":"transcript","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/5fda56cd-a9bd-4484-9296-def271681341.jsonl#76314557-76315233"}],"source":"sweep:transcript","candidate_mechanism":"activation-completeness AC on the user-observable outcome, not a fixture proxy"}
{"schema":"catch-miss/v1","id":"ledger-20260703-023","dedupe_key":"e6d33b912cf3c5371218f2f223fc0abac3f56698259a110abc82f0b96829a1be","ts":"2026-07-03T12:00:00Z","epic":"workflow-mechanization","caught_by":"human","should_have":"design-review","gap_class":"missing-AC","what":"User asks why the metrics epic's live-bearing verification missed the CC-subagent gap entirely and requests a workflow root-cause analysis.","evidence":[{"kind":"transcript","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/5fda56cd-a9bd-4484-9296-def271681341.jsonl#76609266-76610269"}],"source":"sweep:transcript","candidate_mechanism":"same as ledger-20260703-022 — root-cause traced to design-spec/design-review not requiring the activation AC"}
{"schema":"catch-miss/v1","id":"ledger-20260703-046","dedupe_key":"593c60babad0bf252b18d9fe55f13fb15e0ce92eef4f6f0e448a6c403eece535","ts":"2026-07-03T12:00:00Z","epic":"workflow-mechanization","caught_by":"human","should_have":"code-review:batch","gap_class":"false-green","what":"metrics-capture v1 spec (owned-writer design) silently diverged from the shipped v2 mechanism (hook-stamp + durable-log harvest); the drift went undetected through build and review until epic-close Evidence Reckoning forced a spec amendment, and 2 of 26 ACs remained genuinely uncovered by tests even after amending.","evidence":[{"kind":"transcript","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/a3b7eedf-353c-4fe8-b464-095bb6da7517.jsonl#3445542-3452531"},{"kind":"transcript","ref":"transcript:/Users/miles/.claude/projects/-Users-miles-claude-code-touchstone/a3b7eedf-353c-4fe8-b464-095bb6da7517.jsonl#7040392-7047210"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/epics/workflow-mechanization/index.md#row-265"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/epics/workflow-mechanization/index.md#row-266"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/epics/workflow-mechanization/index.md#row-268"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/epics/workflow-mechanization/index.md#AC-25"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/epics/workflow-mechanization/index.md#AC-13"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#amendment-1"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#amendment-2"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#AC-16"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#AC-17"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#AC-18"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#AC-19"},{"kind":"reckoning","ref":"reckoning:/Users/miles/claude_code/touchstone/.touchstone/specs/2026-06-29-metrics-capture-design.md#AC-22"}],"source":"sweep:transcript","candidate_mechanism":"spec-vs-shipped-code drift check run continuously (or at minimum at every mid-epic pivot), not deferred to epic-close Evidence Reckoning; regression tests for AC-13 malformed-manifest and AC-17 collision-resistance"}
{"schema":"catch-miss/v1","id":"ledger-20260703-065","dedupe_key":"8c4152fafcf63e15818822e9cfcfaf6c37a6641d5216d1f36daee0d9a1e16f05","ts":"2026-07-03T12:00:00Z","epic":"workflow-mechanization","caught_by":"live-probe","should_have":"test-suite","gap_class":"false-green","what":"The Phase 2 project-registered-checks anchor needed 4 follow-up fixes (insight session-id, rtk-wrapper classifier miss, hooks exec bit, metrics manifest leak); the rtk-wrapper miss was found only via a live re-probe.","evidence":[{"kind":"git","ref":"git:14c16a92dd885b6dd16b9c7645dd50ea05200258"}],"source":"sweep:git","candidate_mechanism":"live re-probe of deployed hooks/checkers as a standing post-merge step, not a one-time verification"}
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
- **scan-state.json transcripts-section cursor values** (before = `/tmp/ss-1.json`, captured
  after run 1 / before run 2, still present on this machine at fix-wave time; after = the
  current `.touchstone/ledger/scan-state.json` on this machine — later than run 2 because
  this producer session, `a3b7eedf-...`, and one other session kept writing between then and
  now). Cursor is a byte offset into the transcript file; unchanged rows demonstrate the
  bounded-rescan claim above, changed rows are sessions that grew after the captured snapshot:

  | transcript (basename) | before cursor | after cursor | changed? |
  |---|---|---|---|
  | 097307ff-f4be-4ded-a298-85a4a19f2620.jsonl | 37303 | 37303 | no |
  | 25ab4310-01d8-4c9e-ab3e-7dc17c2e4b08.jsonl | 1036788 | 1549606 | yes (session active after snapshot) |
  | 5036c02f-7445-4e80-8012-606855ef26be.jsonl | 19977559 | 19977559 | no |
  | 5466e98d-90cb-4ce6-a0a6-75ac303dce19.jsonl | 90836882 | 90836882 | no |
  | 5fda56cd-a9bd-4484-9296-def271681341.jsonl | 80620637 | 80620637 | no |
  | 65111533-6319-432e-bcea-ea9d6350005c.jsonl | 42086 | 42086 | no |
  | 88a793f5-c528-4a1e-8c29-843d7bcba533.jsonl | 283928368 | 283928368 | no |
  | a3b7eedf-353c-4fe8-b464-095bb6da7517.jsonl (this session) | 45402453 | 49333421 | yes (this fix-wave's own turns) |
  | adb4f82f-9645-46cc-88a8-a15810648bd4.jsonl | 67631338 | 67631338 | no |
  | b4518b37-9b79-44ab-8ada-255becc31ba6.jsonl | 67498 | 67498 | no |
  | d0eb5d0e-1baa-4c73-b850-2531c479d7d1.jsonl | 41247554 | 41247554 | no |
  | d17fa412-ce15-4db6-97c8-bd1f93db4881.jsonl | 43358 | 43358 | no |
  | d183a20c-a69d-4a55-bf8d-86e1b95d3b08.jsonl | 36640 | 36640 | no |
  | tmp.GIIy10LzeJ/out.jsonl (fixture scratch, pre-existing) | 0 | 0 | no |
  | tmp.GIIy10LzeJ/sess1.jsonl (fixture scratch, pre-existing) | 1284 | 1284 | no |

  11 of 15 rows are byte-identical between before and after, corroborating the bounded-rescan
  claim above; the two changed rows are explained by ongoing session activity (this fix-wave
  session and one sibling session), not by a re-scan from zero.
- Note (honest scope): the sweep dir contains sessions beyond the two epics' window; the extractor scanned all (unfiltered cursor mode per procedure); entry.epic is best-effort. The rtk-pipeline gotcha struck once during verification (jq vanished inside a rewritten inline loop → vacuous JOIN OK) — re-run via script file, non-vacuous result above; itself candidate ledger material for a future sweep.

## Machine-local raw bundle (pointer, for the local reckoner)

The full raw artifacts underlying the excerpts above live under
`.touchstone/ledger/` on this machine (gitignored, not part of the committed
surface — see `CLAUDE.local.md § Local Doc Routing`):

- `entries.jsonl` — the live ledger; the five ids above are a `jq -c 'select(...)'` slice of it.
- `.candidates-log.jsonl` — the retained per-run L1 classification artifact (candidate/v1 lines, is_miss:true and false both present, including the negative-control samples above).
- `scan-state.json` — the current cursor state; compare against the `/tmp/ss-1.json` snapshot referenced above (that snapshot is a machine-local `/tmp` artifact, not part of this repo, and may not survive a reboot).
- `fire-log.jsonl` — not present on this machine at fix-wave time (the AC-11 probe ran in a scratch dir under `/private/tmp/claude-501/...`, not this repo's ledger dir); the AC-11 line above was captured from that scratch run, not from this repo's `.touchstone/ledger/`.

A fresh-context reviewer without access to this machine cannot re-run these
greps; the verbatim excerpts above are the authenticatable evidence for that
reader. A reviewer WITH access to this machine can re-run the `jq` command
quoted above to confirm the excerpts still match current ledger state.
