# Phase-ship moment

One moment per phase PR: **pre-approve** — the Post-build pair, whose yes is the
**ship informed-accept**, the second of a unit of work's two human accepts (the first
is crucible's contract accept). The PR approve is that yes acted on, not a further
ruling. There is no explainer file: the dossier's 首頁 (decision line → gate strip →
blocker checklist → how-verified → structure → do-confirm checklist) is the explainer,
and the PR body is its text projection. Anvil's terminal hand-off (branch, review
verdict, unverified list) is this moment's input: the unverified list is what the 首頁's
blocker checklist shows, and an unverified live-bearing AC on it blocks the informed
accept until its live artifact exists or the AC is deferred to a later phase.

## Pre-approve — Post-build pair (single home; close step 2 cites this)

After the phase's branch is pushed and BEFORE the human approves the PR, you (the
shipping session) do the following in order:

- [ ] **Metrics entry (plugin repo only — the root carries `.claude-plugin/plugin.json`).**
      Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/phase-metrics.sh" <epic-dir> <this phase's
      session transcript(s)> --phase N --range <base>..<ship sha> --churn <shape_driven>,<other>`
      and append the printed entry to `deviation.yaml.metrics` (a list, one entry per
      phase). The script's only manual input is `--churn`: classify
      `git diff --stat <base>..HEAD -- .touchstone/checker scripts/plugin-map.sh` per hunk —
      shape_driven = a hunk that writes or reads a field a schema of this phase changed, a
      ratchet key/unit hunk, a removed waiver; everything else = other. A consumer project
      writes no metrics entry.
- [ ] **Comprehension quiz** — authored AFTER the structure and metrics exist, into
      the epic's `quiz.yaml`, **question-first**: `items[]` before `phase_summaries[]` —
      each question is an acceptance criterion the summary is then written against.
      Questions the owner can answer from the dossier's 首頁 and 結構變化 alone (what
      breaks if X, why was Y retired, where does Z live now); each anchors to a D-n
      entry or one panel; drop test — an answer that could not change approval is out;
      at most 8, no minimum. Item shape: `question`, the owner's prose `answer` (absent
      until answered), `refs` (spec ids; the checker verifies existence, nothing more),
      `anchor` (field path), `result: pass|miss` — your judgment, required once
      answered. **Owner's frame, not the builder's:** what changed, why, what breaks —
      internal accounting (a predicate's implementation, a review round's mechanics, an
      id scheme) fails the drop test even when true; ids stay in `refs`/`anchor`, never
      in question text. Then `phase_summaries[]`, one entry per shipped phase, written
      against the questions: 3–5 points, one per line, each point = why it was done →
      what changed → what the owner skips re-deriving, in 1–2 plain sentences with no
      build internals; every question's answer must be an identifiable sentence in the
      summary or a panel — one without such a sentence is a missing source field: fix
      upstream, re-project, re-author.
      Zero D-n entries → `quiz.waived: true` (the page states the waiver visibly).
- [ ] **Form check on the pair** — before handing over, read the 首頁 and every quiz
      question as the owner will: (1) a code (an id, a coined term) used before it is
      defined on that page; (2) a judgment (a priority, a check choice, a non-goal) with
      no basis beside it; (3) a question whose answer sentence you cannot point to on
      the page. Any is a miss handled exactly like a quiz miss below — one
      `gate-miss.md` line, the source field fixed upstream, re-project, then hand over.
- [ ] **Validate the phase's artifacts** — `check-artifact.sh spec` on the spec,
      `review` on every review.yaml, `deviation` on `deviation.yaml`, `quiz` on
      `quiz.yaml` (all exit 0):
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" <kind> <file> --root <epic-dir>`.
- [ ] **Project** — the shipped hook re-rendered `dossier.html` at every artifact
      write; run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" <epic-dir>`
      yourself only when the hook did not fire. Optional structure overlay first:
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/archify-project.sh" <spec.yaml> <epic-dir>/archify`
      (exit 3 = archify absent; the tab keeps its delta tables). Then
      `… --pr-body <epic-dir>` (writes `<epic-dir>/pr-body.md`, the 首頁 in text;
      `gh pr create --body-file` it). A sentence you want to add to the page is a
      missing field — add it upstream and re-project.
- [ ] **Hand the pair to the owner** and ask them to try the quiz; write each answer
      into its item and judge it `result: pass|miss`. A miss → one `gate-miss.md` line in
      the canonical six-field primitive (its header states the fields) and the source
      field it exposed fixed upstream; re-validate, re-project, re-ask.
      **Quiz not passed → no informed accept, no approve.**
- [ ] **Closing message carries the deliverables** — the message that hands the
      pair to the owner names the dossier path, the PR body path, AND, when one was
      published, the artifact link, in the message body itself.
