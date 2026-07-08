---
name: assay
description: |
  Pre-contract interview instrument — the fused single-session interview that
  runs after explore and before design-spec: the AI lays out doc-grounded
  falsifiable assumptions (bold pass included) and extracts the human's tacit
  intent, accounts the four knowledge quadrants, routes every known unknown
  through the unknown-disposition table (probe now / flip-trigger bypass /
  deferred; a structural fork produces an ADR), and emits the guardrail
  contract block the contract author consumes. Requires a live responsive
  user; the human rules readiness once. Invoke inside crucible, or directly
  before authoring a contract.
kind: workflow
---

# /touchstone:assay — Pre-Contract Interview Instrument

One fused interview session that narrows the map-territory gap until the
head/tail guardrail contract is writable. You (the executing agent) lay out
assumptions, extract tacit intent, account the four quadrants, route unknowns
through the disposition table, and author the guardrail block. The human does
exactly two things: answers tacit-knowledge questions and rules readiness.

**Loading constraint — live user required.** In a non-interactive context
(CI, a loop, a scheduled run) do NOT guess-fill any interview answer: flag a
blocker naming assay as the halted step, and stop.

**Unformed-intent escape.** If human-side extraction cannot elicit a stateable
intent, recommend an out-of-band `superpowers:brainstorming` run and halt
assay — do not interview toward an intent the human does not yet hold. (That
skill is NOT a dependency of assay; the recommendation is steering to the user.)

**Inputs.** Sharpened intent + explore findings already in context (you cannot
lay out assumptions about a map that has not been drawn); the parent epic dir
path when one exists — that is the record file's home. When no parent epic
exists, ask the user where to home the record; do not silently pick.

## Map-alignment interview

### AI-side laydown (doc-grounded)

Lay out every assumption you would otherwise silently adopt. Each entry MUST:

- **be falsifiable** — name a concrete file / interface / behavior. A vibe
  sentence ("the config handling is probably fine") is the violation form;
  rewrite it until a probe could prove it wrong.
- **be ordered by architectural impact** — most expensive-to-change first.
- **carry both tags** — `load-bearing?` (does the design collapse if this is
  wrong) × `probe-cost` (how expensive to verify).
- **carry your leaning** — the disposition you would bet on, with a one-line
  reason; the human reacts to a stated position instead of authoring one.

Falsifiability lenses (explicit list — add a future lens HERE, no rename or
re-wiring needed):

1. **Concrete referent** — the named file / interface / behavior above.
2. **Doc-grounding** — check each assumption against CONTEXT.md / docs/adr;
   when your term or claim conflicts with that ledger, the conflict IS an
   assumption — surface it as its own table row.

**Write-back rule (standing).** When a term resolves against the docs
mid-session, update CONTEXT.md inline IF the term meets CONTEXT.md's
admission boundary (cross-epic load-bearing: referenced by ≥2 epics or a shipped
surface). Otherwise record the resolution in the assay record / epic-local
artifact only — never grow CONTEXT.md with single-epic terminology.

**Bold pass (unconditional).** Also lay out the structurally-larger moves you
suppressed under conservative bias, ordered by blast radius. "Change nothing
structural" is itself an assumption — put it on the table. An empty bold
section is permitted ONLY as the explicit line "no suppressed structural
moves"; silence is the violation. Bold items are not auto-adopted — they enter
the same unknown disposition.

### Human-side extraction

Ask questions in the laydown's architectural-impact order, targeting tacit
knowledge ONLY: intent, priority, unstated constraints, what done looks like.
Do NOT ask architecture / API design questions — that design work is yours;
asking the human reverses the responsibility.

Presentation mechanics (instructions, not steering):

- Ask exactly ONE question per message; every question carries your own
  leaning and a one-line reason.
- When the answer options are enumerable, ask through AskUserQuestion with
  your leaning marked "(Recommended)" — the tool is the default form, the
  discipline is the rule; one call carries exactly one question (do not use
  the tool's multi-question capacity).
- Speak plainly to the user: no skill-internal section names, no self-coined
  code labels in any message to the user; refer to a laydown entry by a
  content phrase, never by row number.
- Facts the repo or its docs can answer are yours to look up before asking;
  bring the human only decisions and tacit knowledge.
- Stop asking once you can predict the user's answer to the next
  three questions (fewer left → predict all remaining; an empty queue
  simply stops). Stopping ends the questioning round only — disposition
  and readiness still run. One user correction reopens the question queue.

Named instrument — **want-vs-should-want probe**: "if you didn't have to
justify this choice to anyone, what would you actually want?" It catches
sophistication-signaling answers (scalable / clean / modern offered as goals).

### Four-quadrant accounting

| Quadrant | Disposition |
|---|---|
| known knowns | straight into contract facts |
| known unknowns | one disposition row each |
| unknown knowns (human tacit) | extraction converts them to known knowns → contract facts |
| unknown unknowns | acknowledged to exist, never claimed zero; residual goes to the review gates + deviation log |

**Loop rule.** An extraction answer may flip an existing laydown entry OR add
wholly new entries to the inventory — update the table and re-converge within
the session; do not carry a known contradiction forward.

**Proportionality (steering, not a rule).** A small subject compresses rounds
and merges tables but never skips the laydown itself (the bold pass's explicit
empty-section line stays); judge round count by the subject's blast radius.

## Unknown disposition

Known unknowns enter this table from three sources: laydown residuals
(entries neither confirmed nor flipped), future-observable items, and
suppressed items the bold pass left unresolved.

Route EVERY known unknown through the disposition table:

| load-bearing | probe-cost | disposition |
|---|---|---|
| yes | cheap | **probe now** (spike / mock / reference-check / ask) |
| yes | expensive | **flip-trigger bypass** or scope cut — never silent proceed |
| no | — | deferred log |

**Structural fork case** — a fork entry with ≥2 viable approaches and
durability stakes: author an ADR per `adr-authoring.md` (same directory),
carrying the flip-trigger / bet-owner / assumptions fields, with the human as
bet-owner. Grade the structural judgment against `references/arch-rubric.md`.
For a fork worth critique evidence, dispatch
`touchstone:cross-provider-architect` (adaptable — omit with the reason
recorded in the ADR).

**Readiness criterion.** Every load-bearing known unknown
resolved or flip-triggered. NOT "all cells filled"; NOT "zero unknowns".

**The human rules readiness once.** Guard the ruling with the non-yes
taxonomy:

- "whatever you think" = delegation, not a decision → re-ask with two concrete options.
- "sounds good" = ambiguous → ask what they would refine.
- silence + "let's start" = abandonment, not convergence → stop; ask what is missing.
- an explicit correction ("no, that's not it") → fold it into the table, restate, loop.
- Only an explicit yes advances.

Not ready → run the cheap probe(s), return to the alignment table, re-converge.
Ready → author the guardrail block.

## Guardrail block authoring

Emit the guardrail contract block, four parts:

1. **Head** — scope, invariants (unbreakable boundaries), contract facts (the known-knowns list), out-of-scope.
2. **Tail** — ≥1 acceptance seam per load-bearing decision, written as scenario skeletons that feed the contract's AC layer.
3. **Flip-trigger registry** — every disposition bypass: named observable signal + revisit point.
4. **Deferred log** — the non-load-bearing unknown stubs.

Two consumers — name the handoff explicitly: a **full design-spec** (head →
its Scope / Invariants sections; in a crucible chain the record also fills
design-spec's Foundation — intention ← this record's `subject:`, aim ← head
scope condensed, out-of-scope ← head out-of-scope — so design-spec consumes
instead of re-eliciting; tail → its AC layer) or a **PRD+seams light
contract** (its acceptance-seam + invariant fields). Do NOT
modify `skills/design-spec/template.md` — the block is content the contract
author pours into existing sections, not a template change.

## Durable record

Write `<epics-dir>/<slug>/assay-<YYYY-MM-DD>-<subject>.md` — one record file
per contract subject. A re-run on the same subject (e.g. after a not-ready
loop) APPENDs a new dated section to the same file; never overwrite. Sections:

- `## Alignment table` — merged laydown + extraction, dual tags + leaning,
  bold-pass rows marked
- `## Readiness ruling` — one line: explicit yes + date
- `## Flip-trigger registry` — signal + revisit point per row
- `## Deferred log`
- `## Deviation log` — appended during downstream execution; the instrument's
  standing validity metric: gap / quadrant / which-stage-could-have-caught / catcher

**Execution-precision (every ruling above).** Every disposition names its
file (and line/anchor where applicable) so a later session executes it
without re-derivation; every flip-trigger names both an observable signal and
a revisit point.

## Honest ceiling

assay's done-claim is accounting-completeness: table entries falsifiable,
unknowns dispositioned, human explicit yes. The interview NARROWS
unknown-unknowns; it never proves them zero. Gap size is measured downstream
by the deviation log — never claimed at interview end.
