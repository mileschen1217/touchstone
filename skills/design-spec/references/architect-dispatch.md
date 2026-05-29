# Architect dispatch (default: Pattern A composite — fresh context)

Resolve the dispatch target:
- `force_architect = cc` → dispatch `everything-claude-code:architect` directly with `model: "sonnet"` (single agent, fresh context — model override supersedes the agent's `model: opus` frontmatter).
- `force_architect = codex` → dispatch `codex-adversarial-reviewer` directly (single agent, fresh context).
- Default (no override) → dispatch `touchstone:cross-provider-architect` composite (Pattern A — dual parallel: CC `architect` validates + Codex `codex-adversarial-reviewer` pressure-tests; auto-falls back to CC-only if Codex unavailable):

```
Skill(skill: "touchstone:cross-provider-architect", args: {
  "task": "<the structural-review prompt below, with the spec path or spec text inlined>",
  "role": "architect",
  "task_dir": "<optional: absolute path>"
})
```

The dispatched skill (`touchstone:cross-provider-architect`) owns its procedure end-to-end.

Task envelope contents:

> Review the design spec at `<absolute path to spec>`. Check:
> 1. Problem/Scope/Non-goals are concrete and falsifiable
> 2. Acceptance Criteria cover happy path, error paths, and boundaries (ATDD contract)
> 3. Interfaces/Contracts are specific enough for TDD (field names, types, error returns)
> 4. Error Handling rows map 1:1 to unit tests
> 5. Invariants are cross-cutting rules, not restatements of contracts
> 6. Risks/Open Questions are not hidden
>
> Return: structural feedback only (not line edits). Name any missing sections, any vague contracts, any missing error paths. Flag any architectural concerns that should be resolved before implementation planning begins.

Use fresh context — the composite skill orchestrates fresh subagent contexts; backend agents (CC architect, Codex adversarial reviewer) inherit no drafting context.

## After dispatch — Informed-consent checkpoint

**Informed-consent checkpoint (orthogonal to the advisory verdict):** if the composite's
returned synthesis (`<task_dir>/review.md`) carries a ⚠️ DEGRADED or ⚠️ PARTIAL banner,
present the banner text to the user VERBATIM and obtain explicit acknowledgement (an
`AskUserQuestion` choice, or an explicit user "proceed") BEFORE folding the Step-5
critique back into the draft or writing the spec's final Output. The Step-5 review is
advisory and non-gating (see `SKILL.md § Boundary`), but the consent checkpoint applies
regardless — the banner is informational, not a hard block, but the workflow MUST NOT
auto-advance past it without the human knowingly acknowledging that the structural
critique was produced by a single provider rather than the dual-parallel Pattern A pair.
A clean synthesis (no banner) does not trigger this checkpoint. The banner's meaning
is defined in `skills/cross-provider-reviewer/references/provenance.md`. (This mirrors
`design-review/SKILL.md:150-157` and `arch-review/SKILL.md § 2.5`.)
