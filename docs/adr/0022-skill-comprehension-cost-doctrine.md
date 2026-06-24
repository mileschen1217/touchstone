---
kind: workflow
adr_id: 0022
status: Accepted
date: 2026-06-24
kill-on: mechanical-comprehension-linter
---

# ADR-0022: Skill comprehension-cost doctrine — understandable without a decoder ring

## Status

Accepted. Sibling to ADR-0020 (locality-first skill doctrine). Distinct from ADR-0020
point 4 (altitude — content must trace to a force): content can trace to a force and
still use a name that no cold reader can decode. This ADR governs that separate cost.

## Context

Every non-self-describing token in a skill — an unexpanded abbreviation, an internal
positional name, an undefined term injected from a private glossary — taxes every
subsequent read. Readers who lack the accumulated context of the original author pay a
comprehension toll before they can act on the content. For a Claude Code markdown-skill
plugin, where skills are read by both human maintainers and cold-dispatched agents with
no warm context, that toll compounds: a cold agent that encounters an undefined term
(`FF`/`FB`, `Pattern A`, a bare `rung`) cannot recover — it either halts or proceeds on
a guess.

The driving force is **bounded cognition**: working memory is finite, and every
non-self-describing token occupies a slot that could be used for the actual decision the
skill is trying to communicate. Reducing the comprehension cost of each read is not
cosmetic polish — it is a correctness property for cold-dispatch correctness and a
maintenance-cost property for human readers.

ADR-0017 established that cold-injected fragments must be "complete, self-contained
units." This ADR extends that requirement beyond inject fragments to every skill
surface: names, bodies, and inline references.

## Decision

**A skill must be understandable without a decoder ring.** Minimize the reader's
comprehension cost. Five sub-rules apply across all skill surfaces (names, bodies,
inject fragments, CONTEXT.md entries):

1. **Names self-describing.** An evocative metaphor as an invocation name (`crucible`,
   `keystone`) is acceptable if and only if its `description:` frontmatter carries the
   full meaning — a cold reader who sees only the name and its frontmatter understands
   what the skill does. A positional or internal name (`step0-resolver` names a position,
   not a purpose) is not acceptable — rename to the function it performs.

2. **Abbreviations expanded.** Write `feedforward` and `feedback`, never `FF` or `FB`,
   everywhere including CONTEXT.md. The same rule applies to any other abbreviation that
   is not a universally recognized standard (e.g. `AC` for acceptance criteria is
   borderline; when in doubt, expand on first use). An undefined abbreviation is a
   decoder-ring failure.

3. **Lead with plain words.** State the plain action or concept first; introduce a coined
   term after. "Each skill must be a deep module" (plain first, coined term named once it
   is established) is preferable to "The deep-module invariant applies to each skill"
   (coined term leads, reader must already know it). This lowers the entry barrier for
   readers who encounter the term for the first time.

4. **Cold-injected fragments self-contained.** Hard bar: a cold reviewer dispatched with
   zero glossary access must be able to act on the fragment without ambiguity. Any
   undefined token in an injected fragment — a bare `rung`, an unexplained `kill-on`,
   a `Pattern A` with no expansion — is a decoder-ring failure. This extends ADR-0017's
   "complete, self-contained unit" requirement to semantic completeness, not just
   structural completeness.

5. **Structure for scannability.** A dense multi-point paragraph becomes a list. A
   reader who needs to locate one rule among five should not have to parse a paragraph to
   find it. This ADR's own sub-rules are an application of the rule.

## Consequences

- Every skill edit that introduces a new abbreviation, positional name, or injected
  reference must clear the decoder-ring test before merge: would a cold reader with zero
  glossary understand this without looking anything up?
- CONTEXT.md abbreviation entries (`FF`/`FB`, etc.) are candidates for replacement in
  the next content pass. The authoritative forms live in the consuming skills; CONTEXT.md
  tracks only the expanded canonical term.
- Positional shared-step names in `skills/_shared/` (e.g. `step0-resolver.md`) are
  candidates for rename to function-descriptive names in the next naming pass.
- Cold-inject fragments in `skills/_shared/inject/` must be audited for unexpanded
  abbreviations and undefined terms; each failure is a comprehension-cost bug, not a
  style note.

**Flip trigger:** if a mechanical linter is built that can detect decoder-ring failures
deterministically (undefined tokens, unexpanded abbreviations, positional name patterns),
this doctrine becomes a checker specification. At that point, retire this ADR and replace
it with the linter's rule set. Until then, the doctrine is a judgment-applied standard
enforced by the human reviewer oracle (ADR-0020 point 3).

## Related ADRs

- ADR-0017 (injectable doctrine fragments) — establishes structural self-containment for
  cold-injected fragments; this ADR extends that to semantic self-containment across all
  skill surfaces.
- ADR-0020 (locality-first doctrine + deep-module-over-merge) — governs where doctrine
  lives and whether skills merge; this ADR governs how skill content reads to a cold
  reader. Point 4 of ADR-0020 (altitude — content traces to a force) is a distinct
  orthogonal requirement.
