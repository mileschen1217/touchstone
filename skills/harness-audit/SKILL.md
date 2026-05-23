---
name: harness-audit
description: |
  Composite harness-health dashboard. Surveys Claude Code session logs to
  surface skill usage patterns, dead skills, ADR adherence drift, and hook
  fire/fail signals. Points at specialist audits (/retro, /context-budget,
  /skill-stocktake) for deep dives. Invoke weekly or monthly to answer
  "is my custom harness working well?"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
kind: workflow
---

# m-harness-audit

How do I know the harness runs well or bad? This skill answers that with a
composite view, then routes to specialist audits for depth.

## Scope: mostly user-level

The harness lives mostly at user-level (`~/.claude/skills/`, session logs for
ALL projects, the central ADR directory). So this skill surfaces user-level
signal regardless of CWD:

| Signal | Scope |
|---|---|
| Skill usage counts | Across ALL projects (all session JSONL under `~/.claude/projects/`) |
| Custom-skill coverage | User-level `~/.claude/skills/` (all `m-*` / `ai-*` skills) |
| Hook fire/fail | All sessions, all projects |
| Agent delegation log | All Agent dispatches (`~/.claude/agent_delegation.log`, written by `log-agent-delegation.sh` hook) |
| ADR adherence | Central ADR home (`claude_code_config/docs/adr/`) |
| auto-memory | Per-project (keyed by CWD). Use `--all-memory` to see all. |

Running under `~/Obsidian` vs `~/app/foo` gives the same view of
skill/hook/ADR signal — only the auto-memory section differs. This is
intentional: the harness is one thing, not per-project.

Project-local signal (project CLAUDE.md drift, project-local `.claude/skills/`)
is covered by `/skill-stocktake` when run with the project as CWD.

## When to Invoke

- **Weekly** — quick check (default: last 7 days)
- **Monthly** — deeper check (last 30 days) + ADR sweep
- After adding significant skills/hooks/agents
- When sessions feel slow or friction-heavy (check context bloat)

## Usage

```
/m-harness-audit              — weekly window (7d)
/m-harness-audit 30d          — monthly window
/m-harness-audit --dead       — dead-skill detection only
/m-harness-audit --adr        — ADR adherence sweep only
/m-harness-audit --full       — all signals + dispatch specialist audits
```

## Signals

Six signals, each read only when its mode/flag runs. Full bash blocks + per-signal interpretation → [`references/signals.md`](references/signals.md):

1. **Skill usage** (session JSONL) — top/bottom invocations, dead-skill candidates.
2. **Custom-skill coverage** — `~/.claude/skills/` `m-*`/`ai-*` cross-referenced with usage.
3. **Hook fire/fail** (session JSONL) — fire vs fail rate, zero-fire detection.
4. **Agent delegation** (`~/.claude/agent_delegation.log`) — top agents, vendor split, error rate.
5. **ADR adherence** (`--adr`) — extract decision, check implementation resolves, flag drift.
6. **auto-memory health** — entry count, index size, staleness.

## Report format

Markdown template for the composite report → [`references/report-format.md`](references/report-format.md).

## Specialist audit dispatch (`--full` mode)

After the composite report, offer to chain into:
- **`/retro`** — commit-driven engineering retro (gstack) — velocity, test
  health, plan completion
- **`/context-budget`** — token consumption across agents/skills/rules (ECC)
- **`/skill-stocktake`** — skill quality checklist (ECC) — full review of
  `~/.claude/skills/` custom skills
- **`/cso`** — infrastructure-first security audit (gstack) — if
  security-sensitive work happened recently

Present via AskUserQuestion which to run (or "skip").

## Frequency

| Cadence | Action |
|---|---|
| Weekly | `/m-harness-audit` (7d) — skill usage + hooks |
| Monthly | `/m-harness-audit 30d --full` — + ADR sweep + specialist dispatch |
| Quarterly | Manual: walk the 6-stage workflow end-to-end on a throwaway feature, note friction |

## Related

- Upstream signals: Claude Code session JSONL, gstack analytics, ECC instincts
- Specialist audits: `/retro`, `/context-budget`, `/skill-stocktake`, `/cso`
- ADR home: `claude_code_config/docs/adr/`
- Auto-memory: `~/.claude/projects/<project>/memory/`

## What this skill is NOT

- Not a telemetry capture layer — it reads what's already logged
- Not a replacement for `/retro` or `/skill-stocktake` — those are the deep
  dives; this skill is the triage that routes to them
- Not a hook enforcer — surfaces signals, doesn't auto-fix
