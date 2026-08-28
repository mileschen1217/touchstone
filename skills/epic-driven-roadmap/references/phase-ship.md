# Phase-ship moment

One moment per phase PR: **pre-approve** — the Post-build pair. There is no
explainer file: the dossier's Ship tab is the explainer, and the PR body is its
text projection.

## Pre-approve — Post-build pair (single home; close step 2 cites this)

After the phase's branch is pushed and BEFORE the human approves the PR, you (the
shipping session) do the following in order:

- [ ] **Validate the phase's artifacts** — `check-artifact.sh spec` on the spec,
      `review` on every review.yaml, `deviation` on `deviation.yaml` (all exit 0):
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" <kind> <file> --root <epic-dir>`.
- [ ] **Project** — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" <epic-dir>`
      then `… --pr-body <epic-dir>` (writes `<epic-dir>/pr-body.md`, the Ship tab
      in text; `gh pr create --body-file` it). A sentence you want to add to the Ship
      tab is a missing field — add it upstream and re-project.
- [ ] **Comprehension quiz** — authored AFTER the projection exists, as
      `quiz.items[]` in `deviation.yaml`: questions the owner should be able to
      answer from the Ship tab alone (what breaks if X, why was Y retired, where does
      Z live now). Every `answer` names the field id it resolves to and `anchor`
      carries that field path — an answer with no resolvable field is a missing
      source field: fix upstream, re-project, re-author. Each question anchors to a
      D-n entry or one panel; drop test — if the owner's answer could not change
      whether they approve, the question is out; at most 8, no minimum. Zero D-n
      entries → `quiz.waived: true` (the Ship tab states the waiver visibly).
      Re-validate `deviation.yaml`, re-project, hand the pair to the owner and ask
      them to try it. A wrong answer → `result: miss` on that item, one
      `gate-miss.md` line in the canonical six-field primitive (its header states the
      fields), and the source field it exposed fixed upstream; re-project, re-ask.
      **Quiz not passed → do not approve.**
- [ ] **Closing message carries the deliverables** — the message that hands the
      pair to the owner names the dossier path, the PR body path, AND, when one was
      published, the artifact link, in the message body itself.

