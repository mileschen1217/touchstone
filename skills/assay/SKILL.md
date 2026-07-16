---
name: assay
description: |
  Pre-contract interview instrument — the fused single-session interview between explore and
  the contract author: aligns human and AI across three arms (vocabulary term sheet /
  falsifiable map laydown + extraction / territory), routes every known unknown through
  disposition (a structural fork produces an ADR), evidences alignment with human-falsifiable
  consequence probes, and terminates at the durable record's consensus section, which the
  contract author consumes. Readiness = explicit yes + a zero-correction probe round. Requires
  a live responsive user; invoke inside crucible or directly before a contract. Out of scope —
  non-interactive/CI (no live user) or unformed intent (→ superpowers:brainstorming).
kind: workflow
---

# /touchstone:assay — Pre-Contract Interview Instrument

One fused interview session aligning human and AI across three arms — vocabulary, maps, territory
(each a section below). Terminal deliverable: the durable record's consensus section, every entry
traced to a row the human confirmed in-session.

**Live user required.** In a non-interactive context (CI, a loop, a scheduled run) do NOT
guess-fill any answer: flag a blocker naming assay, and stop.

**Unformed-intent escape.** If extraction cannot elicit a stateable intent, recommend an
out-of-band `superpowers:brainstorming` run (steering, not a dependency) and halt — never
interview toward an intent the human does not yet hold.

**Inputs.** Sharpened intent + explore findings already in context (explore always precedes
assay — you cannot lay out assumptions about an undrawn map); the parent epic dir path —
the record's home. No parent epic → ask; never silently pick.

## Presentation protocol

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/laydown-first-presentation.md`
> with the Read tool and follow it exactly.

assay's delta: the full picture is the complete alignment table — term-sheet rows (each with its
source marker) + assumption and bold-pass rows (each with its `load-bearing?` × `probe-cost`
tags) — every row also carrying its planned handling (will-ask / self-check / residual→disposition /
deferred); rows queued for extraction count as awaiting the human's attention in the fragment's depth tiering.

## Vocabulary arm — term sheet

The alignment table opens with a term sheet covering the session's key terms, pre-existing and session-coined alike. Each row MUST:

- carry a **self-contained working definition** — readable without this session's context;
  define a term before any other row uses it; never a self-coined code label.
- carry exactly ONE **source marker**: doc-grounded / session-coined (AI or human) / ledger-conflict.
- **ledger-conflict escalation** — a conflict with CONTEXT.md / docs usage ALSO enters the
  alignment table as its own assumption row, routed through disposition like any other.

The sheet is a working surface, not a new authority ledger: pre-existing terms keep their source
of truth in CONTEXT.md / docs; session-coined terms write back only past CONTEXT.md's admission boundary.

## Map arm — AI-side laydown (doc-grounded)

Lay out every assumption you would otherwise silently adopt. Each entry MUST:

- **be falsifiable** — name a concrete file / interface / behavior; rewrite a vibe sentence until
  a probe could prove it wrong. A conflict with CONTEXT.md / docs/adr IS an assumption, its own row.
- **be ordered by architectural impact** — most expensive-to-change first.
- **carry both tags** — `load-bearing?` (does the design collapse if this is wrong) × `probe-cost`
  (how expensive to verify). `deferred` handling ⟺ `load-bearing? = no`.
- **carry your leaning** — the disposition you would bet on, with a one-line reason; the
  human reacts to a stated position instead of authoring one.

**Bold pass (unconditional).** Also lay out the structurally-larger moves you suppressed under
conservative bias, ordered by blast radius. "Change nothing structural" is itself an assumption;
an empty bold section is permitted ONLY as the explicit line "no suppressed structural moves".
Bold items enter the same unknown disposition.

## Map arm — human-side extraction

Ask questions in the laydown's architectural-impact order, targeting tacit knowledge ONLY: intent,
priority, unstated constraints, what done looks like. Do NOT ask architecture / API design
questions — that design work is yours.

- Ask exactly ONE question per message; every question carries your own
  leaning and a one-line reason.
- Enumerable answers go through AskUserQuestion with your leaning marked "(Recommended)" —
  one call, one question (carrier limits: presentation protocol).
- Speak plainly: no skill-internal section names, no self-coined code labels; refer to a table
  entry by a content phrase — a visible stable-id handle beside the phrase is fine — never by row number alone.
- Facts the repo or its docs can answer are yours to look up (territory arm — explore findings
  are the map source; repo claims follow the grounded-claims citation discipline; a row territory
  can settle is settled by lookup, never by asking); bring the human only decisions and tacit knowledge.

Named instrument — **want-vs-should-want probe**: "if you didn't have to justify this choice
to anyone, what would you actually want?" It catches sophistication-signaling answers.

**A published predict round closes questioning — every path.** When you can predict the user's
answers to the next three questions (fewer left → all remaining), PUBLISH the round: each
remaining question WITH your predicted answer; an empty queue is published as an explicit
empty-queue statement. Questioning closes only after the user confirms; a missed prediction
reopens that question (a user correction likewise reopens the question queue), and a later
published round must pass before questioning may close. Each published round — predict or
probe — takes the next id in a SINGLE dated sequence of `R-n` ids (one shared counter).

## Four-quadrant accounting

| Quadrant | Disposition |
|---|---|
| known knowns | straight into consensus contract facts |
| known unknowns | one disposition row each |
| unknown knowns (human tacit) | extraction converts them to known knowns → contract facts |
| unknown unknowns | acknowledged to exist, never claimed zero; residual → review gates + deviation log |

**Loop rule.** An extraction answer may flip an existing entry OR add wholly new ones — update
the table and re-converge in-session; never carry a known contradiction forward.
**Proportionality (steering):** a small subject compresses rounds and merges tables but it never skips the laydown
itself (the bold pass's explicit empty-section line stays); judge round count by blast radius.

## Unknown disposition

Known unknowns enter from three sources — laydown residuals (entries neither confirmed nor
flipped), future-observable items, unresolved bold-pass items. Route EVERY one through:

| load-bearing | probe-cost | disposition |
|---|---|---|
| yes | cheap | **probe now** (spike / mock / reference-check / ask) |
| yes | expensive | **flip-trigger bypass** or scope cut — never silent proceed |
| no | — | deferred log |

**Structural fork case** — a fork entry with ≥2 viable approaches and durability stakes:
author an ADR per `adr-authoring.md` (same directory) with the flip-trigger / bet-owner /
assumptions fields, the human as bet-owner; grade against `references/arch-rubric.md`; for a
fork worth critique evidence, dispatch `touchstone:cross-provider-architect` (adaptable —
omit with the reason recorded in the ADR).

## Consensus render — the object of the yes

After the table converges (no open contradiction, unknowns dispositioned), and BEFORE the consequence probes,
render the `## Consensus` section as a pre-yes end-turn message: four subsections — Scope / Invariants /
Contract facts / Out-of-scope — every entry traced to its stable ids.

- **Presentation reuses the loaded `laydown-first-presentation.md`.** Delta: the full
  picture = the consensus section; the depth-tier axis is the entry's **load-bearing STATUS**
  — Scope / Invariants / Contract-facts entries full text, Out-of-scope entries one line —
  derived from the subsection, NOT a literal `load-bearing?` tag column (consensus entries
  carry `[trace:]`, not tags). The render covers exactly the four subsections, never the record's `## Deferred log`.
- **Render before persist.** The record's `## Consensus` is persisted only at/after the yes;
  being not yet persisted, the render's digest tier stays one-line inline rather than
  collapsing to a record-file pointer.
- **Re-render on a correction** (a falsified probe, or a correction at the readiness ask):
  re-converge and re-render on the corrected state — the eventual yes never lands on a stale render.

## Consequence probes — alignment made falsifiable

Immediately after the consensus render and BEFORE any readiness ask, publish consequence
probes: behavior forecasts the human can falsify — each a concrete "I will X / never Y /
under pressure sacrifice Z first". Floor: ≥1 probe per load-bearing ruling (a human-confirmed
resolution of a row tagged load-bearing; deferred rows never count), minimum one; each probe
names its source row / ruling by stable id. A falsified probe folds back into the table,
re-converges (new rows may reopen extraction), re-renders the consensus, and fires a fresh probe
round; readiness is NOT asked on the corrected round.

## Readiness — explicit yes + a clean probe round

Criterion: every load-bearing known unknown resolved or flip-triggered (NOT "all cells filled";
NOT "zero unknowns") AND the latest probe round had zero corrections — an ambiguous probe answer
counts as a correction and folds back. Not ready → run the cheap probe(s), return to the table,
re-converge. The readiness ruling cites the explicit yes and the clean round's dated `R-n` id;
the ask refers the human to the pre-yes consensus render as its object.

**The human rules readiness once.** Guard with the non-yes taxonomy:

- "whatever you think" = delegation → re-ask with two concrete options.
- "sounds good" = ambiguous → ask what they would refine.
- silence + "let's start" = abandonment → stop; ask what is missing.
- an explicit correction → fold into the table, re-render the consensus, restate, loop.
- Only an explicit yes advances.

## Durable record — the terminal deliverable

Write `<epics-dir>/<slug>/assay-<YYYY-MM-DD>-<subject>.md` — frontmatter `subject:` (one line;
the contract author maps intention from it), `date:`, `epics:`. One record per subject; a
re-run APPENDs a new dated section, never overwrites. Sections, order fixed — consumers key on these names:

- `## Term sheet` — rows `T-n`
- `## Alignment table` — rows `A-n`: dual tags + leaning + planned handling; bold-pass rows marked
- `## Extraction Q&A` — rulings `Q-n`; predict / probe rounds `R-n` (dated)
- `## Consensus` — four subsections: Scope / Invariants / Contract facts / Out-of-scope;
  every entry ends with `[trace: <stable-ids>]` (comma-separated) — stable ids only
- `## Flip-trigger registry` — observable signal + revisit point per row
- `## Deferred log` — the non-load-bearing unknown stubs
- `## Readiness ruling` — explicit yes + date + the clean round's `R-n`
- `## Deviation log` — appended during downstream execution: gap / quadrant / which-stage-could-have-caught / catcher

**The consensus section IS the handoff** — an implementation of the confirmed-facts source
contract (`skills/_shared/inject/confirmed-facts-source.md`). The contract author derives Scope /
Invariants facts from Consensus rows and itself authors the seam / AC layer — assay emits no
contract-material packaging beyond the consensus section, no acceptance-seam skeletons. With no
contract downstream, the record as produced IS the terminal deliverable. Every disposition names
its file (and line/anchor where applicable) so a later session executes it without re-derivation.

## Honest ceiling

assay's done-claim is accounting-completeness: entries falsifiable, unknowns dispositioned,
alignment evidenced by a published clean probe round, human explicit yes. The interview NARROWS
unknown-unknowns; it never proves them zero. Gap size is measured downstream by the deviation log — never claimed at interview end.
