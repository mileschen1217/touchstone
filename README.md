# touchstone

> A test of what is genuine. (試金石 — a stone used to test the authenticity of metal.)

A Claude Code plugin for **workflow discipline** — 10 stage skills + 5 agents, organised around the **honesty spine**: *claim ≤ evidence*. Gaps are marked, not hidden.

## What it is

Touchstone bundles a 6-stage workflow (Explore → Grill → Keystone → Design-Spec → Plan → Build → Review Gate) with mechanisms that hold every stage to the honesty spine. The plugin's spine is **`claim ≤ evidence`** — every artifact (spec, plan, commit, review) carries the evidence its claims rest on; missing evidence is marked `[假設]`/`[unverified]`, never papered over.

The spine is carried *through* four roles (not enforced by a fifth):

- **Skill** — drafting / authoring (`design-spec`, `keystone`, `code-review`, ...)
- **Mode** — narration discipline (`grounded-claims` — cite source, mark assumptions)
- **Discipline** — domain stance (`source-as-truth` — code is authoritative; docs describe why)
- **Baseline** — universal foundations (`intention-first` — name intent before mechanism)

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
# everything-claude-code — architect agent + language-specific reviewers
claude plugin marketplace add https://github.com/your-org/everything-claude-code   # check upstream URL
claude plugin install everything-claude-code@everything-claude-code --scope user

# superpowers — writing-plans, using-git-worktrees, brainstorming, etc.
claude plugin install superpowers@claude-plugins-official --scope user
```

**Optional (cross-vendor review path):**

```bash
# codex — cross-vendor agents (codex:rescue, codex-* reviewers/implementers)
claude plugin install codex@openai-codex --scope user
```

Without `everything-claude-code`, the language-specific code reviewers and the `architect` agent dispatched by `cross-provider-architect` are unavailable. Without `codex`, only single-vendor (Claude-only) review paths work — touchstone degrades gracefully but loses the parallel CC+Codex composite.

## Skills

- `touchstone:init` — Bootstrap project adoption with `.claude/touchstone.yaml`.
- `touchstone:keystone` — Structural-commitment skill: decide and record a durability bet over code, docs, or suite structure.
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
- `touchstone:codex-tdd` — Cross-vendor TDD with Codex red-green-refactor.
- `touchstone:codex-reviewer` — Read-only Codex code review (Pattern B).
- `touchstone:codex-adversarial-reviewer` — Codex adversarial design critique.

## 6-stage workflow

The full workflow lives in your global `~/.claude/CLAUDE.md` (touchstone integrates as routing). See `docs/comparisons.md` for scope and `CONTEXT.md` for vocabulary.

## OTel setup (for CC-subagent figures)

`/touchstone:insight` attributes CC-subagent token/cost per agent, but only when an OpenTelemetry collector funnels Claude Code telemetry into a local JSONL sink. Without it, CC-subagent cells are `[unverified]` (Codex figures do not need it — they come from `~/.codex/sessions`).

**One-shot setup.** This installs/locates `otelcol-contrib`, writes the collector config (the **logs** pipeline the reader consumes), loads a persistent launchd agent (macOS), and appends the telemetry env vars — including `TOUCHSTONE_OTEL_EXPORT` — to your shell profile. Idempotent; re-running is safe:

```bash
scripts/metrics/setup-otel.sh
```

Then open a new shell (so the env vars load) and run your touchstone gates. Overrides: `OTELCOL_BIN` (collector binary), `PROFILE_FILE` (shell rc to edit), `OTEL_HTTP_PORT`.

### Read the report

Run-manifests are stamped automatically by a plugin hook on every **design-spec / design-review /
anvil** invocation (to `${TOUCHSTONE_METRICS_DIR:-/tmp/touchstone-metrics}/runs`) — no setup, no mode
toggle. Codex cost is harvested from `~/.codex/sessions` rollouts. Read the report on demand:

```bash
# via the skill — also bounds the last still-open run at report time
/touchstone:insight

# or directly (TOUCHSTONE_OTEL_EXPORT is set by setup-otel.sh)
scripts/metrics-report.sh --session-id <session-uuid> \
  ${TOUCHSTONE_OTEL_EXPORT:+--otel "$TOUCHSTONE_OTEL_EXPORT"} \
  [--session ~/.claude/projects/<slug>/<session-uuid>.jsonl]   # optional: adds main-loop + session-wallclock summary
```

`--session-id` must match your otelcol export's `session.id` attribute. The reader auto-detects the
nested OTLP shape (`resourceLogs[].scopeLogs[].logRecords[]`) and normalizes it; CC-subagent cost
comes from OTel, Codex cost from `~/.codex/sessions`, and any cell that can't be grounded prints a
`[unverified: <reason>]` marker rather than a fabricated number.

> **Scope limit — read before trusting the Codex numbers.** Codex cost is attributed by working
> directory + time window, so it is reliable only when **at most one active session runs per literal
> cwd at a time**. Separate git worktrees have distinct cwds and are fine; two concurrent sessions in
> the *same directory path* are out of scope and their Codex costs may cross-attribute. CC-subagent
> figures (OTel, keyed by `session.id`) are unaffected.

## Status

`0.2.0`. Experimental. Used by the author on one project across ~30 sessions. Cross-project portability is unverified — see `docs/comparisons.md` for scope boundaries.

## License

MIT. See [LICENSE](LICENSE).
