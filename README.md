# m-workflow

A Claude Code plugin bundling 11 workflow-stage skills plus an init skill, packaged for cross-project portability.

**Status:** `experimental-buildroot-only` (MVP). Does not claim portability until AC-7b second-project validation passes.

## Install (local development)

```bash
claude plugin marketplace add ~/projects/m-workflow
claude plugin install m-workflow@m-workflow-dev
```

Then in any project:

```
/m-workflow:init        # writes .claude/m-workflow.yaml
/m-workflow:design-spec <feature>
/m-workflow:design-review <spec-path>
... etc
```

## Skill inventory

| Slash command | Stage / role |
|---|---|
| `/m-workflow:init` | One-time per-project setup (writes yaml) |
| `/m-workflow:design-spec` | Author a design spec |
| `/m-workflow:design-review` | Pattern A doc review (dispatches cross-provider-reviewer) |
| `/m-workflow:arch-review` | Standalone arch consult (dispatches cross-provider-architect) |
| `/m-workflow:arch-discovery` | E2E system discovery |
| `/m-workflow:epic-driven-roadmap` | Scaffold / close / audit epics |
| `/m-workflow:code-review` | Per-commit or batch code review |
| `/m-workflow:test-quality-audit` | Audit test suite quality + coverage |
| `/m-workflow:harness-audit` | Composite harness-health dashboard |
| `/m-workflow:extract-knowledge` | Distill research docs into reusable notes |
| `/m-workflow:cross-provider-reviewer` | Pattern A composite (CC + Codex review) |
| `/m-workflow:cross-provider-architect` | Pattern A composite (CC + Codex architect) |

## Disciplines

Plugin's stage skills branch on `adopted_disciplines` in `<project>/.claude/m-workflow.yaml`.

| Discipline | Effect |
|---|---|
| `source-as-truth` | Stage skills load CONTEXT.md vocabulary at Step 0; apply Bridge content audit (P1/P2/P3), kill-on lifecycle, standing-vs-transient classification. |

## Maintenance

- **Vocabulary edits:** `CONTEXT.md` only. SKILL.md bodies read CONTEXT.md at runtime; no inline copies to sync.
- **Plugin variable reference:** the plugin-root variable points to install dir; the project-dir variable points to user's working project. See spec § Plugin variable reference for the full table.
- **Audit scripts:** `scripts/migration-audit.sh` runs in 3 modes (namespace / magic-string / unexpanded-vars). `scripts/test-wrapper.sh` is the AC-6a probe.

## Spec + Plan

Design spec: `.swarm/specs/2026-05-17-m-workflow-plugin.md` (rev 4 accepted).
Implementation plan: `.swarm/plans/2026-05-17-m-workflow-plugin.md`.

## License

MIT
