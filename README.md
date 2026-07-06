# touchstone

> A test of what is genuine. (試金石 — a stone used to test the authenticity of metal.)

A Claude Code plugin for **workflow discipline** — 10 stage skills + 6 agents, organised around the **honesty spine**: *claim ≤ evidence*. Gaps are marked, not hidden.

## What it is

Touchstone bundles a 6-stage workflow (Explore → Assay → Design-Spec → Plan → Build → Review Gate) with mechanisms that hold every stage to the honesty spine. The plugin's spine is **`claim ≤ evidence`** — every artifact (spec, plan, commit, review) carries the evidence its claims rest on; missing evidence is marked `[假設]`/`[unverified]`, never papered over.

The spine is carried *through* the plugin's surfaces, not enforced by a separate mechanism:

- **Skills** — drafting / authoring (`design-spec`, `assay`, `code-review`, ...)
- **`grounded-claims`** — narration discipline (cite source, mark assumptions)
- **`source-as-truth`** — project discipline (code is authoritative; docs describe why)
- **`intention-first`** — universal baseline (name intent before mechanism)

## Install

```bash
git clone https://github.com/mileschen1217/touchstone ~/projects/touchstone
claude plugin marketplace add ~/projects/touchstone
claude plugin install touchstone@touchstone --scope user
```

⚠️ Plugin dispatches agents and runs bash; use in trusted contexts only.

## Dependencies

Touchstone delegates work to agents and skills that live in other plugins. Install these before running touchstone skills.

**Required:**

```bash
# superpowers — writing-plans, using-git-worktrees, brainstorming, etc.
claude plugin install superpowers@claude-plugins-official --scope user
```

**Optional (cross-vendor review path):**

```bash
# codex — cross-vendor agents (codex:rescue, codex-* reviewers/implementers)
claude plugin install codex@openai-codex --scope user
```

The review/architecture agents (`architect`, `code-reviewer`) are vendored plugin-local since 0.18.0 — no external plugin is needed for any touchstone execution path. Without `codex`, only single-vendor (Claude-only) review paths work — touchstone degrades gracefully but loses the parallel CC+Codex composite. (The optional `everything-claude-code` plugin's language-testing skills remain a useful depth reference for the test-evidence lens, nothing more.)

## Skills

- `touchstone:init` — Bootstrap project adoption with `.claude/touchstone.yaml`.
- `touchstone:crucible` — Front-end contract orchestrator: explore → assay → design-spec, one human accept.
- `touchstone:anvil` — Back-end contract executor: plan → plan-review → SDD build → final cross-vendor review, stops before ship.
- `touchstone:insight` — Workflow-improvement loop: ledger digest → proposals → human ruling → checker install/retire.
- `touchstone:assay` — Pre-contract interview instrument: assumption laydown ⇄ tacit-intent extraction → readiness fork → guardrail contract block.
- `touchstone:design-spec` — Author spec: Problem → Scope → AC (GWT) → Architecture → Interfaces.
- `touchstone:design-review` — Gate spec/plan/ADR before Build (Pattern A).
- `touchstone:code-review` — Per-commit + per-batch code review (Patterns C / B).
- `touchstone:epic-driven-roadmap` — Pure-tracker ROADMAP + per-epic index convention.
- `touchstone:grounded-claims` — Narration mode: cite source, mark `[假設]`.
- `touchstone:cross-provider-architect` — Parallel CC + Codex architecture review.
- `touchstone:cross-provider-reviewer` — Parallel CC + Codex code review composite.

## Agents

- `touchstone:tdd` — Double-loop TDD agent (ATDD outer + unit-test inner).
- `touchstone:codex-implementer` — Cross-vendor task execution via Codex CLI.
- `touchstone:codex-reviewer` — Read-only Codex code review (Pattern B).
- `touchstone:codex-adversarial-reviewer` — Codex adversarial design critique.
- `touchstone:architect` — Read-only CC architecture validation (Pattern A arm).
- `touchstone:code-reviewer` — Read-only CC reviewer (Pattern A arm / Pattern B).

## 6-stage workflow

The full workflow lives in your global `~/.claude/CLAUDE.md` (touchstone integrates as routing). See `docs/comparisons.md` for scope and `CONTEXT.md` for vocabulary.

## Project-registered checks

Touchstone's `PreToolUse(Bash)` hook intercepts the agent's `git commit` and `git push` calls and runs your project's own deterministic checks before the command executes — no per-repo setup required.

### Convention

Add check scripts at `.touchstone/checker/<stage>/check-*.sh` (e.g. `pre-commit/check-adr-cite.sh`), where `<stage>` is `pre-commit` or `pre-push`. Scripts are:

- **Project-owned and committed** — the canonical `.gitignore` carve (written by `/touchstone:init`) excludes most of `.touchstone/` but includes `checker/`, so checks enter git normally.
- **Locus-agnostic** — a check does not know what invokes it. The same script works under the CC hook today and as a native `git commit` hook tomorrow, with zero changes.
- **Stage-keyed, not gate-keyed** — directories are named by stable git-hook stage (`pre-commit` / `pre-push`), not by touchstone gate name. Gate-name coupling is the silent-dead-check trap: a renamed gate makes a check silently never run.

Bootstrap with `/touchstone:init`, which creates the scaffold and applies the carve idempotently.

### Enforcement

The plugin registers a single `PreToolUse(Bash)` hook. It fires in **every repo the agent touches** — zero per-repo install. When the agent runs a covered command:

1. The hook classifies the command (`git commit` → `pre-commit`; `git push` → `pre-push`).
2. It resolves the repo root from the command's effective working directory (honouring `git -C <path>`).
3. It runs every `check-*.sh` under `.touchstone/checker/<stage>/` in that repo.
4. Any check that exits non-zero **blocks the command** (hook exits 2); clean checks are transparent.

### Honest ceiling

The CC hook catches **only agent commits/pushes made via the Bash tool**. A human committing manually in their own terminal is not intercepted — this is acceptable for an agent-driven workflow. Universal coverage (catching human commits too) is a future option: install the same locus-agnostic check scripts as native `git` hooks; no check changes required.

Command classification is best-effort regex on the command string. **KNOWN-LIMITATION forms that classify as `none` (not checked):**

- `cd <path> && git commit …` — the pre-command `cd` prefix prevents reliable repo-root resolution.
- `git cherry-pick`, `git revert`, `git merge` — excluded by design (not standard commit/push forms).

An unrecognised commit variant silently skips its checks, so the covered command forms are enumerated in the hook and a meta-check guards the classifier itself. See [ADR-0029](docs/adr/0029-repo-local-git-hooks-not-shipped.md) for the full decision and alternatives considered.

## OTel setup (for CC-subagent figures)

`scripts/metrics/phase-record.sh` attributes CC-subagent token/cost per agent, but only when an OpenTelemetry collector funnels Claude Code telemetry into a local JSONL sink. Without it, CC-subagent cells are `[unverified]` (Codex figures do not need it — they come from `~/.codex/sessions`).

**One-shot setup.** This installs/locates `otelcol-contrib`, writes the collector config (the **logs** pipeline the reader consumes), loads a persistent collector service (**macOS** launchd / **Linux** systemd `--user`), and appends the telemetry env vars — including `TOUCHSTONE_OTEL_EXPORT` — to the profile your login shell sources (`~/.zshrc`, `~/.bashrc`, or `~/.profile`). Idempotent; re-running is safe:

```bash
scripts/metrics/setup-otel.sh
```

Then open a new shell (so the env vars load) and run your touchstone gates. If `otelcol-contrib` isn't already present it is downloaded from the official GitHub releases for your OS/arch (there is no Homebrew formula — the `file` exporter is contrib-only). Overrides: `OTELCOL_BIN` (use an existing binary), `SETUP_SKIP_AGENT=1` (don't load launchd — Linux/CI, or run the collector yourself), `PROFILE_FILE`, `OTEL_HTTP_PORT`.

### Read the report

Run-manifests are stamped automatically by a plugin hook on every **design-spec / design-review /
anvil** invocation (to `${TOUCHSTONE_METRICS_DIR:-$HOME/.touchstone-metrics}/runs`) — no setup, no mode
toggle. The hook catches both invoke paths: `UserPromptSubmit` when you type the gate command, and
`PreToolUse`/`Skill` when a composite (e.g. crucible) auto-invokes design-spec / design-review
internally. Codex cost is harvested from `~/.codex/sessions` rollouts. Reading is split into a
deterministic step and a semantic step (see `skills/epic-driven-roadmap/references/phase-ship.md`):

```bash
# deterministic — appends the phase's cost/time/token row to the epic's
# data-points.md; also bounds the last still-open run at record time
scripts/metrics/phase-record.sh <epic-slug> <phase-label>

# or read the numbers directly without recording a row
# (TOUCHSTONE_OTEL_EXPORT is set by setup-otel.sh)
scripts/metrics-report.sh --session-id <session-uuid> \
  ${TOUCHSTONE_OTEL_EXPORT:+--otel "$TOUCHSTONE_OTEL_EXPORT"} \
  [--session ~/.claude/projects/<slug>/<session-uuid>.jsonl]   # optional: adds main-loop + session-wallclock summary
```

`/touchstone:insight` is a separate, semantic step — the workflow-improvement loop that turns the
gate-miss ledger's open entries into a ranked, evidence-backed proposal digest for human accept. It
does not read or report the metrics numbers above; run it alongside `phase-record.sh` at the
phase-ship moment (see `skills/epic-driven-roadmap/references/phase-ship.md`).

`--session-id` must match your otelcol export's `session.id` attribute. The reader auto-detects the
nested OTLP shape (`resourceLogs[].scopeLogs[].logRecords[]`) and normalizes it; CC-subagent cost
comes from OTel, Codex cost from `~/.codex/sessions`, and any cell that can't be grounded prints a
`[unverified: <reason>]` marker rather than a fabricated number.

> **Scope limit — read before trusting the Codex numbers.** Codex cost is attributed by working
> directory + time window, so it is reliable only when **at most one active session runs per literal
> cwd at a time**. Separate git worktrees have distinct cwds and are fine; two concurrent sessions in
> the *same directory path* are out of scope and their Codex costs may cross-attribute. CC-subagent
> figures (OTel, keyed by `session.id`) are unaffected.
>
> **Accuracy limit — a stamp is a gate *invocation*, not a guaranteed completion.** When you TYPE a
> leading `/anvil` (or `/design-spec` / `/design-review`), it is stamped at submit time; if you then
> abandon or retry the run, that window is spurious or misattributed. The match is anchored to a
> leading slash command, so discussing a gate in prose never stamps — only running the command does.
> Gates auto-invoked by a composite (crucible → design-spec / design-review) are stamped via the Skill
> tool and are completion-faithful. Filtering abandoned windows is left to the reader.

## Status

`0.15.0` (see `.claude-plugin/plugin.json` for the current version). Experimental. Used by the author on one project. Cross-project portability is unverified — see `docs/comparisons.md` for scope boundaries.

## License

MIT (LICENSE file not yet committed).
