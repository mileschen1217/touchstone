# Close an epic

**Failure semantics (stated once for the whole close):**

- **Blocking** — step 0 (ship verification: zero evidence → refuse close; the
  only bypass is the user's explicit waiver this turn), the close-readiness
  check (step 4: fix and re-run until it passes — no waiver exists for it),
  and Evidence Reckoning (5b: its step-1 structural floor, step-4 rules, and
  step-5b mechanical check). `[unverified]` / waiver escape hatches exist
  ONLY where Evidence Reckoning's step-4 rules grant them — never on a
  live-bearing row.
- **Advisory** — Doc Reckoning (5), Catch-attribution sweep (5c), Proposal
  reconcile (5d): failures and findings go into the close report, never
  fatal; the human may close with advisory findings accepted.
- **Degrade** — a referenced script absent from the deployed plugin → skip
  that check and say so; never false-block.
- **Sweep stages** — an L0 extractor failure skips that source and proceeds;
  an L1/L2 stage failure discards the staged batch atomically and leaves
  `.last-sweep` untouched (the range re-extracts next sweep). Never proceed
  silently — always run `report` and paste its output.

0. **Verify Stage 7 ship before stamping anything.** Ship = the project-defined
   deliverable handoff landed (merged PR on `main`, pushed tag, deployed
   artifact); local commit / open PR / pushed feature branch ≠ shipped. Gather
   evidence (`gh pr list --state merged`, `git log origin/main`, or the
   project's own check), propose it to the user, obtain explicit ack.
1. Edit `.touchstone/epics/<slug>/index.md`: in `## Phases`, set each row's
   Status to `done` and fill Landed (YYYY-MM-DD).
2. In the same file's frontmatter set `status: done` and `landed: <YYYY-MM-DD>`.
3. Fill the Retrospective block — bullets only (What worked / What pivoted /
   What to do differently).
4. **Re-read the index to confirm steps 1–3 landed, then run the
   close-readiness check on that confirmed file:**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/epic-driven-roadmap/check-close-ready.sh" .touchstone/epics/<slug>/index.md
   ```

   Show the full output. Non-zero → fix and re-run.

5. Run **Doc Reckoning** (§ below) and append its block to the epic index.

5b. Run **Evidence Reckoning** (§ below).

5c. Run the **Catch-attribution sweep** (§ below). Paste the `report` phase
    output into the close report verbatim.

5d. Run the **Proposal reconcile** (read-only):
    `bash "${CLAUDE_PLUGIN_ROOT}/scripts/proposal/reconcile.sh"`. Paste its output
    verbatim into the close report. Close never touches the checker rail —
    accept/deploy decisions live only in the `/touchstone:insight` flow.

5e. **Comprehension face — cite, don't redo.** Reference each phase's
    Post-build pair (Buy-in explainer + comprehension quiz), produced at
    phase ship pre-approve — single home: `references/phase-ship.md`. Link
    each phase's pair artifacts in the close report; close never re-runs the
    quiz. A phase that shipped without its pair → produce it now per
    phase-ship.md before closing.

6. Update ROADMAP: if `${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-render.sh` exists,
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-render.sh" --root <project-root>`;
   otherwise move the epic's row from § Active to § Completed with the landed date.
7. Commit.

## Doc Reckoning

Mechanical inventory of what this epic did to the doc graph. It lists facts
and surfaces candidates in the output block only; every follow-up decision
(write/downgrade a bridge, delete, move, rung, deposit's lever, distill) is
the human's — intentionally NOT skillified. This procedure never acts on its
own findings.

**Inputs:** epic slug; git range from the index frontmatter's `started:` /
`landed:` dates (`git log --since "$STARTED" --until "$LANDED" …`).

**Procedure**

1. **Created docs** — `.md` files added in the range under `.touchstone/research/`,
   `.touchstone/specs/`, `.touchstone/plans/`, `.touchstone/docs/`. Record each
   with frontmatter `kind:`; a `kind: bridge` doc missing `kill-on:` →
   **finding** (advisory).
2. **Killed docs** — `.md` files deleted in the range; record path + the
   removing commit (best-effort: the commit naming a `lever-*` slug).
3. **Pending kills** — grep surviving `.md` frontmatter for `kill-on:` values
   whose lever already landed (cross-check ROADMAP § Completed): doc still
   present ⇒ **pending kill**.
3b. **Stale-candidate bridges (advisory)** — for each surviving bridge this
    epic touched: bridge mtime (`git log -1 --format=%ct`) older than a
    referenced source path's by >30 days ⇒ flag (human follow-up = the
    three-principle re-audit, `skills/_shared/inject/bridge-content-gate.md`).
3c. **Rung-misclassification candidates (advisory)** — a bridge section whose
    prose cites exactly ONE source path is a rung-2/3 candidate ("which symbol
    would a `///` doc-comment attach to?" — single answer = wrong rung).
3d. **Doc-as-workaround candidates (advisory)** — bridge sections explaining
    why dead/duplicative source still exists (trigger phrases: "deprecated",
    "kept until X ships", "do not use", "no-op stub", "legacy path").
4. **Source-level deposit** — read each design spec's `## Source-level Deposit`
   section; record the lever it names, or "none — <stated reason>".
5. **Built spec distill-or-archive** (classification per
   `skills/_shared/inject/standing-vs-transient-bridge.md`) — for each landed
   spec: pure transient → mark for `.touchstone/archive/specs/` +
   `kind: diagnostic` + `evidence-for:`; standing-candidate sections → list
   which distill to `.touchstone/docs/architecture/<topic>.md` (with own
   `kill-on:`); whole-spec cross-cutting (rare) → copy whole, retire original.

**Output — append to the epic index:**

```markdown
## Doc Reckoning

**Deposit (from specs):**
- `<spec-path>` → advances `<lever-slug>` (or `none — <reason>`)

**Created:**
- `<doc-path>` — kind: `<kind>` · kill-on: `<lever-slug>` (or none — flag if bridge)

**Killed:**
- `<doc-path>` — removed in `<commit-sha>` (advances `<lever-slug>`)

**Pending kills:**
- `<doc-path>` — kill-on `<lever-slug>` (landed `<date>` but doc still present)

**Stale-candidate bridges (advisory):**
- `<doc-path>` — last touched `<date>`; referenced source `<source-path>` last touched `<date>` (+N days newer)

**Rung-misclassification candidates (advisory):**
- `<doc-path>` § `<section>` — cites only `<source-path>`; suggested rung: 2 | 3 | argue cross-cutting

**Doc-as-workaround candidates (advisory):**
- `<doc-path>` § `<section>` — triggered by `<phrase>`; action: PR to remove `<source-path>` OR justify retention

**Built specs (distill-or-archive candidates):**
- `<spec-path>` — landed `<commit-sha>`; recommended: archive | distill <sections> → standing bridge | move-whole
```

## Evidence Reckoning

Per-AC accounting authored ONCE at close by reading source.

**Procedure**

1. **Structural floor first.** For each `status: Accepted` spec of this epic:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-spec-floor.sh" <spec-path>`.
   Non-zero BLOCKS close — fix the spec before continuing.

2. **Derive coverage.** Apply the evidence-honesty (coverage) criteria — the SAME
   criteria as `skills/code-review/SKILL.md` batch, **inlined here** so it is
   greppable in this host too (present at BOTH batch AND epic-close by design):

   > Read the governing spec's ACs and the test source. For each AC, judge whether a
   > test asserts that AC's Then-clause (AC coverage, semantic — not code-coverage %,
   > not tool-measured). If an AC is claimed done but no test in source asserts it and
   > it carries no `[unverified]` → report **silent false-green** (blocks the done
   > claim). A test that mocks the very boundary a boundary-crossing AC claims does
   > NOT discharge that claim (proxy, not coverage). Emit `[unverified: reason]` for
   > any AC you cannot confirm — never pass by default. `[unverified]` is honest and
   > allowed (informed-consent); surface findings, do not force passing.

2b. **Ground every coverage judgment.** The evidence is the **committed
   artifact** the AC asserts about — never the plan/test assertion pointing at
   it. Cite freshly per `grounded-claims`:
   `(via: read → <file>:<line>: <asserted content present>)`. A grep/bats line
   is itself a claim to re-ground; if re-running it against the artifact fails,
   the coverage claim is ungrounded → `[unverified]` (or fix the assertion).

3. **Build the reckoning table** (one row per AC across the epic's accepted specs):

   | AC | Covered by (test / live-artifact ref — verification evidence, derived at close) | [unverified] | live-bearing? | waiver | Issue |
   |----|----------------------------------------|----------------------|---------------|--------|-------|

   - "Covered by" = the evidence found asserting the AC; blank ⇒ none found.
     Non-live-bearing AC → a test reference. Live-bearing AC → a **live
     artifact with provenance** (producer identity + freshness —
     commit/timestamp). Satisfying cell shape:
     `Covered by: live artifact .touchstone/epics/<slug>/evidence/<name>.md @ <commit-sha> via <producer>`
   - "live-bearing?" = "yes" iff the AC id is in its spec's Verification
     Strategy `Live-bearing AC IDs`.
   - "waiver" = a human-written rationale to consciously proceed past a
     NON-LIVE gap.
   - "Issue" = the filed debt issue for each `[unverified]` / waiver row.

4. **Apply the blocking rules:**
   - A non-live-bearing row with no "Covered by", no `[unverified]`, and no waiver ⇒ **BLOCKS close**.
   - A live-bearing row closes ONLY with a live-artifact-with-provenance
     "Covered by" cell. A static proxy (grep / mock / env-faked condition /
     deployed-file read) does NOT satisfy it; `[unverified]` is
     **unavailable** and a waiver is NOT allowed on a live-bearing row ⇒ any
     uncovered / proxy-only live-bearing AC **BLOCKS close** — the only honest
     path is deferring the whole AC to a later phase.
   - An `[unverified]` or waiver row with an empty Issue cell ⇒ **BLOCKS close**.
   - An un-reckoned AC (no row) ⇒ **BLOCKS close**.

5. **Record**: append the `## Evidence Reckoning` section with the table to the
   epic index.

5b. **Mechanical gate check.**
   ```
   if [ -f "${CLAUDE_PLUGIN_ROOT}/scripts/check-evidence-reckoning.sh" ]; then
     bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-evidence-reckoning.sh" \
       .touchstone/epics/<slug>/index.md <spec-path>
   fi
   ```
   Non-zero BLOCKS close — fix each printed `BLOCK:` row.

A healthy close has an empty `[unverified]` set.

## Catch-attribution sweep

Harvests gate-miss signal (transcript corrections, git fix-chains, Evidence
Reckoning `[unverified]` rows, checker fire-log) from this closing epic's
history into `.touchstone/ledger/entries.jsonl`. Failure semantics: the
header block's Sweep-stages bullet.

### Step 1 — collect

Export the ledger dir and the three configurable source envs (firelog needs
none — it reads `$TOUCHSTONE_LEDGER_DIR/fire-log.jsonl` when present), then:

```bash
export TOUCHSTONE_LEDGER_DIR="<repo-root>/.touchstone/ledger"
export LEDGER_TRANSCRIPTS_DIR="$HOME/.claude/projects/$(pwd | tr '/._' '---')"
export LEDGER_GIT_REPO="<repo-root>"
export LEDGER_EPIC_DIR="<repo-root>/.touchstone/epics/<slug>"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh" collect
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh" report
```

If `report` prints "sources skipped (unconfigured)", one of the three envs was
empty at collect time — fix the export and re-run `collect` before continuing.

### Step 1b — prefilter (deterministic, recall-preserving)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh" prefilter
```

Drops provably-non-signal transcript records (blank tool-result envelopes, bare
slash-commands — usually most of a window) before the paid L1 sees them:
survivors → `.digest-classify.jsonl`, drops → `.prefilter-dropped.jsonl`, prints
`pre-filter: <kept> classified, <dropped> dropped`. **Structural only** — never
drops for looking "already covered" (recurrence signal `/touchstone:insight` reads).

### Step 2 — L1 classification dispatch (haiku, one dispatch per chunk)

Chunk the **survivor file** `$TOUCHSTONE_LEDGER_DIR/.digest-classify.jsonl`
(Step 1b's output, NOT raw `.digest.jsonl`) into ≤200KB pieces, never splitting
a line:

```bash
chunkdir="$(mktemp -d)"
awk -v maxb=200000 -v dir="$chunkdir" '
  BEGIN { idx = 0 }
  { n = length($0) + 1
    if (bytes > 0 && bytes + n > maxb) { idx++; bytes = 0 }
    file = dir "/chunk-" idx
    print $0 >> file
    bytes += n
  }
' "$TOUCHSTONE_LEDGER_DIR/.digest-classify.jsonl"
```

For EACH chunk, make ONE `Agent` dispatch with **explicit `model: "haiku"`**
AND **explicit `subagent_type: "general-purpose"`** — both pins every time
(unpinned model silently doubles cost; several named agent types lack the
Read tool this dispatch depends on). The dispatch prompt is the verbatim
content of `references/sweep-l1-classify-prompt.md` — the dispatched agent is
cold, so read that file and inline it as the prompt, substituting this chunk's
`<chunk-file-path>` and its distinct `<out-file-path>`.

Pass each chunk a distinct `<out-file-path>` (`$chunkdir/out-<idx>.jsonl`) so the
main thread never ingests raw candidate lines. After all chunks return, append
each out file to `.candidates-log.jsonl`
(`cat "$chunkdir"/out-*.jsonl >> "$TOUCHSTONE_LEDGER_DIR/.candidates-log.jsonl"`),
and compare each chunk's `wc -l` against its out file — a shortfall IS a dispatch
failure even at exit 0 (`validate-candidates` only shape-checks lines that
exist). Get the `is_miss:true` set for Step 4 by `jq`-ing the aggregated file,
never by re-reading it line by line.

On any chunk failure (error, timeout, no output, shortfall): append the EXACT
line `sweep incomplete: l1` to `$TOUCHSTONE_LEDGER_DIR/.sweep-incomplete`
yourself (the sequencing guard matches exact strings), skip that chunk, and
keep dispatching the rest for signal. After all chunks: if
`.sweep-incomplete` contains a `sweep incomplete: l1` line, skip Steps 3–4
entirely and run only Step 5's `report` (finalize would refuse; don't spend
the L2 dispatch). An unrelated L0 line there (e.g. `sweep incomplete: git`)
does NOT block Steps 3–5 — only `l1`/`l2` lines do.

### Step 3 — validate

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh" validate-candidates
```

Non-zero = L1 stage failure (`sweep incomplete: l1` recorded). One pass per
phase: fix step 2's output (re-dispatch the offending chunk), then re-run
`validate-candidates` once — never loop it within a collect cycle.

### Step 4 — L2 synthesis dispatch (sonnet, one dispatch)

Make ONE `Agent` dispatch with **explicit `model: "sonnet"`** and **explicit
`subagent_type: "general-purpose"`** (same pin rule as Step 2). The CLOSER
reads the three inputs itself and EMBEDS them in the dispatch prompt after
the fixed instructions: the `is_miss:true` lines from `.candidates-log.jsonl`,
their matching digest/v1 records from `.digest.jsonl` (join by `ref`), and
the current `entries.jsonl` content (empty if absent). The dispatched agent
needs no file access. The dispatch prompt is the verbatim content of
`references/sweep-l2-synth-prompt.md` (fixed instructions) followed by those
three embedded inputs — read that file and inline it.

Write the returned lines to `$TOUCHSTONE_LEDGER_DIR/.staging.jsonl`
(overwrite — current run's batch only). On dispatch error / timeout / no
usable output: append the EXACT line `sweep incomplete: l2` to
`.sweep-incomplete`, do not write `.staging.jsonl`, skip finalize, but still
run Step 5's `report` and paste its incomplete line into the close report.

### Step 5 — finalize and report

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh" finalize
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh" report
```

`finalize` appends `.staging.jsonl` through the ledger writer (dedupe applies
— an incident already recorded via a prior sweep or a label is a no-op) and,
only on success, advances the single `.last-sweep` timestamp to this run's
collect-start. On any finalize failure the staging file is discarded whole and
`.last-sweep` stays untouched.

Paste `report`'s output — sources consumed, any skipped/incomplete lines, and
the entries count + byte size — into the close report verbatim (step 5c above).
