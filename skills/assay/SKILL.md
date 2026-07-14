---
name: assay
description: |
  Pre-contract interview instrument — the fused single-session interview after explore and
  before the contract author: aligns human and AI across three arms — vocabulary (term sheet),
  maps (falsifiable laydown + bold pass, tacit-intent extraction, published predict round),
  territory (explore / grounded-claims wiring) — routes every known unknown through the
  unknown-disposition table (a structural fork produces an ADR), evidences alignment with
  human-falsifiable consequence probes, and terminates at the durable record's consensus
  section (every entry traced to a human-confirmed row), which the contract author consumes.
  Readiness = explicit yes + a zero-correction probe round. Requires a live responsive user;
  invoke inside crucible or directly before a contract. Out of scope — non-interactive/CI
  (no live user) or unformed intent (→ superpowers:brainstorming).
kind: workflow
---

<!-- keep-long: 232 lines. All main-path — the full interview procedure (vocabulary/map/territory arms, unknown-disposition, consensus render, consequence probes, readiness ask) is read every invocation; no orientation-only content to extract. Interim: an essence re-compression of the procedure prose is deferred to Phase 2 of alignment-surface-review-bandwidth (this build added the consensus-render step; token/essence audit folded there). -->

# /touchstone:assay — Pre-Contract Interview Instrument

One fused interview session that aligns human and AI on everything this topic touches, across
three arms: **vocabulary** — words carry the same self-contained working definitions; **maps** —
the human's picture and the AI's picture, laid open to each other and mutually predicted;
**territory** — both maps checked against the repo's actual state. The terminal deliverable is
the durable record's consensus section, every entry traced to a row the human confirmed
in-session. The human answers tacit-knowledge questions and rules readiness.

**Loading constraint — live user required.** In a non-interactive context (CI, a loop, a
scheduled run) do NOT guess-fill any answer: flag a blocker naming assay, and stop.

**Unformed-intent escape.** If extraction cannot elicit a stateable intent, recommend an
out-of-band `superpowers:brainstorming` run and halt assay — do not interview toward an
intent the human does not yet hold. (Not a dependency; the recommendation is steering.)

**Inputs.** Sharpened intent + explore findings already in context (you cannot lay out
assumptions about a map that has not been drawn — explore always precedes assay); the parent
epic dir path when one exists — the record's home. No parent epic → ask; never silently pick.

## Presentation protocol

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/inject/laydown-first-presentation.md`
> with the Read tool and follow it exactly.

assay's delta: the full picture is the complete alignment table — term-sheet rows (each
carrying its source marker) + assumption and bold-pass rows (each carrying its `load-bearing?`
× `probe-cost` tags) — every row also carrying its planned handling (will-ask / self-check /
residual→disposition / deferred); rows queued for extraction questioning count as awaiting the
human's attention in the fragment's depth tiering.

## Vocabulary arm — term sheet

The alignment table opens with a term sheet covering this session's key terms, pre-existing and session-coined alike. Each row MUST:

- carry a **self-contained working definition** — readable without this session's context;
  define a term before any other row uses it; never a self-coined code label.
- carry exactly ONE **source marker**: doc-grounded / session-coined (AI or human) /
  ledger-conflict.
- **ledger-conflict escalation** — a conflict with CONTEXT.md / docs usage ALSO enters the
  alignment table as its own assumption row, routed through disposition like any other.

The sheet is a working alignment surface, not a new authority ledger: pre-existing terms keep their
source of truth in CONTEXT.md / docs; session-coined terms live in the record and write back only
past CONTEXT.md's admission boundary (write-back rule, standing).

## Map arm — AI-side laydown (doc-grounded)

Lay out every assumption you would otherwise silently adopt. Each entry MUST:

- **be falsifiable** — name a concrete file / interface / behavior; rewrite a vibe sentence
  until a probe could prove it wrong. Check each assumption against CONTEXT.md / docs/adr —
  a conflict with that ledger IS an assumption, surfaced as its own row.
- **be ordered by architectural impact** — most expensive-to-change first.
- **carry both tags** — `load-bearing?` (does the design collapse if this is wrong) ×
  `probe-cost` (how expensive to verify). `deferred` handling ⟺ `load-bearing? = no` — the
  disposition routing the probe floor counts on.
- **carry your leaning** — the disposition you would bet on, with a one-line reason; the
  human reacts to a stated position instead of authoring one.

**Bold pass (unconditional).** Also lay out the structurally-larger moves you suppressed under
conservative bias, ordered by blast radius. "Change nothing structural" is itself an assumption. An
empty bold section is permitted ONLY as the explicit line "no suppressed structural moves"; silence is the violation. Bold items enter the same unknown disposition.

## Map arm — human-side extraction

Ask questions in the laydown's architectural-impact order, targeting tacit knowledge ONLY: intent,
priority, unstated constraints, what done looks like. Do NOT ask architecture / API design questions — that design work is yours; asking it reverses the responsibility.

- Ask exactly ONE question per message; every question carries your own
  leaning and a one-line reason.
- When the answer options are enumerable, ask through AskUserQuestion with your leaning
  marked "(Recommended)" — one call, one question (carrier limits: presentation protocol).
- Speak plainly to the user: no skill-internal section names, no self-coined code labels;
  refer to a table entry by a content phrase — a visible stable-id handle beside the phrase
  is fine — never by row number alone.
- Facts the repo or its docs can answer are yours to look up before asking (territory arm);
  bring the human only decisions and tacit knowledge.

Named instrument — **want-vs-should-want probe**: "if you didn't have to justify this choice to
anyone, what would you actually want?" It catches sophistication-signaling answers (scalable /
clean / modern offered as goals).

**A published predict round closes questioning — every path.** When you can predict the
user's answers to the next three questions (fewer left → all remaining), PUBLISH the round:
each remaining question WITH your predicted answer; an empty queue is published as an
explicit empty-queue statement — closing without a published round is not a path. Questioning
closes only after the user confirms. A missed prediction reopens that question for real
extraction (a user correction likewise reopens the question queue); a later published round
must pass before questioning may close. Each published round — predict or probe — takes the next id in a SINGLE dated sequence of `R-n` ids (one shared counter across both round types, never two per-type counters that could each emit `R-1`).

## Territory arm — wiring, not new mechanism

Explore findings are the laydown's map source; claims about repo behavior follow the
grounded-claims citation discipline. A row territory can settle is settled by lookup, never by asking.

## Four-quadrant accounting

| Quadrant | Disposition |
|---|---|
| known knowns | straight into consensus contract facts |
| known unknowns | one disposition row each |
| unknown knowns (human tacit) | extraction converts them to known knowns → contract facts |
| unknown unknowns | acknowledged to exist, never claimed zero; residual → review gates + deviation log |

**Loop rule.** An extraction answer may flip an existing table entry OR add wholly new entries —
update the table and re-converge in-session; never carry a known contradiction forward.
**Proportionality (steering, not a rule):** a small subject compresses rounds and merges tables but
never skips the laydown itself (the bold pass's explicit empty-section line stays); judge round count by blast radius.

## Unknown disposition

Known unknowns enter from three sources — laydown residuals (entries neither confirmed nor
flipped), future-observable items, unresolved bold-pass items. Route EVERY one through:

| load-bearing | probe-cost | disposition |
|---|---|---|
| yes | cheap | **probe now** (spike / mock / reference-check / ask) |
| yes | expensive | **flip-trigger bypass** or scope cut — never silent proceed |
| no | — | deferred log |

**Structural fork case** — a fork entry with ≥2 viable approaches and durability stakes: author an ADR
per `adr-authoring.md` (same directory), carrying the flip-trigger / bet-owner / assumptions fields,
with the human as bet-owner; grade the judgment against `references/arch-rubric.md`; for a fork worth
critique evidence, dispatch `touchstone:cross-provider-architect` (adaptable — omit with the reason recorded in the ADR).

## Consensus render — the object of the yes

After the table converges (no open contradiction, unknowns dispositioned) and
BEFORE publishing the consequence probes, render the `## Consensus` section as a
pre-yes end-turn message: the four subsections — Scope / Invariants / Contract
facts / Out-of-scope — every entry traced to its stable ids. This render is the
object the human's explicit yes lands on; the readiness ask refers the human to
it.

- **Presentation reuses the loaded `laydown-first-presentation.md`.** Delta: the
  full picture = the consensus section; the depth-tier axis is the entry's
  **load-bearing STATUS** — Scope / Invariants / Contract-facts entries (the
  load-bearing contract) get full text, Out-of-scope entries get one line —
  derived from the subsection and its traced source rows, NOT a literal
  `load-bearing?` tag column (consensus entries carry `[trace:]`, not tags). The
  render covers exactly the four `## Consensus` subsections; the record's
  `## Deferred log` is NOT part of it.
- **Render before persist.** The record's `## Consensus` is NOT written before the
  explicit yes — it is persisted only at/after the yes. Because the consensus
  content is not yet persisted at render time, the render's digest tier (the
  short Out-of-scope subsection) stays one-line inline rather than collapsing to a
  record-file pointer (the scale notch's not-yet-persisted case).
- **Re-render on a correction.** On any correction — a falsified probe, or an
  explicit correction at the readiness ask — the table re-converges and the
  consensus is re-rendered on the corrected state before the next readiness ask;
  the eventual yes never lands on a stale render.

## Consequence probes — alignment made falsifiable

After the table converges (no open contradiction, unknowns dispositioned) and BEFORE any
readiness ask, publish consequence probes: behavior forecasts the human can falsify — each a
concrete "I will X / never Y / under pressure sacrifice Z first". Floor: ≥1 probe
per load-bearing ruling (a human-confirmed resolution of a row tagged load-bearing; deferred
rows never count), minimum one; each probe names the table row / ruling it derives from by
stable id. A falsified probe folds back into the table, re-converges (new rows may reopen
extraction), re-renders the consensus (per the Consensus-render step), and fires a fresh probe
round; readiness is NOT asked on the corrected round.

## Readiness — explicit yes + a clean probe round

Criterion: every load-bearing known unknown resolved or flip-triggered (NOT "all cells
filled"; NOT "zero unknowns") AND the latest probe round had zero corrections — an ambiguous
probe answer counts as a correction and folds back. Not ready → run the cheap probe(s),
return to the table, re-converge. The record's readiness ruling cites both the explicit yes
and the clean probe round by its dated `R-n` id.
 The ask refers the human to the pre-yes consensus render as the object of the yes.

**The human rules readiness once.** Guard the ruling with the non-yes taxonomy:

- "whatever you think" = delegation, not a decision → re-ask with two concrete options.
- "sounds good" = ambiguous → ask what they would refine.
- silence + "let's start" = abandonment, not convergence → stop; ask what is missing.
- an explicit correction ("no, that's not it") → fold it into the table, re-render the consensus, restate, loop.
- Only an explicit yes advances.

## Durable record — the terminal deliverable

Write `<epics-dir>/<slug>/assay-<YYYY-MM-DD>-<subject>.md` — frontmatter `subject:` (one
line; the contract author maps intention from it), `date:`, `epics:`. One record per subject;
a re-run on the same subject APPENDs a new dated section, never overwrites. Sections, order
fixed — consumers key on these names; a rename is a breaking change:

- `## Term sheet` — rows `T-n`
- `## Alignment table` — rows `A-n`: dual tags + leaning + planned handling; bold-pass rows marked
- `## Extraction Q&A` — rulings `Q-n`; predict / probe rounds `R-n` (dated)
- `## Consensus` — four subsections: Scope / Invariants / Contract facts / Out-of-scope; every
  entry ends with `[trace: <stable-ids>]` (comma-separated, e.g. `[trace: A-2, T-3]`); stable ids
  only — a free-text row name is not a parseable trace
- `## Flip-trigger registry` — observable signal + revisit point per row
- `## Deferred log` — the non-load-bearing unknown stubs
- `## Readiness ruling` — explicit yes + date + the clean round's `R-n`
- `## Deviation log` — appended during downstream execution; the standing validity metric:
  gap / quadrant / which-stage-could-have-caught / catcher

**The consensus section IS the handoff.** The record is an implementation of the confirmed-facts source contract
(`skills/_shared/inject/confirmed-facts-source.md`). The contract author derives Scope / Invariants facts from Consensus rows and itself authors
the seam / AC layer — assay emits no contract-material packaging beyond the consensus section and
no acceptance-seam skeletons. With no contract downstream, the record as produced IS the terminal deliverable — no extra exit branch, no empty contract stub.

**Execution-precision.** Every disposition names its file (and line/anchor where applicable)
so a later session executes it without re-derivation; every flip-trigger names both an
observable signal and a revisit point.

## Honest ceiling

assay's done-claim is accounting-completeness: entries falsifiable, unknowns dispositioned, alignment
evidenced by a published clean probe round, human explicit yes. The interview NARROWS unknown-unknowns;
it never proves them zero. Gap size is measured downstream by the deviation log — never claimed at interview end.
