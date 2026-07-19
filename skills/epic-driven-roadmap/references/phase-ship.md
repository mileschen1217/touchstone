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
      `.touchstone/epics/<epic-dir>/` (dir = `YYYY-MM-DD-<slug>`, or the undated grandfathered name).
- [ ] **Comprehension quiz** — 5–8 questions the owner should be able to
      answer if they truly understand the change (what breaks if X, why was Y
      retired, where does Z live now), answers collapsed / after the
      questions. **The quiz is the explainer's acceptance test:** every
      question must be answerable closed-book from the explainer alone (if
      the owner must open the diff to answer, the explainer failed there);
      each question anchors to a specific explainer section; cover only the
      rulings and invariants that would change the approve decision — never
      trivia. **Author the quiz FIRST, then the explainer:** for each
      question, the explainer must carry the answer as an explicit sentence a
      reader can point to — never as an implied clause the reader must infer
      (dense single-clause compression is the known failure form).
      Deliver it WITH the explainer and ask the owner to try it. A wrong
      answer marks exactly where the explainer failed — revise the explainer
      there, re-ask, AND record the miss as a use-point failure event: one
      `gate-miss.md` line in the canonical six-field primitive (its header
      states the fields) per wrong answer. **Quiz not passed → do not
      approve** (informed accept, never a rubber-stamp).

Epic close cites each phase's pair (close step 2); it never re-runs the quiz.

## Post-merge — record

At the moment the phase's deliverable ships (PR merged / release tagged),
cwd = the target repo root, run:

