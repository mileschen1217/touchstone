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

One fused interview session aligning human and AI across three arms — vocabulary, map, territory (each below). Terminal deliverable: the durable record's `## Consensus` section, every entry traced to a row the human confirmed in-session.

**Live user required.** In a non-interactive context (CI, a loop, a scheduled run), do NOT guess-fill an answer: flag a blocker naming assay, and stop.

**Unformed-intent escape.** If extraction cannot elicit a stateable intent, recommend an out-of-band `superpowers:brainstorming` run (steering, not a dependency) and halt — never interview toward an intent the human does not yet hold.

**Inputs.** A sharpened intent plus explore findings already in context (explore always precedes assay — you cannot lay out assumptions about an undrawn map), and the parent epic directory path (the record's home). No parent epic → ask; never silently pick.

## Presentation

Every turn — laying out the map or running extraction — follows four rules:

1. **Index + top stratum.** One-line index of every row (grouped by arm, badged with its tags), then full text for only the top-impact stratum — about 5±2 rows, the ones most expensive to get wrong — plus 2-3 AI-recommended discussion entry points, each with a one-line reason. The human may expand any other row by naming it.
2. **Record is the full-text home.** The durable record carries every row's full text, written before or together with the message — never only in the message.
3. **Waves.** The top stratum resolves → the next stratum gets full text. A resolved row collapses to a one-line digest. While grilling, re-present only what changed.
4. **Status line.** Close every turn with `resolved n / open n / new n`.

## Vocabulary arm — term sheet

Open the alignment table with a term sheet covering the session's key terms, pre-existing and session-coined alike. Each row MUST carry:

- a **self-contained working definition** — readable without this session's context; define a term before any other row uses it; never a self-coined code label.
- exactly ONE **source marker**: doc-grounded / session-coined (AI or human) / ledger-conflict. A conflict with CONTEXT.md or project docs ALSO enters the alignment table as its own assumption row, routed through disposition like any other.

The sheet is a working surface, not a new authority ledger: a pre-existing term keeps its source of truth in CONTEXT.md or the project's docs; a session-coined term writes back only past that material's admission boundary.

## Map arm — AI-side laydown

Lay out every assumption you would otherwise silently adopt. Each entry MUST:

- **be falsifiable** — name a concrete file, interface, or behavior; rewrite a vibe sentence until a probe could prove it wrong. A conflict with CONTEXT.md or a project ADR IS an assumption, its own row.
- **be ordered by architectural impact** — most expensive-to-change first.
- **carry both tags** — `load-bearing?` (does the design collapse if this is wrong) and `probe-cost` (how expensive to verify). `deferred` handling ⟺ `load-bearing? = no`.
- **carry your leaning** — the disposition you would bet on, with a one-line reason; the human reacts to a stated position instead of authoring one from scratch.

**Bold pass (unconditional).** Also lay out the structurally-larger moves you suppressed under conservative bias, ordered by blast radius. "Change nothing structural" is itself an assumption — an empty bold section is permitted ONLY as the explicit line "no suppressed structural moves". Bold items enter the same unknown disposition as any other row. A small subject compresses rounds and merges tables, but never skips the bold pass's explicit empty-section line.

## Map arm — human-side extraction

Ask questions in the laydown's architectural-impact order, targeting tacit knowledge ONLY: intent, priority, unstated constraints, what done looks like. Do NOT ask architecture or API design questions — that design work is yours. A fact the repo or its docs can answer (the **territory arm**) is yours to look up, never the human's to be asked — a repo claim you make follows the grounded-claims citation discipline; bring the human only decisions and tacit knowledge.

- Ask exactly ONE question per message; every question carries your own leaning and a one-line reason.
- Enumerable answers go through AskUserQuestion with your leaning marked "(Recommended)" — one call, one question.
- Speak plainly: no skill-internal section names, no self-coined code labels. Refer to a table entry by a content phrase — a stable-id handle beside the phrase is fine — never by row number alone.

Named instrument — the **want-vs-should-want probe**: "if you didn't have to justify this choice to anyone, what would you actually want?" It catches sophistication-signaling answers.

**Loop rule.** An extraction answer may flip an existing row OR add wholly new ones — update the table and re-converge in-session; never carry a known contradiction forward.

**A published predict round closes questioning — every path.** When you can predict the user's answers to the next three questions (fewer left → all remaining), publish the round: each remaining question WITH your predicted answer; an empty queue is published as an explicit empty-queue statement. Questioning closes only after the user confirms; a missed prediction reopens that question (a user correction likewise reopens the queue), and a later published round must pass before questioning may close again. Each round — predict or probe — takes the next id in a SINGLE dated sequence of `R-n` ids (one shared counter).

## Territory arm — seam-map on a cross-boundary artifact

The territory arm looks up repo facts the human is never asked. One territory fact is
**load-bearing for reach**: when the intent changes a **cross-boundary artifact** (the
term is homed in `reach-discovery.md`) — one that crosses an actor/module boundary such
that **>1 party** must agree on it, decided by party-count rather than by file type —
the AI SHALL produce a **saturated seam-map** via
`${CLAUDE_PLUGIN_ROOT}/skills/_shared/reach-discovery.md` and carry it into Consensus
Scope. When the intent changes only single-party artifacts (an
ordinary one-consumer file edit), no seam-map is required — the negative branch is
reachable and stays cheap.

- **Saturation** is the multi-channel plateau the method (`reach-discovery.md`) applies —
  swept via ≥2 orthogonal channels; a single-search first-hit is not a seam-map.
- **Sub-floor (a channel unavailable — shallow clone / no history).** Declare the
  unavailable channel in the seam-map. With ≥2 channels still available, absence does
  not block reaching the plateau over the available channels (declared, not silently
  skipped). With **fewer than 2** channels available, the plateau is unobservable: mark
  the seam-map **reach-under-determined** and carry it to the human with that limitation
  stated — never render it as a confident plateau.

## Unknown disposition

A known unknown enters from three sources — laydown residuals (rows neither confirmed nor flipped), future-observable items, unresolved bold-pass items. Route EVERY one through:

| load-bearing | probe-cost | disposition |
|---|---|---|
| yes | cheap | **probe now** (spike / mock / reference-check / ask) |
| yes | expensive | **flip-trigger bypass** or scope cut — never silent proceed |
| no | — | deferred log |

**Structural fork case** — a fork entry with ≥2 viable approaches and durability stakes: author an ADR per `adr-authoring.md` (same directory) with the flip-trigger, bet-owner, and assumptions fields, the human as bet-owner; grade it against `references/arch-rubric.md`. For a fork worth critique evidence, dispatch `touchstone:cross-provider-reviewer` (internal role `architecture-critique`) — adaptable, omit only with the reason recorded in the ADR.

## Consensus render — the object of the yes

After the table converges (no open contradiction, every unknown dispositioned) and BEFORE the consequence probes, render the `## Consensus` section as a pre-yes end-turn message: four subsections — Scope / Invariants / Contract facts / Out-of-scope — every entry traced to its stable ids (`[trace: <ids>]`).

- Reuse the Presentation rules above; the depth-tier axis here is the entry's load-bearing STATUS — Scope / Invariants / Contract-facts entries get full text, Out-of-scope entries get one line. The render covers exactly the four subsections, never the record's `## Deferred log`.
- **Seam-map in Scope (triggered intent).** When the intent changed a cross-boundary artifact, the Scope carries its saturated seam-map as `artifact → {party: file:line}` entries, each ending with a `[trace:]` to its confirmed row. A **zero-party** result — the sweep found no other party — is NOT dropped: it lands as an explicit `no other parties (swept via <channels>)` Scope entry (a valid zero-party plateau), so a mis-fired trigger (an artifact that was not actually cross-boundary) stays visible for review.
- **The seam-map baseline is human-confirmed.** The plateau-declared seam-map becomes a verify-against baseline for any downstream stage ONLY after the human confirms it at the readiness yes (the standard Consensus yes covers it). That human yes on the seam-map — not the sweep alone — is the ratchet (INV-5).
- **Render before persist.** The record's `## Consensus` section is written only at or after the yes; while not yet persisted, keep the render's digest tier inline rather than collapsing to a record-file pointer.
- **Re-render on a correction** (a falsified probe, or a correction at the readiness ask): re-converge and re-render on the corrected state — the eventual yes never lands on a stale render.

## Consequence probes — alignment made falsifiable

Immediately after the consensus render and BEFORE any readiness ask, publish consequence probes: behavior forecasts the human can falsify — each a concrete "I will X / never Y / under pressure sacrifice Z first". Floor: ≥1 probe per load-bearing ruling (a human-confirmed resolution of a row tagged load-bearing; deferred rows never count), minimum one; each probe names its source row or ruling by stable id. A falsified probe folds back into the table, re-converges (new rows may reopen extraction), re-renders the consensus, and fires a fresh probe round; readiness is NOT asked on the corrected round.

## Readiness — explicit yes + a clean probe round

Criterion: every load-bearing known unknown resolved or flip-triggered (NOT "all cells filled"; NOT "zero unknowns") AND the latest probe round had zero corrections — an ambiguous probe answer counts as a correction and folds back. Not ready → run the cheap probe(s), return to the table, re-converge. The readiness ruling cites the explicit yes and the clean round's dated `R-n` id; the ask refers the human to the pre-yes consensus render as its object. For a triggered cross-boundary-artifact intent this same yes is the human confirmation of the seam-map baseline (the ratchet, INV-5) — no downstream stage consumes the seam-map as a verify-against baseline before it.

**The human rules readiness once.** Anything short of an explicit yes is not-ready — name the specific gap the non-answer signals and return to it, never round a soft or delegated reply up to consent. A delegation ("whatever you think") gets re-asked with two concrete options; an explicit correction folds into the table, re-renders the consensus, restates, loops. Only an explicit yes advances.

## Durable record — the terminal deliverable

Write `<epics-dir>/<slug>/assay-<YYYY-MM-DD>-<subject>.md` — frontmatter `subject:` (one line; the contract author maps intention from it), `date:`, `epics:`. One record per subject; a re-run APPENDs a new dated section, never overwrites. Sections, order fixed — consumers key on these names:

- `## Term sheet` — rows `T-n`
- `## Alignment table` — rows `A-n`: dual tags + leaning + planned handling; bold-pass rows marked
- `## Extraction Q&A` — rulings `Q-n`; predict / probe rounds `R-n` (dated)
- `## Consensus` — four subsections: Scope / Invariants / Contract facts / Out-of-scope; every entry ends with `[trace: <stable-ids>]` (comma-separated) — stable ids only. A triggered cross-boundary-artifact intent's Scope carries the seam-map as `artifact → {party: file:line}` entries (a zero-party plateau rendered explicitly)
- `## Flip-trigger registry` — observable signal + revisit point per row
- `## Deferred log` — the non-load-bearing unknown stubs
- `## Readiness ruling` — explicit yes + date + the clean round's `R-n`
- `## Deviation log` — appended during downstream execution: gap / quadrant / which-stage-could-have-caught / catcher

**The consensus section IS the handoff** — an implementation of the confirmed-facts source contract (`skills/_shared/inject/confirmed-facts-source.md`). The contract author derives Scope and Invariants facts from Consensus rows and itself authors the seam / AC layer — assay emits no contract-material packaging beyond the consensus section. Every disposition names its file (and line or anchor where applicable) so a later session executes it without re-derivation.

**Honest ceiling.** The interview narrows unknown-unknowns; it never proves them zero. Gap size is measured downstream by the deviation log — never claimed at interview end.
