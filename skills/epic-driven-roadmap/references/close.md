# Close an epic

**Failure semantics.** Blocking — step 0 (ship verification), step 3 (the
close-readiness check), and Evidence Reckoning's blocking rules (§ below).
The Disposition pass (step 5) is an action list, not a gate — skipping an item
leaves a dual-home and is noted in the close report.

0. **Verify ship before stamping anything.** Ship = the project-defined
   deliverable handoff landed (merged PR on `main`, pushed tag, deployed
   artifact) — a local commit, an open PR, or a pushed feature branch is not
   shipped. Gather evidence (`gh pr list --state merged`, `git log
   origin/main`, or the project's own check), propose it to the user, get
   explicit ack.
1. Edit `.touchstone/epics/<epic-dir>/index.md`: in `## Phases` set every row's
   Status to `done` and fill Landed (YYYY-MM-DD); in frontmatter set
   `status: done` and `landed: <YYYY-MM-DD>`; fill the Retrospective block
   (bullets only — What worked / What pivoted / What to do differently, ≤5
   lines total).
2. **Comprehension cite.** Reference each phase's Post-build pair (the dossier's
   首頁 + the quiz block of its `deviation.yaml`, produced at phase ship —
   single home: `references/phase-ship.md`) in the close report; close never
   re-runs the quiz. A phase that shipped without its pair → produce it now,
   per phase-ship.md, before closing.
3. Run:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/epic-driven-roadmap/check-close-ready.sh" .touchstone/epics/<epic-dir>/index.md
   ```
   Show the full output. Non-zero → fix and re-run.
4. Run Evidence Reckoning (§ below); append its section to the epic index.
   Then ask the fixed recall question — "這個 epic 裡,你抓到哪些 gates 沒抓到的?" —
   and append every answer to `.touchstone/gate-miss.md` in the six-field
   primitive (`date | artifact | 事件 | 應然 locus | 實然 locus | severity`); an
   answer of "none" appends nothing — the close report records `recall: none`.
5. Run the Disposition pass (§ below).
5a. Regenerate the dossier:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" .touchstone/epics/<epic-dir>
   ```
   Per the renderer header.
6. Update `ROADMAP.md`: move the epic's row from § Active to § Completed
   with the landed date, pointing at the archived index path.
7. Move the whole epic dir to `.touchstone/archive/epics/<epic-dir>/`
   (`mkdir -p .touchstone/archive/epics` first), then commit. An empty `epics/` dir means no in-flight work — that invariant
   is the workspace's status indicator.

## Evidence Reckoning

Per-AC accounting, authored once at close by reading the committed
artifact the AC asserts about — never the plan/test assertion pointing at
it. Cite fresh: `(via: read → <file>:<line>: <content asserted present>)`.

For each `status: accepted` spec of this epic, one row per AC:

| AC | Covered by (test / live-artifact ref) | unverified | live-bearing? | waiver | Issue |
|----|----|----|----|----|----|

- **Covered by** — the evidence found asserting the AC's Then-clause; blank
  = none found. Non-live-bearing AC → a test reference. Live-bearing AC → a
  live artifact with provenance (producer identity + freshness/commit). The
  deliverable-review `review.yaml` is the first place to read; its
  `status: unverified` findings pre-fill the unverified column.
- **live-bearing?** — "yes" iff the AC's `live_bearing` is true.
- **waiver** — a human-written rationale to consciously proceed past a
  non-live gap.
- **Issue** — the filed debt issue for each unverified / waiver row.

**Blocking rules:** a non-live-bearing row with no Covered-by, no
unverified mark, and no waiver BLOCKS close. A live-bearing row closes only
with a live-artifact-with-provenance Covered-by cell — unverified and
waivers are unavailable on a live-bearing row; an uncovered or proxy-only
live-bearing AC BLOCKS close (defer the whole AC to a later phase instead
of faking coverage). An unverified/waiver row with an empty Issue cell
BLOCKS close. An un-reckoned AC (no row at all) BLOCKS close.

Append the table to the index as `## Evidence Reckoning`.

## Disposition pass

Two halves:

- **Declared** — from each accepted spec's ledger rulings and `delta.blocks[]`:
  promote each decision that must outlive the epic to its home (a structural
  ruling → an ADR; vocabulary → CONTEXT.md past its admission boundary; behavior →
  already in source, nothing to copy); retire the bridge docs the epic created
  and check every `kill-on:` trigger across the project's standing docs — fired →
  retire now.
- **Discovered** — mechanised: for every path in each spec's `touch_set.touched`,
  grep the standing docs (`README*`, `CLAUDE.md`, `CONTEXT.md`, `docs/**`) for that
  path or its basename; each hit is one row: `doc | touch_set path | updated in
  this epic? (yes / why not)`. The human fills the last cell.

Record the pass as `## Disposition` in the index: promoted (path → home),
retired (path), kill-on checked (fired/quiet), the standing-docs table, or
`all none`.
