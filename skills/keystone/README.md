# keystone — maintainer notes

Orientation for maintainers. The executable procedure lives in `SKILL.md`; this file
holds usage reference and dependency context the running agent does not need.

## Invocation

| Command | Behavior |
|---|---|
| `/touchstone:keystone` | Interactive: asks for question, context, candidates |
| `/touchstone:keystone "<question>"` | Skip the prompt; derive context from conversation |

(No `--defer-adr` option: once a decision is reached the durable ADR is normative — see `SKILL.md` and the binding rule below. ADR capture is skipped only when NO decision was made.)

## Dependencies

- **`touchstone:cross-provider-architect`** composite skill (required) — wraps
  `everything-claude-code:architect` (CC) + `codex-adversarial-reviewer` (Codex) in Pattern A.
- **`codex-reviewer`** / **`codex-adversarial-reviewer`** backend agents (required by the
  composite when Codex is healthy).
- **`everything-claude-code:architecture-decision-records`** (optional) — ADR capture at
  the ADR-record step. The not-installed fallback (manual ADR per `adr-authoring.md`) is
  enforced inline in `SKILL.md`.

## Decision persistence options

The decision record is durable by design (written to an ADR). Ephemeral elements:

- **ADR** — canonical form; the Alternatives Considered section captures the decision.
- **Design-spec Related section** — reference the ADR.
- **Project working notes** — if the decision was deferred, save the memo at a
  project-defined location (user-driven; no skill config).

The binding rule — do not write to `docs/adr/` unless a decision was made — stays inline
in `SKILL.md`.
