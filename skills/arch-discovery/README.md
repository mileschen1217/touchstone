# arch-discovery — maintainer notes

Orientation for maintainers. The executable procedure (Setup / Discovery / Sweep / Matrix
modes) lives in `SKILL.md`.

## Slot in the 6-stage workflow

```
1.  Explore                              → research notes
2.  /touchstone:arch-review              → ADRs (per-question decisions)
2.5 /touchstone:arch-discovery  ← HERE   → discovery doc + matrix
3.  /touchstone:design-spec              → GWT contract (assumes 2.5's system model)
4.  /superpowers:writing-plans           → execution sequencing
5.  Build (ATDD + TDD)
6.  Review Gate
```

Discovery is the system-definition layer. Specs (Stage 3) inherit its system model, ownership,
and invariants as starting assumptions — they don't re-derive them.

## Integration with sibling skills

| Skill | Relationship |
|---|---|
| `/touchstone:arch-review` | Sub-tool — invoked by `sweep` when a cell is "settle between two approaches"; the resulting ADR is cited from the discovery. |
| `/touchstone:design-review` | Downstream gate — end-of-discovery audit when the matrix is complete; recognizes `type: discovery`. |
| `/touchstone:design-spec` | Downstream — hand off after `/touchstone:design-review` clears Critical/High; the spec inherits §1 system model as `Status: assumed`. |
| `/touchstone:epic-driven-roadmap` | Discovery doc gets `epics: [<slug>]` frontmatter; appears as a Stage 2.5 artifact under the epic index. |

## Authoring anti-patterns

- **Single-feature change** — overkill; go to `/touchstone:design-spec` (also enforced by Skip-when).
- **Treating the matrix as a checkbox** — cells must cite specific sections, not "yes"; empty `covered` claims are gaps in disguise.
- **Skipping §1 (system model)** — downstream sections then have nothing to cite (Discovery Mode drafts §1 first).
- **Conflating discovery with spec** — discovery describes; spec contracts. Writing GWT scenarios means you're past discovery.
- **Per-feature monolith fragments** — features cross-cut; they appear across §3/§4/§5/§6 in the spine, not in per-feature sub-trees.
- **Running sweep without a starting matrix** — sweep iterates cells; an empty §0 has nothing to do (use Setup/Discovery first).
- **Authoring without updating the matrix** — content drift; walk the matrix after every authoring session.

## Other pointers

- Upstream: Topic 2 exploration routing (`~/.claude/CLAUDE.md`).
- Doc Routing convention: project's `CLAUDE.md § Doc Routing`.
