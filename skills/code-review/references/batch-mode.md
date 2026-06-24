# Batch Mode (Pattern B) — Procedure

Vendor-not-builder review. Invoked when `/touchstone:code-review` is called with the `batch` keyword.

Provenance (schema, the 5 operations, both banner formats) is defined solely in
`skills/cross-provider-reviewer/references/provenance.md`.

## Steps

1. Resolve the commit range:
   - `/touchstone:code-review batch <range>` → use `<range>`
   - `/touchstone:code-review batch` → default `$(git merge-base HEAD main)..HEAD` (or `master`; project CLAUDE.md may override)
1b. Locate the governing spec deterministically (for the evidence-honesty criteria
   in Step 4). **Which epic is "in scope":** resolve it from `touchstone.yaml`
   `epics_dir` + the active epic (the epic whose branch/range is being reviewed), OR
   take it from the `epic` / `governing_specs` field the orchestrator passed in the
   reviewer envelope. If neither is resolvable from the diff context, take the skip
   path immediately. Otherwise read that epic index and enumerate its
   `status: Accepted` specs (paths under `specs_dir`). If there is no epic index in
   scope, or no Accepted spec, SKIP the evidence-honesty criteria and emit exactly
   one line — `no governing spec — coverage not audited` — never silently pass.
   Otherwise carry the Accepted spec path(s) into the reviewer envelope as
   `governing_specs`.
2. Detect builder (ALWAYS run — the E14 envelope needs `builder_vendor` even under
   `force_reviewer`; force waives only the reviewer swap in Step 3 and the
   vendor-correctness requirement, NOT builder detection):
   - Scan commit-message trailers in the range:
     ```
     git log --format=%B <range> | grep -iE '^Co-Authored-By:.*(codex|gpt-?5|openai)'
     ```
   - If any commit has a Codex-flavored `Co-Authored-By:` trailer → `builder = codex`
   - Otherwise → `builder = cc` (harness default — covers both Claude-tagged and untagged commits, since this skill runs inside Claude Code)
   - **Log the detection result so the user can spot misclassification:**
     - "Builder detection: N/M commits tagged Codex → builder = codex; reviewer swap = CC"
     - "Builder detection: no Codex trailers in M commits → builder = cc (default); reviewer swap = Codex"
   - Detection requires commit-message hygiene. If a Codex agent built code without tagging commits, the swap will misroute. Override with `batch with cc` in that case.
3. Determine reviewer:
   - If `force_reviewer = codex` → reviewer = `codex-reviewer`
   - If `force_reviewer = cc` → reviewer = `everything-claude-code:code-reviewer`
   - Else cross-vendor swap based on detected builder:
     - `builder = cc` → reviewer = `codex-reviewer`
     - `builder = codex` → reviewer = `everything-claude-code:code-reviewer`
4. Dispatch the resolved reviewer:
   - `codex-reviewer` → `Agent(subagent_type: "touchstone:codex-reviewer", description: "Codex batch review", prompt: { task: <full diff>, role: "batch-reviewer", task_dir: <optional> })`
   - `everything-claude-code:code-reviewer` → corresponding Agent dispatch  <!-- # EXTERNAL DEP — everything-claude-code (Epic B vendors this) -->

   When `governing_specs` is non-empty (from Step 1b), the reviewer applies the
   **evidence-honesty (coverage) criteria** (these fire ONLY here at `batch` /
   epic-close, where test source exists — never at design-review, never on
   arbitrary diffs). Build them in two parts:

   **(a) Shared spine doctrine — load-and-inject (unconditional).** Read
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/live-bearing-predicate.md` AND
   `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/ac-coverage-honesty-principle.md`
   — and inject them verbatim into the reviewer envelope: append to the reviewer's task
   prompt AND carry as `evidence_honesty_vocab`. This is Baseline/spine, not a
   discipline — inject regardless of which disciplines are adopted (do NOT gate it on
   `source-as-truth`).

   **(b) The `code-review batch` feedback delta** — prepend this, after the injected doctrine:

   > Read the governing spec's ACs and the test source. For each AC, judge whether a
   > test asserts that AC's Then-clause (AC coverage, semantic — not code-coverage %,
   > not tool-measured). A test that mocks the very boundary a boundary-crossing AC
   > claims does NOT discharge that claim (proxy, not coverage). A **silent false-green**
   > (per the injected principle — an AC done with neither an asserting test nor
   > `[unverified]`) blocks the done claim.
   >
   > **Live-bearing ACs (an extra demand, Phase 2).** For each AC listed in the
   > governing spec's `Live-bearing AC IDs`: the evidence is a **live artifact** —
   > captured output of actually exercising the behaviour against the real boundary.
   > A static proxy (grep / mock / env-faked condition / deployed-file read) does
   > NOT satisfy a live-bearing AC; if only a static proxy is offered, flag it (same
   > block semantics as silent false-green — it may not be claimed done). The
   > artifact must carry **provenance**: (1) which producer/invocation made it
   > (re-runnable command or identifiable session) and (2) freshness
   > (commit/timestamp tying it to current code). Authentication burden scales
   > with fakeability: a hand-pasteable perf log demands strong provenance
   > (re-runnable command + real-scale fixture reference + freshness); a real
   > `Agent()` transcript is largely self-attesting and demands less. You
   > authenticate the artifact — you do not re-run the producer
   > (**producer ≠ judge**: the artifact is produced by a script/session/build run,
   > never by you the reviewer; this is the existing builder ≠ reviewer discipline).
   > Do NOT
   > require cryptographic signing of artifacts (over-spec — a human is in the loop
   > at close).
5. Single reviewer; no parallel dispatch in Pattern B.
   **Normative fallback (M3):** if the swapped reviewer (e.g. `touchstone:codex-reviewer`)
   returns `status: failed` / a `fallback_reason` (codex unavailable), fall back to the
   builder's OWN vendor (`everything-claude-code:code-reviewer` when builder=cc) and let
   it produce the verdict. If BOTH the swap target and the builder-vendor fallback fail →
   `status: failed`, `providers_used == []`, no banner.
   **No pre-probe (L2):** do not add a `codex --version` pre-probe here — rely on the
   `touchstone:codex-reviewer` agent's own `status: failed` / `fallback_reason` as the
   codex-availability signal.
6. Write provenance + banners per `skills/cross-provider-reviewer/references/provenance.md`
   (sole canonical home — use the FULL plugin-relative path; a bare `references/provenance.md`
   would wrongly resolve under `skills/code-review/references/`, which does not exist).
   That reference holds every field/operation/banner definition; this body gives only actions:
   - Record `builder_vendor` = the detected builder from Step 2 (`"cc"`/`"codex"`). This is
     ALWAYS set, including under `force_reviewer` (Step 2 always runs detection).
   - Record `providers_used` (the vendor that actually reviewed) and `providers_expected`
     for THIS invocation per provenance.md.
   - Extract `session_id` from `raw_codex.jsonl` if codex ran, per that reference.
   - If degraded/partial, build and prepend the banner(s) to the verdict text and to
     `<task_dir>/review.md` (when `task_dir` given), per that reference.
   - Write `<task_dir>/review.result.json` (review-envelope/v1) per that reference.
7. Surface findings; Critical / High block merge.
8. **Informed-consent checkpoint (CONSENT-3):** if the verdict carries a ⚠️ DEGRADED or
   ⚠️ PARTIAL banner, present the banner to the user and obtain explicit acknowledgement
   (an `AskUserQuestion` choice or an explicit user "proceed") BEFORE reporting the batch
   as ready to proceed/commit. This is orthogonal to the C+H block — it applies even at
   C+H == 0. A clean (no-banner) review does NOT trigger this checkpoint.
