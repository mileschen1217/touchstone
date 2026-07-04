# Skill authoring template

The committed home of touchstone's skill-body form. The binding standard is two
sentences (also in `CLAUDE.md § Skill-body content conventions`):

1. **Layer calibration** — where deviation is a defect, write an instruction
   (unconditional imperative); where deviation is legitimate judgment, write
   steering (name the goal and the trade-off, not a pseudo-rule).
2. **Form economy** — every line must change what the executing agent does on
   this run; guideline ≤200 lines / ≈2.5k tokens per skill body, hard cap 500
   lines; the review-prompt surface's total token count never grows net.

## Template

```markdown
---
name: <skill-name>                       # matches the directory
description: Use when the user wants/asks for/mentions <X>.   # routing signal, not a summary
# allowed-tools / user-invocable / kind as the skill needs
---

# /<namespace>:<skill-name> — <Title>

<One sentence: what this invocation does. No rationale, no history.>

## Phase 1 — <Name>

**<AnchorTerm>** — declarative one-sentence definition (define once, reuse the term).

Imperative directive. Imperative directive.

- [ ] Completion criterion the agent can verify without a human (grep-able / runnable / output-checkable).

## Phase 2 — <Name>

Imperative steps.

<Anti-pattern name> — what it looks like. → Fix: imperative fix.

## Related

- Rationale / history / dependencies: `README.md` (or `CONTEXT.md` named concept).
```

## Rules the template encodes

- **description = routing signal.** "Use when …" trigger phrasing; a human-invoked
  skill gets a human-readable one-liner instead. Never a document summary.
- **First body sentence states the action of this invocation** — the reader already
  decided to run the skill; do not argue for its existence.
- **Imperatives for instructions, declaratives for definitions; zero hedging**
  ("typically", "consider", "may want to" are all banned — an instruction is
  unconditional or it is steering, in which case name the trade-off explicitly).
- **2–6 bold anchor terms**, each defined once at first use, referenced by name after.
- **Per-phase completion checkboxes** the agent can self-verify.
- **Secondary material goes to sibling files** (`references/*.md`, `README.md`), with
  one exception: content a cold-dispatched sub-agent must apply is injected inline
  in the dispatch prompt (the sub-agent cannot see siblings) — and every lens in a
  multi-lens dispatch is grounded to equal depth, never one inline + one by name.
- **Anti-patterns are documented; correct-output examples are not** (trust the
  executor to apply rules; name the smells and their fixes). Exception: an output
  whose exact string a downstream consumer parses (sentinel line, report field
  phrasing) is a contract — show it verbatim.
- **No history, no version narration, no ADR numbers in the body** — rationale lives
  in `README.md` / `CONTEXT.md`; cite the named concept, not the ledger entry.
- **State the actor for every MUST** — a prose instruction is honest as an
  instruction; never describe an LLM-followed sentence as a system-enforced
  mechanism unless an event-bound check (hook / exit code) actually enforces it.
