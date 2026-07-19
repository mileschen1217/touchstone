# touchstone

> A test of what is genuine. (試金石 — a stone used to test the authenticity of metal.)

A Claude Code plugin for **workflow discipline** — 11 skills + 4 agents, organised around the **honesty spine**: *claim ≤ evidence*. Gaps are marked, not hidden.

## What it is

Touchstone bundles a 6-stage workflow (Explore → Assay → Design-Spec → Plan → Build → Review Gate) with mechanisms that hold every stage to the honesty spine. The plugin's spine is **`claim ≤ evidence`** — every artifact (spec, plan, commit, review) carries the evidence its claims rest on; missing evidence is marked `[假設]`/`[unverified]`, never papered over.

The spine is carried *through* the plugin's surfaces, not enforced by a separate mechanism:

- **Skills** — drafting / authoring (`design-spec`, `assay`, `code-review`, ...)
- **`grounded-claims`** — narration discipline (cite source, mark assumptions)
- **`source-as-truth`** — project discipline (code is authoritative; docs describe why)
- **`intention-first`** — universal baseline (name intent before mechanism)
- **eval loop** — every gate stamps its yield (`.touchstone/eval/stamps.jsonl`); epic close reckons keep / adjust / kill per gate

## Install

```bash
git clone https://github.com/mileschen1217/touchstone ~/projects/touchstone
claude plugin marketplace add ~/projects/touchstone
claude plugin install touchstone@touchstone --scope user
```

⚠️ Plugin dispatches agents and runs bash; use in trusted contexts only.

## Dependencies

Touchstone delegates work to agents and skills that live in other plugins. Install these before running touchstone skills.

**Optional (build orchestration):** the `conductor` plugin — `anvil` builds through
`conductor:orchestration-mode`; absent, anvil falls back to the light loop.

**Optional (cross-vendor review path):**

```bash
# codex — cross-vendor agents (codex:rescue, codex-* reviewers/implementers)
claude plugin install codex@openai-codex --scope user
```

The review/architecture agents (`architect`, `code-reviewer`) are vendored plugin-local since 0.18.0 — no external plugin is needed for any touchstone execution path. Without `codex`, only single-vendor (Claude-only) review paths work — touchstone degrades gracefully but loses the parallel CC+Codex composite. (The optional `everything-claude-code` plugin's language-testing skills remain a useful depth reference for the test-evidence lens, nothing more.)

## Skills

- `touchstone:init` — Bootstrap project adoption with `.claude/touchstone.yaml`.
- `touchstone:crucible` — Front-end contract orchestrator: explore → assay → design-spec, one human accept.
- `touchstone:anvil` — Back-end contract executor: entry check → conductor orchestration-mode (AC-coverage floor) → final cross-vendor review, stops before ship.
- `touchstone:assay` — Pre-contract interview instrument: three-way alignment (vocabulary / maps / territory) — laydown-first full table ⇄ tacit-intent extraction → published predict round → consequence probes → readiness (explicit yes + clean round) → record consensus section the contract author consumes.
- `touchstone:design-spec` — Author the contract spine: Foundation → User Stories (US-N) → Requirements (REQ-N, `traces-to`) → ACs (GWT), challenge-stamped.
- `touchstone:design-review` — Gate spec/plan/ADR before Build (cross-provider doc review).
- `touchstone:code-review` — Cross-vendor batch review of a logical commit group (single-commit ad-hoc review → Claude Code built-in `/code-review`).
- `touchstone:epic-driven-roadmap` — Pure-tracker ROADMAP + per-epic index convention.
- `touchstone:grounded-claims` — Narration mode: cite source, mark `[假設]`.
- `touchstone:cross-provider-reviewer` — Parallel CC + Codex composite; internal roles `review` / `architecture-critique`.

## Agents

- `touchstone:codex-reviewer` — Codex arm, both internal roles (review / adversarial critique via envelope lens; Pattern B reviewer).
- `touchstone:code-reviewer` — Read-only CC arm, both internal roles (Pattern A / Pattern B).

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

## Status

`2.0.0` — the distilled rewrite (see `.claude-plugin/plugin.json`). Experimental. Used by the author on one project. Cross-project portability is unverified — see `docs/comparisons.md` for scope boundaries.

## License

MIT (LICENSE file not yet committed).
