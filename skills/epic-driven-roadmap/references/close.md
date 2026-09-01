# Close an epic

**Failure semantics.** Blocking — step 0 (ship verification) and step 3 (the epic
checker, which enforces the reckoning blocking rules). The Disposition pass
(step 5) is an action list, not a gate — skipping an item leaves a dual-home and
is noted in the close report.

0. **Verify ship before stamping anything.** Ship = the project-defined
   deliverable handoff landed (merged PR on `main`, pushed tag, deployed
   artifact) — a local commit, an open PR, or a pushed feature branch is not
   shipped. Gather evidence (`gh pr list --state merged`, `git log
   origin/main`, or the project's own check), propose it to the user, get
   explicit ack.
1. **Comprehension cite.** Reference each phase's two accepts — the contract
   accept (its assay record's readiness ruling) and the ship informed-accept
   (the Post-build pair: the dossier's 首頁 + the quiz block of its
   `quiz.yaml`, produced at phase ship — single home:
   `references/phase-ship.md`) — in the close report; close never re-runs the
   quiz and asks for no accept of its own. A phase that shipped without its
   pair → produce it now, per phase-ship.md, before closing.
2. **Evidence Reckoning.** Author `reckoning[]` in the epic's `epic.yaml` —
   one row per AC of every `status: accepted` spec in the epic dir, written
   once at close by reading the committed artifact the AC asserts about,
   never the plan or test assertion pointing at it. Cite fresh, specific
   evidence in `covered_by` (`(via: read → <file>:<line>: <content asserted
   present>)`; a `live_bearing: true` row closes only on a live artifact's
   provenance — producer identity + freshness/commit token). The
   deliverable-review `review.yaml` is the first place to read; its
   `status: unverified` findings pre-fill `unverified` rows. `waiver` = a
   human-written rationale to consciously proceed past a non-live gap;
   `issue` = the filed debt issue for an unverified or waived row. The
   blocking rules are the checker's (step 3) — an un-reckoned AC, an
   evidence-free row, a proxy-only or unverified/waived live-bearing row, or
   a missing issue blocks there.
   Then ask the fixed recall question — "這個 epic 裡,你抓到哪些 gates 沒抓到的?" —
   and append every answer to `.touchstone/gate-miss.md` in the six-field
   primitive (`date | artifact | 事件 | 應然 locus | 實然 locus | severity`); an
   answer of "none" appends nothing — the close report records `recall: none`.
3. Run (blocking; re-run after step 4 too — `status: done` arms the close gate):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" epic .touchstone/epics/<epic-dir>/epic.yaml --root .touchstone/epics/<epic-dir>
   ```
   Show the full output. Non-zero → fix and re-run; nothing below runs until it
   exits zero.
4. Edit `epic.yaml`: every `phases[].status` → `done` with `landed`
   (YYYY-MM-DD); top-level `status: done` and `landed`; fill `retrospective`
   (display-only block scalar, bullets only — What worked / What pivoted /
   What to do differently, ≤5 lines total).
5. Run the Disposition pass (§ below); record it in `epic.yaml`'s structured
   `disposition` field (`promoted` / `retired` / `kill_on` / `standing_docs`
   lists, or `none: true`).
5a. The shipped hook re-rendered the dossier at every write above; run
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" .touchstone/epics/<epic-dir>`
   yourself only when the hook did not fire.
6. Regenerate `ROADMAP.md` (same invocation the scaffold reference names, run
   from the project root) — the epic's row moves to Completed by generation,
   never by hand.
7. Move the whole epic dir to `.touchstone/archive/epics/<epic-dir>/`
   (`mkdir -p .touchstone/archive/epics` first), re-run the projection of
   step 6, then commit. An empty `epics/` dir means no in-flight work — that
   invariant is the workspace's status indicator. (Already-archived legacy
   epics keep their `index.md`; the renderer's legacy read path serves them —
   no retro-conversion.)

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

Record the pass in the `disposition` field: promoted (path → home), retired
(path), kill-on checked (fired/quiet), the standing-docs rows, or `none: true`.
