# Report format

```markdown
## Harness Audit: last {N} days

### Skill usage
**Top 5:** (usage count / skill)
1. superpowers:brainstorming — 42
2. m-code-review — 28
3. ...

**Dead candidates (0 invocations):**
- m-foo (custom, 34 days since last use) → suggest: remove / relocate
- ai-bar (custom, 21 days) → suggest: CLAUDE.md mention missing?

### Hooks
- commit-gate.sh: fired 14× / blocked 0× (clean)
- log-agent-delegation.sh: fired 87× / errors 0×
- Any ECC hook issues: ...

### Agent delegations (last {N} days)
**Total:** 87 dispatches | **Error rate:** 1/87 (1.1%)

**Vendor split:**
- cc: 64 (74%)
- codex: 19 (22%)
- gemini: 4 (5%)

**Top agents:**
1. everything-claude-code:code-reviewer — 22
2. codex-implementer — 11
3. Explore — 9
4. ...

**Workflow signal:** Codex agents fired (Phase 2 working). gemini-frontend rare; ok if frontend work was rare.

### ADR adherence
| ADR | Status | Note |
|---|---|---|
| 0010 | in-force | commit-gate.sh present, mentioned in CLAUDE.md |
| 0012 | **drifted** | Context7 MCP mentioned but not in settings.json |
| ... | | |

### auto-memory
- Entries: 7 / index: 9 lines (healthy)

### Recommendations
- [ ] Run `/context-budget` — last run never / >30d ago
- [ ] Run `/retro 7d` — no recent retro found
- [ ] Investigate ADR-0012 drift
- [ ] Consider removing dead skill: m-foo
```
