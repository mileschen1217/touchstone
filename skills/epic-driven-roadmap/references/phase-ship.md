# Phase-ship moment

One moment per phase PR: **pre-approve** — the Post-build pair. There is no
explainer file: the dossier's 首頁 (decision line → gate strip → blocker checklist →
how-verified → structure → do-confirm checklist) is the explainer, and the PR body
is its text projection.

## Pre-approve — Post-build pair (single home; close step 2 cites this)

After the phase's branch is pushed and BEFORE the human approves the PR, you (the
shipping session) do the following in order:

- [ ] **Metrics line (plugin repo only — the root carries `.claude-plugin/plugin.json`).**
      Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/plugin-map.sh"` and write
      `deviation.yaml.metrics` = `{phase, stage1_tokens, false_edges, instrument_churn:
      {shape_driven_lines, other_lines}, measured_at: <ship sha>}` — `stage1_tokens` =
      the stage-1 unique context-loaded bytes ÷ 4 (the ratchet's unit),
      `false_edges` = the map's count, `instrument_churn` from
      `git diff --stat <base>..HEAD -- .touchstone/checker scripts/plugin-map.sh`
      classified per hunk: shape_driven = a hunk that writes or reads a field a schema
      of this phase changed, a ratchet key/unit hunk, a removed waiver; everything
      else = other. A consumer project writes no metrics block.
- [ ] **Comprehension quiz** — authored AFTER the structure and metrics exist, as
      `quiz.items[]` in `deviation.yaml`: questions the owner should be able to
      answer from the dossier's 首頁 and 結構變化 alone (what breaks if X, why was Y
      retired, where does Z live now). Every item carries `phase` and `kind`:
      - `kind: ref-set` — you write `expected_refs` (the AC/REQ/INV ids the right
        answer names); the owner answers with `answer_refs`; `check-artifact.sh`
        grades it (set equality; missing/extra ids listed) — never you.
      - `kind: manual` — `answer` names the field id it resolves to and `anchor`
        carries that field path; the owner's answer is judged by you as
        `result: pass|miss`.
      An answer with no resolvable field is a missing source field: fix upstream,
      re-project, re-author. Each question anchors to a D-n entry or one panel; drop
      test — if the owner's answer could not change whether they approve, the
      question is out; at most 8, no minimum. Zero D-n entries → `quiz.waived: true`
      (the page states the waiver visibly).
- [ ] **Validate the phase's artifacts** — `check-artifact.sh spec` on the spec,
      `review` on every review.yaml, `deviation` on `deviation.yaml` (all exit 0; the
      deviation run prints each ref-set item's grade):
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" <kind> <file> --root <epic-dir>`.
- [ ] **Project** — the shipped hook re-rendered `dossier.html` at every artifact
      write; run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dossier-render.sh" <epic-dir>`
      yourself only when the hook did not fire. Optional structure overlay first:
      `bash "${CLAUDE_PLUGIN_ROOT}/scripts/archify-project.sh" <spec.yaml> <epic-dir>/archify`
      (exit 3 = archify absent; the tab keeps its delta tables). Then
      `… --pr-body <epic-dir>` (writes `<epic-dir>/pr-body.md`, the 首頁 in text;
      `gh pr create --body-file` it). A sentence you want to add to the page is a
      missing field — add it upstream and re-project.
- [ ] **Hand the pair to the owner** and ask them to try the quiz. A miss (a
      ref-set grade `miss`, or a manual `result: miss`) → one `gate-miss.md` line in
      the canonical six-field primitive (its header states the fields) and the source
      field it exposed fixed upstream; re-validate, re-project, re-ask.
      **Quiz not passed → do not approve.**
- [ ] **Closing message carries the deliverables** — the message that hands the
      pair to the owner names the dossier path, the PR body path, AND, when one was
      published, the artifact link, in the message body itself.
