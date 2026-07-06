---
name: insight
description: The workflow-improvement loop — reads the gate-miss ledger's open entries (plus the epic data-point record as auxiliary signal), presents a ranked evidence-backed proposal digest, and on explicit human accept records the decision as facts and installs deterministic checks through the minimal install rail (copy + one installed fact; liveness is read post-hoc from the raw fire-log).
allowed-tools: [Bash, Read, Write, Edit]
user-invocable: true
kind: workflow
---

# /touchstone:insight — workflow-improvement loop

**Elevated trust, declared:** this skill causes executable, exit-code-gating
checker scripts to be written into `.touchstone/checker/<stage>/` — content
that blocks future commits/pushes. `/touchstone:init`'s scaffold creates the
checker directories; this skill is the sole writer of check content (always
through `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/install.sh"`, never by hand). Never install anything
without an explicit human accept of that specific proposal in this session.

Every deterministic step of this loop is a script call under `scripts/proposal/`
(run with the TARGET repo as cwd — the scripts resolve the ledger from the
current repo; the ad-hoc sweep pointer in step 1 is the ledger
family's own script). Do not re-implement a step in prose, and do not
re-derive a script's result by judgment. Present `[unverified: …]` markers
as-is; they are the honest answer.

1. **Digest first.** Run `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/report.sh" digest` and present its
   output as-is, including the freshness line. If it prints
   "no open entries — run the sweep first", say so and stop (the sweep runs
   at epic close, or ad-hoc via `"${CLAUDE_PLUGIN_ROOT}/scripts/ledger/sweep-run.sh"`).
2. **Cluster + draft (the semantic step).** Read the open set:
   `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/report.sh" open-entries`. Optionally read the epic's
   `data-points.md` as auxiliary signal. Cluster open entries into candidate
   mechanisms (a recurring class → one candidate), then screen every candidate
   through the four admission rules — a candidate that fails one is not drafted
   (record the ruling as a `kind=rejected` fact whose note names which rule and
   where the class was routed instead):
   - **A1 Feedforward-first.** Ask: would earlier discovery work (exploring the
     repo/context before designing, sharpening the contract's assumptions) have
     dissolved this miss class at its source? If yes, route the class to
     strengthening that upstream instrument — do not add a downstream check for
     it. The rejected fact's note names the upstream destination.
   - **A2 Merge-or-replace.** Name the existing unit (checker, lens, skill rule)
     whose class overlaps this candidate — write it into the sidecar's
     `overlap:` frontmatter field. Merge into it or replace it; a net-new unit
     must argue that no existing home fits. Screening is judgment + the human's
     ruling — no script arbitrates overlap.
   - **A3 Size.** Absolute layer: the unit carries no filler — size is what the
     procedure needs (guideline ≤200 lines / ≈2.5k tokens for a skill body;
     hard cap 500 lines). Ratchet layer: the review-prompt surface's total
     token count never grows net — an addition over the cap is paid for by an
     equal deletion. The size guideline covers lazy-loaded `references/*.md`
     too — a size audit that reads only SKILL.md bodies is incomplete; the
     token ratchet stays scoped to the review-prompt surface.
   - **A4 Deterministic checks sink to checkers.** Any fully deterministic
     check (grep-able, exit-code-able) ships as a checker script, never as an
     LLM lens sentence; a lens containing a deterministic sub-check has that
     sub-check carved out into a script.
   **Screen each surviving candidate against what already exists** before
   drafting: list `.touchstone/checker/*/` and the repo's registered
   lints/tests — a class whose mechanism already shipped is not a candidate
   (its open entries predate the mechanism; close them with a `kind=rejected`
   fact naming the existing mechanism instead).
   For each surviving candidate, write its sidecar under
   `<ledger-dir>/proposals/<id>/`:
   - `proposal.md` — frontmatter `stage:` + `check_name:` (checker units
     only), then prose: mechanism, rationale, class description. No status
     field — status lives only in resolution facts.
   - `draft-check.sh` — MANDATORY for `unit_type=checker` (install refuses
     without it).
   - Set `cost_witness = {kind: "declared", note: …}` — one line naming the
     expected cost of keeping this unit (maintenance, false-block risk).
   Compose each proposal fact and append it via
   `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/facts-append.sh" proposal` (the writer recomputes
   recurrence, latest_entry_ts, and auto-install eligibility).
3. **Present the ranked digest** (`"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/report.sh" digest`) —
   one screen — and ask the human to rule per proposal: accept / reject /
   defer.
4. **Record the ruling as facts, then act:**
   - **Accept:** append `kind=accepted` via
     `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/facts-append.sh" resolution` FIRST; then, for a
     checker proposal, run `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/install.sh" <proposal-id>` and
     present the resulting installed fact verbatim.
   - **Reject:** append `kind=rejected`.
   - **Defer:** append nothing — the proposal stays pending.
   - Non-checker accepted units are carried out manually by the human;
     when done, append `kind=completed` with a note describing what was done.
5. **Retirement pass (run after the proposal rulings, same session).** Read
   `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/reconcile.sh"` output — each installed check's line
   carries `fires=<n> … commits=<m>` (raw fires since first install; the
   commit count is the denominator — judge rate, never raw fires). Table a
   unit for the human when
   `fires=0` across ≥2 epics AND ≥100 commits — the threshold only puts it on
   the table; the retirement judgment is **cost-to-keep**: maintenance debt,
   false-block history, cognitive surface. A zero-fire unit has three
   identities: *insurance* (cheap, guards a catastrophic class — keep),
   *habit-corrector* (the habit may be cured — human judges cured vs
   path-dead), *idle* (guards a path that no longer exists — the one true
   retirement case). Any unit WITH fires stays (each fire = a prevented
   incident). LLM lenses have no fire-log: judge them by whether a
   feedforward instrument now covers their class, and only retire on an
   observed drop in that class's miss rate — never on prediction. Retire via
   `"${CLAUDE_PLUGIN_ROOT}/scripts/proposal/install.sh" --revoke <proposal-id>` (also available
   on direct request any time); revoke removes the check and reopens its
   entries for future runs.
