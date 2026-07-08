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

## Essence-rewrite methodology

How to slim an existing skill/agent md surface without changing behavior. The
target state is the two-sentence standard above; this section is the procedure
for getting an already-shipped file there. The surface-wide net-byte ratchet is
`scripts/check-md-surface-budget.sh` against `scripts/md-surface-baseline.txt`
— it runs inside the test suite, and you (the rewriting session / PR author)
run it and keep it green before push: any addition is funded by deletion in
the same PR.

### Fat classes

- **F1 — enumeration without principle.** ≥3 same-shape list items with no
  stated generating rule. Fix: state the rule once; keep 1–2 anchor examples
  explicitly labeled as examples, not rules; cut the rest.
- **F2 — repeated discipline.** The same rule restated at multiple points
  (within a file or across files). Fix: declare once at first use; later sites
  reference the declared term by name — a short pointer, never a paraphrase
  (a paraphrase is a second copy that drifts).
- **F3 — boundary-disclaimer density.** Per-item "this does NOT do X, that
  lives at Y" prose. Fix: one shared boundary line for the file.
- **F4 — README narration on an execution surface.** Mechanism / rationale /
  roadmap text that doesn't change what the executing agent does this run.
  Fix: move to `README.md` / `docs/` / `CONTEXT.md`.
- **F5 — verbatim duplication across files.** The same block in ≥2 files.
  Fix: one canonical home; every other site defers by reference.

### Essence-first procedure

1. Read the whole file; write its essence in ≤3 sentences: what must the
   executing agent do differently because this file exists?
2. Classify every paragraph against F1–F5. Each paragraph either survives
   (it changes what the agent does this run), moves to a single home with a
   pointer left behind, or is cut.
3. Rewrite from the essence — do not produce the new file by deleting lines
   from the old one (trimming preserves the old structure's fat). Then diff
   new against old for behavior: any semantic change beyond form is a
   halt-and-ask to the human, never a silent edit.
4. Verify: inbound references (section anchors, file paths other surfaces
   point at) still resolve; net bytes are down; the budget check is green.

### Incompressible content (never counts as fat)

- **Cold-dispatch prompts.** A cold-dispatched sub-agent sees only its prompt.
  Every definition, enum, and lens inside an embedded dispatch prompt stays
  inline and verbatim; a pointer never substitutes. Restating a rule inside a
  cold prompt that also exists elsewhere is required self-containment, not F2/F5.
- **Checkpoint safety belts.** A discipline declared once plus per-station
  one-line specialized checkboxes is already essence form: the station lines
  carry station-specific content and guard a long multi-stage run. Do not
  collapse them into the single declaration.
- **Parsed contract strings.** Sentinel lines, report fields, and schema blocks
  a downstream consumer parses byte-for-byte stay verbatim at every consuming
  site that needs them.

### Cluster co-rewrite rule

Files sharing an F5 block are one rewrite unit. Rewrite the whole cluster in
one pass, choosing one canonical home for the shared content; editing a single
member alone re-diverges the cluster immediately. (Worked examples of cluster
shape: an agent quartet sharing a contract glossary; a composite-skill pair
sharing a base procedure; a template and its workflow reference sharing field
rules.)

## Suite consistency layer

Suite-wide rules every skill in this plugin converges to; future audits diff
skills against this section.

### Frontmatter canon

| Field | Status | Semantics |
|---|---|---|
| `name` | official | Skill identifier; MUST match the skill's directory name. |
| `description` | official | Routing signal preloaded into context; the model reads it to decide when to invoke the skill. |
| `allowed-tools` | official | Restricts which tools the agent may use while the skill runs. |
| `user-invocable` | official | Whether the skill is exposed to the user as a slash command. |
| `disable-model-invocation` | official | Blocks the model from invoking or loading the skill on its own; user invocation only. |
| `kind` | non-official | Human-read suite convention (e.g. workflow); Claude Code ignores it. |

Official fields carry Claude Code's documented semantics; non-official fields
are suite-local conventions — mark any new non-official field as such in this
table.

### Suite rules

- **Negative routing.** Every skill's `description` or first body paragraph
  MUST name when NOT to use it (a "When NOT to use" / "Skip if" clause).
- **Live-human declaration.** A skill that requires a live responsive user
  MUST declare that loading constraint at the top of its body, before any
  procedure.
- **Thin-wrapper pattern.** An entry-alias skill (body = a few forwarding
  lines) sets `disable-model-invocation: true`. Allowed ONLY for newly created
  entry skills; NEVER retrofit onto a composite that another skill or agent
  invokes via the Skill tool — the field blocks ALL model loading, including
  legitimate chain calls, and severs the chain. Discriminator (grep-testable):
  the skill's name appears in any other skill/agent body as an invocation
  instruction → it is an in-chain composite → the field is forbidden.
  Dual-role skills (directly invocable AND chain-called) default conservative
  → forbidden.
- **Bounded examples.** An example is allowed only where it specifies an
  abstract rule or a render/output format; ≤1 example per site; label it as
  an example, not a rule. Larger examples move to `references/` satellite
  files. (The parsed-contract exception above stands: byte-exact contract
  strings appear verbatim wherever consumed.)
- **Self-describing names.** Internal section/stage names MUST be functional
  self-descriptions; opaque codes (bare stage numbers, letter suffixes) are
  banned. Coin a term only when a cross-reference genuinely needs one, and
  define it inline at first occurrence.
