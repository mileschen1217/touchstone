# m-workflow

Workflow-discipline skill family for Claude Code. Bundles design-spec, design-review, arch-review, epic-driven-roadmap, code-review, and related stage skills.

**Status:** R4 spike (0.0.1) — verifying plugin install + path resolution semantics. Not for general use yet.

## Install (local development)

```bash
claude plugin install --local ~/projects/m-workflow
```

After install, restart Claude Code. The skill `/m-workflow:spike` should appear in the available-skills list.

## R4 spike goal

Verify how Claude Code's Skill execution context resolves file paths when a skill runs from inside an installed plugin. Specifically:

- Can a SKILL.md `Read` a sibling file by relative path?
- Can a SKILL.md `Read` a plugin-root-level file by `../../`?
- Is there an environment variable exposing plugin root?
- Does `Skill(skill: "m-workflow:spike")` work cross-skill?

Run `/m-workflow:spike` after install. The skill body lists the verification probes and reports results.

## Related

- Design spec: `~/moxabuild.stacking/buildroot/.swarm/specs/2026-05-17-m-workflow-plugin.md`
- Parent epic: `~/moxabuild.stacking/buildroot/.swarm/epics/workflow-architecture-refactor/`
