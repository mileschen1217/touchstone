# Scaffold a new epic

Requires a live, responsive user — step 0 pauses for an answer before
anything is written.

0. **Foundation elicitation.** Open with: "Please describe the intended work
   in your own words." Sharpen the answer into three fields through a short
   back-and-forth — never ask a design question (architecture, files, APIs,
   effort; deflect those with "that's a design decision for a later stage"):
   **Intention (why)** — the motivation; **Aim** — the one-sentence
   observable outcome (reject vague tokens like "better"/"elegant" — ask
   what the user would observe when the work is done); **Out of scope** —
   up to three routes this epic will NOT take, even if related. Present the
   draft under those three exact labels and ask "Please confirm or edit this
   foundation." Do not proceed until confirmed.
1. Pick a slug — lowercase, hyphen-separated, names the deliverable surface
   (e.g. `port-statistics-stacking`), not a phase number. The epic DIR is
   `YYYY-MM-DD-<slug>` (today's date prefix); the `slug:` field stays the
   pure slug — renderers key on the field, dir name is only a fallback.
   Pre-existing undated epic dirs are grandfathered (rename optional at close).
2. Read the project's CLAUDE.md § Doc Routing for the concrete
   epics path.
3. Copy `templates/epic.yaml` (beside this skill) to
   `<epics-dir>/YYYY-MM-DD-<slug>/epic.yaml` and fill: `slug`, `started`
   (today, YYYY-MM-DD), `status: proposed`, `aim`, `foundation`
   (intention + out-of-scope from step 0; an owner ruling sentence goes into
   `foundation.rulings` verbatim), and the phase-1 row. Validate:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" epic <path> --root <epic-dir>`
   — exit 0 before anything else happens.
4. Project the tracker:
   `bash "${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-render.sh" --root <project-root>`
   — ROADMAP.md is generated output; never hand-write or hand-edit a row.
5. New content docs for this epic (research, specs, plans, ADRs) get
   frontmatter `epics: [<slug>]` — see `templates/content-doc.md`.
6. Commit.
