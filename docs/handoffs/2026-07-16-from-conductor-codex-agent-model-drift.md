# Handoff: codex-* agents dispatch with no pinned model (config-drift risk)

- **From**: conductor session 2026-07-16 (pilotfish comparison → touchstone agent audit)
- **Status**: open — small, mechanical
- **Class**: verify-never-assume / config-layer drift (same family as the
  `CLAUDE_CODE_SUBAGENT_MODEL` incident logged in conductor's benchmark protocol)

## Finding

All three codex-side agents (`agents/codex-reviewer.md`,
`agents/codex-adversarial-reviewer.md`, `agents/codex-implementer.md`) forward via
`codex exec --json --skip-git-repo-check ...` **without a `-m`/`--model` flag**.
The effective model is whatever the operator's codex config defaults to at run
time — it can drift silently across machines, config edits, and Codex CLI
upgrades, and nothing in the review record says which model actually reviewed.

The CC arms are pinned (`model: sonnet` in frontmatter); the codex arms are not.
Cross-vendor review's independence claim is thus half-pinned: one arm's identity
is declared, the other's is ambient.

## Suggested fix (either is enough)

1. Pin: add an explicit `-m <model>` sourced from one declared place (agent
   frontmatter comment or a single config note), OR
2. Disclose: have the forwarder echo the resolved model (codex exec reports it
   in its JSON stream) into the review output, so every review record carries
   the model that produced it.

Option 2 is cheaper and matches touchstone's claim≤evidence spine: don't force
a choice of model, just make the actual one auditable.
