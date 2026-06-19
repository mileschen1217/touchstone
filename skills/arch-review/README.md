# arch-review — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`; this file
holds usage reference and dependency context the running agent does not need.

## Invocation

| Command | Behavior |
|---|---|
| `/touchstone:arch-review` | Interactive: asks for question, context, candidates |
| `/touchstone:arch-review "<question>"` | Skip the prompt; derive context from conversation |
| `/touchstone:arch-review --defer-adr` | Run the consult but skip ADR capture even if a decision is reached |

## Dependencies

- **`touchstone:cross-provider-architect`** composite skill (required) — wraps
  `everything-claude-code:architect` (CC) + `codex-adversarial-reviewer` (Codex) in Pattern A.
- **`codex-reviewer`** / **`codex-adversarial-reviewer`** backend agents (required by the
  composite when Codex is healthy).
- **`everything-claude-code:architecture-decision-records`** (optional) — ADR capture at
  Step 4. The not-installed fallback (manual ADR per `adr-authoring.md`) is enforced inline
  in `SKILL.md` Step 4.

## Memo persistence options

The architect's tradeoff memo is ephemeral by default (lives in the conversation).
Persistence options:

- **ADR** — canonical form; the Alternatives Considered section captures the memo essence.
- **Design-spec Related section** — reference the ADR.
- **Project working notes** — if the decision was deferred, save the memo at a
  project-defined location (user-driven; no skill config).

The binding rule — do not write to `docs/adr/` unless a decision was made — stays inline
in `SKILL.md` Step 4.
