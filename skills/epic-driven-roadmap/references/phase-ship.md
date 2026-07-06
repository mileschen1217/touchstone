# Phase-ship moment

Two moments per phase PR: **pre-approve** (the Post-build pair) and
**post-merge** (the two recording lines).

## Pre-approve — Post-build pair (single home; close 5e cites this)

After the phase PR is pushed/opened and BEFORE the human approves it, you (the
shipping session) produce both; do not present the PR for approval until the
quiz has been taken and passed:

- [ ] **Buy-in explainer** — what changed, why, and what the reader can now do
      differently, written for the human owner (not a diff summary). Light
      phase (≲1 phase of work, no new contract) → a short text section in the
      PR conversation. Medium/heavy phase → a self-contained `.html` artifact
      (inline CSS/JS, no external requests) stored under
      `.touchstone/epics/<slug>/`.
- [ ] **Comprehension quiz** — 5–8 questions the owner should be able to
      answer if they truly understand the change (what breaks if X, why was Y
      retired, where does Z live now), answers collapsed / after the
      questions. **The quiz is the explainer's acceptance test:** every
      question must be answerable closed-book from the explainer alone (if
      the owner must open the diff to answer, the explainer failed there);
      each question anchors to a specific explainer section; cover only the
      rulings and invariants that would change the approve decision — never
      trivia. Deliver it WITH the explainer and ask the owner to try it. A
      wrong answer marks exactly where the explainer failed — revise the
      explainer there and re-ask. **Quiz not passed → do not approve**
      (informed accept, never a rubber-stamp).

Epic close cites each phase's pair (close step 5e); it never re-runs the quiz.

## Post-merge — record

Run these two lines (cwd = the target repo root) at the moment the phase's
deliverable ships (PR merged / release tagged):

- [ ] **Deterministic:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/metrics/phase-record.sh" <epic-slug> <phase-label>`
      — appends the phase's gate-run metrics and the current open-entry count
      to `.touchstone/epics/<slug>/data-points.md` (cells honestly
      `[unverified: …]` when OTel is absent; never hand-copy the numbers).
      Running it also bounds the last still-open gate-run window.
- [ ] **Semantic:** invoke `/touchstone:insight` — ranked proposal digest over
      the full open-entry set; every ruling is recorded as a fact.
