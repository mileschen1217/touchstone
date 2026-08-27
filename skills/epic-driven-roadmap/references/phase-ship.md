# Phase-ship moment

One moment per phase PR: **pre-approve** — the Post-build pair.

## Pre-approve — Post-build pair (single home; close 5e cites this)

After the phase PR is pushed/opened and BEFORE the human approves it, you (the
shipping session) produce both; do not present the PR for approval until the
quiz has been taken and passed:

- [ ] **Buy-in explainer** — the phase's `## Phase map` (design-spec
      template, four panels), copied from the spec, each panel marked **as
      planned** or carrying its planned-vs-built delta taken from the
      deviation log; every build-time incident written under the panel it
      affected; then an **evidence status** part (which ACs are covered, by
      what, and any `[unverified]` rows). A phase with no design spec (PRD+seams light
      contract) → draft the four panels at ship time and label the map
      "drafted at ship, not at contract". Light phase (≲1 phase of work, no
      new contract) → a short text section in the PR conversation.
      Medium/heavy phase → a self-contained `.html` artifact (inline CSS/JS,
      no external requests) stored under `.touchstone/epics/<epic-dir>/`
      (dir = `YYYY-MM-DD-<slug>`, or the undated grandfathered name), file
      names per the renderer header's Ship pattern
      (`scripts/dossier-render.sh`).
- [ ] **Comprehension quiz** — questions the owner should be able to answer
      if they truly understand the change (what breaks if X, why was Y
      retired, where does Z live now), answers collapsed / after the
      questions. **The quiz is the explainer's acceptance test:** every
      question must be answerable closed-book from the explainer alone (if
      the owner must open the diff to answer, the explainer failed there);
      each question anchors to a specific map panel; drop test — if the
      owner's answer to this question could not change whether they approve,
      the question is out. The drop test takes precedence over the count:
      at most 8, no minimum.
      **Author the quiz FIRST, then the explainer:** for each
      question, the explainer must carry the answer as an explicit sentence a
      reader can point to — never as an implied clause the reader must infer
      (dense single-clause compression is the known failure form).
      Deliver it WITH the explainer and ask the owner to try it. A wrong
      answer marks exactly where the explainer failed — revise the explainer
      there, re-ask, AND record the miss as a use-point failure event: one
      `gate-miss.md` line in the canonical six-field primitive (its header
      states the fields) per wrong answer. **Quiz not passed → do not
      approve** (informed accept, never a rubber-stamp).
- [ ] **Regenerate the dossier** — run
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" .touchstone/epics/<epic-dir>`
      after the explainer and quiz files exist and before the pair is handed
      over; generated-view contract: the renderer's header.
- [ ] **Closing message carries the deliverables** — the message that hands the
      pair to the owner names the explainer's file path, the dossier path, AND,
      when one was published, the artifact link, in the message body itself.

Epic close cites each phase's pair (close step 2); it never re-runs the quiz.
