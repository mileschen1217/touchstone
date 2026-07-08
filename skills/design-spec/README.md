# design-spec — maintainer notes

Orientation for maintainers. The executable procedure (Load vocabulary, Draft Mode) lives in `SKILL.md`.

## Workflow chain

```
/touchstone:crucible (explore → assay) → /touchstone:design-spec
  → human accept → /touchstone:anvil (writing-plans → plan-review → SDD → final review)
```

## Upstream / downstream

- Front-end orchestrator (upstream): `/touchstone:crucible` — normal entry; exploration is its in-chain phase.
- Interview instrument (upstream): `/touchstone:assay` — assumption/intent interview; its
  unknown-disposition fork resolves structural-commitment questions (ADR) before drafting the spec.
- ATDD chain (downstream): "ATDD — spec and test development" in global `CLAUDE.md`.
- Plan generation (downstream): `/superpowers:writing-plans`.
- design-review gate (downstream, consolidated): `/touchstone:design-review` — runs after crucible writes `accepted-candidate`.
- ADR workflow: `${CLAUDE_PLUGIN_ROOT}/skills/assay/adr-authoring.md`.

## Example

- A spec matching the template: `docs/superpowers/specs/2026-04-16-m-extract-knowledge-design.md`
  (Obsidian repo).
