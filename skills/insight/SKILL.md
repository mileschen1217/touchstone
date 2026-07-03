---
name: insight
description: The workflow-improvement loop — reads the gate-miss ledger's open entries (plus the epic data-point record as auxiliary signal), presents a ranked evidence-backed proposal digest, and on explicit human accept records the decision as facts and installs deterministic checks with a two-sided liveness proof.
allowed-tools: [Bash, Read, Write, Edit]
user-invocable: true
kind: workflow
---

# /touchstone:insight — workflow-improvement loop

**Elevated trust, declared:** this skill causes executable, exit-code-gating
checker scripts to be written into `.touchstone/checker/<stage>/` — content
that blocks future commits/pushes. `/touchstone:init`'s scaffold creates the
checker directories; this skill is the sole writer of check content (always
through `scripts/proposal/install.sh`, never by hand). Never install anything
without an explicit human accept of that specific proposal in this session.

Every deterministic step below is a script call under `scripts/proposal/`
(run from the repo root). Do not re-implement a step in prose, and do not
re-derive a script's result by judgment. Present `[unverified: …]` markers
as-is; they are the honest answer.

1. **Digest first.** Run `scripts/proposal/report.sh digest` and present its
   output as-is, including the freshness line. If it prints
   "no open entries — run the sweep first", say so and stop (the sweep runs
   at epic close, or ad-hoc via `scripts/ledger/sweep-run.sh`).
2. **Cluster + draft (the semantic step).** Read the open set:
   `scripts/proposal/report.sh open-entries`. Optionally read the epic's
   `data-points.md` as auxiliary signal. Cluster open entries into candidate
   mechanisms (a recurring class → one candidate). For each candidate, write
   its sidecar under `<ledger-dir>/proposals/<id>/`:
   - `proposal.md` — frontmatter `stage:` + `check_name:` (checker units
     only), then prose: mechanism, rationale, class description. No status
     field — status lives only in resolution facts.
   - `draft-check.sh` + `fire-fixture.sh` — MANDATORY for `unit_type=checker`
     (install refuses without them); `fire-fixture.sh` must create a
     self-contained scratch git repo in the failing state and print its
     toplevel.
   - `replay.sh` (optional) — prints `<sha> fire|pass` per commit. When it
     exists, run `scripts/proposal/replay-run.sh <sidecar-dir> <rev-range>`
     and embed the fires/hits result in the proposal's `cost_witness`;
     when it does not, use `cost_witness = {kind: "declared", note: …}`.
   Compose each proposal fact and append it via
   `scripts/proposal/facts-append.sh proposal` (the writer recomputes
   recurrence, latest_entry_ts, and auto-install eligibility).
3. **Present the ranked digest** (`scripts/proposal/report.sh digest`) —
   one screen — and ask the human to rule per proposal: accept / reject /
   defer.
4. **Record the ruling as facts, then act:**
   - **Accept:** append `kind=accepted` via
     `scripts/proposal/facts-append.sh resolution` FIRST; then, for a
     checker proposal, run `scripts/proposal/install.sh <proposal-id>` and
     present the resulting proof (or install-failed triage) fact verbatim.
   - **Reject:** append `kind=rejected`.
   - **Defer:** append nothing — the proposal stays pending.
   - Non-checker accepted units are carried out manually by the human;
     when done, append `kind=completed` with a note describing what was done.
5. **Revoke on request:** `scripts/proposal/install.sh --revoke <proposal-id>`
   removes the check and reopens its entries for future runs.
