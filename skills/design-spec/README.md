# design-spec — maintainer notes

Orientation for maintainers. The executable procedure (Load vocabulary, Draft Mode, the
architect critique, the Boundary) lives in `SKILL.md`.

## Workflow chain

```
Explore → /touchstone:design-spec → /superpowers:writing-plans → Build (ATDD+TDD)
```

Naturally chained with exploration (Topic 2 routing) on the input side and
`/superpowers:writing-plans` on the output side.

## Upstream / downstream

- Exploration routing (upstream): Topic 2 in global `CLAUDE.md`.
- Architecture consult (upstream, conditional): `/touchstone:keystone` — resolve
  structural-commitment questions before drafting the spec.
- ATDD chain (downstream): "ATDD — spec and test development" in global `CLAUDE.md`.
- Plan generation (downstream): `/superpowers:writing-plans`.
- design-review gate (downstream, distinct from the architect critique): `/touchstone:design-review`
  — the distinction is load-bearing and stays in `SKILL.md`'s Boundary section.
- ADR workflow: `${CLAUDE_PLUGIN_ROOT}/skills/keystone/adr-authoring.md`.

## Example

- A spec matching the template: `docs/superpowers/specs/2026-04-16-m-extract-knowledge-design.md`
  (Obsidian repo).
