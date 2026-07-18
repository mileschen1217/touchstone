# Close an epic

**Failure semantics.** Blocking — step 0 (ship verification), step 3 (the
close-readiness check), and Evidence Reckoning's blocking rules (§ below).
Advisory — docs-current and eval reckon: findings go in the close report,
never fatal; the human may close with advisory findings noted. The
Disposition pass (step 5) is an action list, not a gate — skipping an item
leaves a dual-home and is noted in the close report.

0. **Verify ship before stamping anything.** Ship = the project-defined
   deliverable handoff landed (merged PR on `main`, pushed tag, deployed
   artifact) — a local commit, an open PR, or a pushed feature branch is not
   shipped. Gather evidence (`gh pr list --state merged`, `git log
   origin/main`, or the project's own check), propose it to the user, get
   explicit ack.
1. Edit `.touchstone/epics/<slug>/index.md`: in `## Phases` set every row's
   Status to `done` and fill Landed (YYYY-MM-DD); in frontmatter set
   `status: done` and `landed: <YYYY-MM-DD>`; fill the Retrospective block
   (bullets only — What worked / What pivoted / What to do differently, ≤5
   lines total).
2. **Comprehension cite.** Reference each phase's Post-build pair (buy-in
   explainer + comprehension quiz, produced at phase ship — single home:
   `references/phase-ship.md`) in the close report; close never re-runs the
   quiz. A phase that shipped without its pair → produce it now, per
   phase-ship.md, before closing.
3. Re-read the index to confirm steps 1–2 landed, then run:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/epic-driven-roadmap/check-close-ready.sh" .touchstone/epics/<slug>/index.md
   ```
   Show the full output. Non-zero → fix and re-run.
4. Run Evidence Reckoning, the docs-current check, and eval reckon (§
   below); append their sections to the epic index.
5. Run the Disposition pass (§ below).
6. Update `ROADMAP.md`: move the epic's row from § Active to § Completed
   with the landed date, pointing at the archived index path.
7. Move the whole epic dir to `.touchstone/archive/epics/<slug>/`
   (`mkdir -p .touchstone/archive/epics` first — pre-always-on workspaces
   lack it), then commit. An empty `epics/` dir means no in-flight work — that invariant
   is the workspace's status indicator.

## Evidence Reckoning

Per-AC accounting, authored once at close by reading the committed
artifact the AC asserts about — never the plan/test assertion pointing at
it. Cite fresh: `(via: read → <file>:<line>: <content asserted present>)`.

For each `status: Accepted` spec of this epic, one row per AC:

| AC | Covered by (test / live-artifact ref) | [unverified] | live-bearing? | waiver | Issue |
|----|----|----|----|----|----|

- **Covered by** — the evidence found asserting the AC's Then-clause; blank
  = none found. Non-live-bearing AC → a test reference. Live-bearing AC → a
  live artifact with provenance (producer identity + freshness/commit).
- **live-bearing?** — "yes" iff the AC's spec declares it live-bearing.
- **waiver** — a human-written rationale to consciously proceed past a
  non-live gap.
- **Issue** — the filed debt issue for each `[unverified]` / waiver row.

**Blocking rules:** a non-live-bearing row with no Covered-by, no
`[unverified]`, and no waiver BLOCKS close. A live-bearing row closes only
with a live-artifact-with-provenance Covered-by cell — `[unverified]` and
waivers are unavailable on a live-bearing row; an uncovered or proxy-only
live-bearing AC BLOCKS close (defer the whole AC to a later phase instead
of faking coverage). An `[unverified]`/waiver row with an empty Issue cell
BLOCKS close. An un-reckoned AC (no row at all) BLOCKS close. A healthy
close has an empty `[unverified]` set.

Append the table to the index as `## Evidence Reckoning`.

## Disposition pass

Every artifact in the epic dir is a short-lived delta; truth lives in
source code and the canonical homes (`docs/adr/`, CONTEXT.md, README).
Read each accepted spec's Source-level Deposit section, then:

- promote each declared durable residue to its named canonical home
  (a decision → an ADR; vocabulary → CONTEXT.md past its admission
  boundary; behavior → already in source, nothing to copy);
- retire the bridge docs the spec listed, and check every `kill-on:`
  trigger across the project's standing docs — fired → retire now;
- everything not promoted simply rides into the step-7 archive move.

Record the pass as `## Disposition` in the index: promoted (path → home),
retired (path), kill-on checked (fired/quiet), or `all none`.

## Docs-current check

List the repo docs this epic's diff plausibly affects (README, CLAUDE.md
sections whose meaning it changed, ADRs it supersedes). For each, confirm
it was updated in this epic's changes, or note why not. Advisory only.

## Eval reckon

Read `.touchstone/eval/stamps.jsonl` (gate stamps), `.touchstone/gate-miss.md`
(use-point failure events), and this epic's deviation log — treat any as
empty/absent if not yet created. Write one page: per gate touched by this
epic, a keep / adjust / kill verdict with the evidence line that earned it.
Ask the fixed recall question — "這個 epic 裡,你抓到哪些 gates 沒抓到的?" —
and append every answer to `gate-miss.md` as a new line (`date | artifact |
event | expected locus | actual locus | severity`). Append the page to the
index as `## Eval Reckon`.
