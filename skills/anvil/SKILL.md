---
name: anvil
description: >-
  Use when an accepted contract (spec.yaml with status accepted) needs to be
  built; stops before ship and hands off to phase-ship. Out of scope — a spec
  not yet at status accepted.
allowed-tools: [Bash, Read, Skill, Agent, Edit, Write]
user-invocable: true
kind: workflow
---

# /touchstone:anvil — Back-End Contract Executor

Apply `../.shared/harness-runtime.md` before any host-dependent operation.

Invocation: `/touchstone:anvil <spec-path>`. Run in a fresh session. The build's `done` is `build/verdict.yaml`: a ruler a non-builder wrote from the spec, frozen before the first edit, re-run by `ruler.py held-out` outside this session's tree — never this session's own green.

## Stage 1 — entry check

The spec's `status` is `accepted`, and:

```bash
bash "<plugin-root>/scripts/design-review-precheck.sh" "$spec" --attest
```

Non-zero exit → surface the output verbatim and halt. Zero → `mkdir -p <epic-dir>/build` (`<epic-dir>` = the spec's directory, `<root>` = the repo root) and proceed.

## Stage 2 — build on one path

ruler-author → `ruler.py check` → `red-first` → `freeze` → session build → `held-out` → deliverable-review. No other path, no fallback, and nothing between the ruler and the freeze asks a human or a model for a judgment — `ruler.py freeze` writes from the red-first log alone.

Artifacts, all under `<epic-dir>/build/` (`B`): `ruler.yaml` + `ruler/` — the AC → test index and its test files (schema `${CLAUDE_PLUGIN_ROOT}/skills/.shared/schemas/ruler.schema.yaml`); `freeze.json` — the sha of every ruler file, written once by `ruler.py freeze`; `disputes.yaml` — the builder's entries against a frozen test; `verdict.yaml` — per-AC PASS / FAIL / DISPUTED / UNVERIFIED written by `ruler.py held-out` (schema `verdict.schema.yaml`, same directory), the artifact the ship accept reads. `R="${CLAUDE_PLUGIN_ROOT}/scripts/ruler.py"`, `S=<scratchpad>`.

Dispatches during a build are exactly ruler-author (2.1) and Stage 3's review arms; each takes its model from the agent definition's `model:` line, never from this session (the plugin-graph checker enforces the pin). You consume a dispatch's files, never its report text. Any other `Agent()` is a `D-n` entry.

### 2.1 ruler-author

Snapshot before and after the dispatch, to the scratchpad: `git -C <root> status --porcelain --untracked-files=all --ignored` plus the sha256 of every dirty or untracked path it lists.

```
Agent(subagent_type: "touchstone:ruler-author", description: "ruler-author", prompt: "
spec_file: <spec-path>
ruler_file: <epic-dir>/build/ruler.yaml
ruler_dir: <epic-dir>/build/ruler
repo_root: <root>
ruler_py: <the path check commands name — scripts/ruler.py in this plugin's own repo, else $R>
schema_file: ${CLAUDE_PLUGIN_ROOT}/skills/.shared/schemas/ruler.schema.yaml
pre_build_commit: <git -C <root> rev-parse HEAD>
pre_build_tree: $S/pre-build   # git -C <root> worktree add --detach "$S/pre-build" <pre_build_commit>, made before this dispatch
")
```

Append `rulings: <epic-dir>/deviation.yaml` whenever that file's `waiting_on_human` carries a resolved `test-wrong` ruling — the author rewrites only the nodes of the ACs it names.

- [ ] Author scope: diff the two snapshots — every path that appeared, vanished, changed status or changed sha is `B/ruler.yaml` or lies under `B/ruler/`; any other path → `rm -rf B/ruler B/ruler.yaml`, a `D-n` naming the path, re-dispatch once; a second violation → halt naming the path.
- [ ] `B/ruler.yaml` exists and `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" ruler B/ruler.yaml` exits 0; absent or failing → re-dispatch once with the check output appended to the prompt; absent or failing again → halt naming the file, no third dispatch.

### 2.2 `ruler.py check` → `red-first` → `freeze`

```bash
python3 "$R" check     --ruler "$B/ruler.yaml" --spec <spec-path> --root <root>
python3 "$R" red-first --ruler "$B/ruler.yaml" --tree "$S/pre-build" --root <root>   # the worktree 2.1 made
python3 "$R" freeze    --ruler "$B/ruler.yaml" --root <root>
```

- [ ] Every command exits 0 and `B/freeze.json` exists. A refusal names a ruled node that passes on the pre-build tree, a node missing from the trace, a check command not in the runner form, or a ruler file changed since red-first — a defect of the ruler: `rm -f B/red-first.json`, re-dispatch 2.1 once with the refusal appended (the author revises its own files; snapshot again), then re-run this step; a second refusal → halt with it. Never a hand edit of a ruler file, never a change to the tooling.
- [ ] An AC with a non-empty `ambiguity[]` → append a `W-n` (`kind: ruling`) to the spec's `waiting_on_human` naming the AC and both readings, and a `blocked` `D-n` naming it; the build continues on every other AC and held-out carries it UNVERIFIED with the ruler's reason.

### 2.3 session build

`test -f "$B/freeze.json"` immediately before the first edit under `touch_set.touched`; missing → halt naming it — never re-run `freeze` or `red-first` to replace it (`ruler.py freeze` refuses a second freeze of the same build). Then build every AC yourself: an item you cannot finish is `blocked` with its reason and you move to the next; a gap against the spec is a `D-n` in the epic's `deviation.yaml` (field set: `${CLAUDE_PLUGIN_ROOT}/skills/.shared/schemas/deviation.schema.yaml`) the moment you find it, never a note in the run report.

A ruler file is never edited after freeze: `hooks/guard-ruler.sh` blocks Edit and Write on `B/freeze.json`, every file it lists and everything under `B/ruler/`, and `held-out`'s sha check turns any other route into a FAIL naming the file. A test you believe wrong is one entry appended to `B/disputes.yaml` — `ac`, `test`, `asserts` (what the test checks), `spec_says` (the AC text you read), `conflict` (why both cannot hold) — the test stays as it is, still runs held-out, and its verdict row is DISPUTED with the test and your reason side by side for the owner's ruling at phase-ship. No ruler-author dispatch happens between freeze and held-out. Run `python3 "$R" run --ruler "$B/ruler.yaml" <node>` as often as you like — a report, never the verdict. Your own tests live outside `B/ruler/` and never enter the ruler, the freeze or the verdict. Commit the build before 2.4.

Self-build only (the spec's `touch_set` names this plugin's own skills): each live-bearing AC about anvil's behaviour is exercised through `bash "${CLAUDE_PLUGIN_ROOT}/scripts/tests-smoke/probe-anvil.sh" run … --plugin-dir <root>` after the shipped surface is committed, evidence under `B/probes/<AC>/` in the four-file shape the ruler-author definition names.

### 2.4 `held-out`

```bash
python3 "$R" held-out --ruler "$B/ruler.yaml" --freeze "$B/freeze.json" --out "$B/verdict.yaml" --root <root> --scratch "$S"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-artifact.sh" verdict "$B/verdict.yaml"
```

- [ ] `B/verdict.yaml` exists. A FAIL row is a build item: fix, commit, re-run 2.4. A DISPUTED or UNVERIFIED row survives untouched to phase-ship — no stage promotes it.

## Stage 3 — deliverable-review

Invoke `Skill(skill: "touchstone:deliverable-review")` on the branch range with the spec as the governing spec. Convergence belongs to the stopping rule that gate injects (`severity-tiered-stopping-rule.md` under `${CLAUDE_PLUGIN_ROOT}/skills/.shared/inject/`): read its outcome, never re-run the gate past its budget. An `unverified` review row survives intact, like an UNVERIFIED verdict row.

## Terminal — reviewed deliverable, handed to phase-ship

Hand the branch, `review.yaml`, `B/verdict.yaml` and the ruler index `B/ruler.yaml` to phase-ship (`epic-driven-roadmap` `references/phase-ship.md`) — the human reads tests and verdicts there, not code; FAIL, DISPUTED and UNVERIFIED live-bearing rows block that accept until ruled or deferred. The second of a unit of work's two human accepts happens there; anvil asks for none. The hand-off message carries the build report: builder-session USD (transcript usage), each dispatch's USD (the OTel export's cost rows by agent), and verification-side ÷ builder as the ratio — above 1.0 is a `D-n` with its cause; a dispatch with no cost row or a zero builder denominator makes the ratio UNVERIFIED with that reason instead of a number. **Anvil stops before ship** — never push, open a PR, merge, or release, on any path including halts.
