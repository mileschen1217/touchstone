---
name: arch-discovery
description: |
  Architecture discovery skill for system definition. Sits between
  exploration (Stage 1) and design spec (Stage 3) when behavior,
  ownership, invariants, and platform constraints all need to be
  aligned before a contract can be written. Especially fits networking,
  embedded, and hw-sw co-designed systems. Produces a single monolithic
  E2E-spine doc; completeness is enforced by a features × lenses
  coverage matrix maintained in §0 of the doc itself.
allowed-tools: [Bash, Read, Write, Edit, Grep, Glob, Skill, Agent]
kind: workflow
---

# m-arch-discovery

Mid-discovery system-definition skill. The doc it produces describes end-to-end behavior, ownership model, invariants, state distribution, flows, lifecycle, and platform constraints — without committing to implementation.

## When to Invoke

Invoke when ALL are true:
- Exploration has produced findings; the problem domain is mapped.
- The system involves multiple interacting actors / state holders, not a single-module change.
- Stakeholders include "ownership / authority" questions that cross components (who programs what, who is canonical for which state).
- A design spec cannot be written yet because the system model itself is still being aligned.

Especially valuable when:
- Hardware / ASIC / runtime constraints must be reasoned about alongside software behavior.
- Failure semantics (failover, partition, fault) need to be made explicit before contracts are committed.
- Multiple features interact and cannot be designed in isolation.

Skip when:
- Single-feature change inside a settled architecture.
- Spec writer can confidently state ownership/invariants from existing docs.
- The project already has a discovery doc on a comparable feature.
- The decision needed is binary "approach A vs B" → use `/touchstone:arch-review`.

## Setup Mode

Triggered when the topic doesn't yet have a discovery doc.

> Read `${CLAUDE_PLUGIN_ROOT}/skills/_shared/step0-resolver.md`
> with the Read tool and follow it exactly.

Source the output directory from `bundle.research` (the resolver's bundle). Interactive flow:
1. Create `<bundle.research>/<topic>/` if missing.
2. Copy template to `<bundle.research>/<topic>/YYYY-MM-DD-<slug>-discovery.md`.
3. **Verify frontmatter contract** — the new doc MUST carry `type: discovery` in its frontmatter (the template provides it; do not strip it). This is a load-bearing cross-skill contract: `/touchstone:design-review` recognizes discovery docs by `type: discovery` (or by path matching `**/research/**/*-discovery.md`, but the type field is authoritative). Without it, the end-of-discovery audit gate returns "out of scope" and the doc cannot be handed off to `/touchstone:design-spec`. If your `bundle.research` does NOT match the path glob (e.g. you chose `.touchstone/arch/` instead of `.touchstone/research/`), the `type: discovery` frontmatter is the *only* signal `/touchstone:design-review` will see — preserve it carefully.
4. Bootstrap §0 matrix: rows from user's initial feature list (if provided), full L1–L16 columns, all cells `unset`.
5. Add frontmatter `epics: [<slug>]` if a matching epic index exists under the project's epic dir (per CLAUDE.md § Doc Routing). Adds alongside the mandatory `type: discovery` — does not replace it.
6. **Show the author a worked exemplar before drafting.** This is the cheapest defense against the "bullets-only first draft" failure mode. Two paths:
   - **Preferred (when an exemplar exists)** — `${CLAUDE_PLUGIN_ROOT}/skills/arch-discovery/exemplar/` holds a canonical realized §1.1 / §1.2 / §1.3 trio. Read it. The author opens Discovery Mode having *seen* the target shape (Narrative paragraphs → Mermaid diagram → Claims), not just having read instructions to produce it.
   - **Fallback (no exemplar yet)** — surface a 1-screen synthetic excerpt inline in the chat that demonstrates the Narrative + Diagram + Claims shape on a generic topic (e.g. a 2-actor system). The author calibrates on tone and density before authoring §1.
   Either way, the exit criterion is: "the author has seen, in this session, what a fully-realized §1.X looks like." Skipping this step reliably produces an axiom-list first draft that costs 1–2 iterations to recover from.
7. Hand off to Discovery Mode.

## Discovery Mode

The interactive scaffold.

Inputs to collect:
1. **Topic slug** — kebab-case; names the deliverable surface, not a phase.
2. **Initial feature list** — what observable units does the discovery cover? (Example for L3 stacking: `vlan-membership`, `arp`, `svi`, `connected-route`, `failover`.)
3. **Known constraints** — any hard external constraints to bake into §2 platform behavior up front (example: "Marvell CPSS 4.3.16 SDK, Prestera DX ASIC family").
4. **Carry-over material** — paths to existing exploration notes that should seed sections.

Drafting workflow:
1. **Read** template from `${CLAUDE_PLUGIN_ROOT}/skills/arch-discovery/template.md`, lenses from `${CLAUDE_PLUGIN_ROOT}/skills/arch-discovery/lenses.md`, and coverage-matrix from `${CLAUDE_PLUGIN_ROOT}/skills/arch-discovery/coverage-matrix.md`.
2. **Read** carry-over material; map each chunk to (section, lens) cells.
3. **Draft §1 system model first** — roles, ownership, invariants. Without this, downstream sections have nothing to cite. Every section follows the **Narrative → Diagram → Claims** shape spelled out at the top of `template.md`. Bullet-only sections are a defect — they read as axiom lists and lose the human-alignment audience.
4. **Draft §2 platform behavior surface** — explicit capability / constraint / forced-behavior layout. For embedded / ASIC systems, this is load-bearing; do not skip.
5. **Draft §3 state, §4 flows, §5 lifecycle, §6 failures, §7 interfaces** incrementally; each section cites §1 and §2.
6. **Update §0 matrix continuously.** Every cell either points to a section (`covered`) or carries `gap` / `deferred (→ pointer)` / `N/A (rationale)`.
7. **Status** stays `Status: Discovery (in progress)` until a sweep pass returns no `gap` cells.
8. **Stranger-read pass before status promotion.** Before flipping to `matrix-complete`, re-read the doc top-to-bottom as if seeing it for the first time. For each section ask: (a) does the Narrative actually motivate the Claims, or is it preamble that could be deleted? (b) does the Diagram add a shape the prose can't? (c) do the Claims read as falsifiable, or as vague aspirations? Any section that fails one of these gets fixed before promotion — not deferred. This is the cheapest defense against shipping a doc that is correct and unreadable.

## Sweep Mode

Iterative completeness pass over the §0 matrix. Driven by gaps in the matrix itself, not by external review.

Procedure (codified in `coverage-matrix.md`):
1. Read §0 matrix.
2. For each cell whose state is `unset` or `gap`:
   - Present the (feature, lens) intersection
   - Ask: investigate now / defer with pointer / mark N/A with rationale / skip
   - On `investigate now`: dispatch the right helper (Explore, grep, `/touchstone:arch-review`, Context7, web), capture the finding into the appropriate section, update cell state to `covered (§X.Y)`.
   - On `defer`: capture concrete pointer; update cell.
   - On `N/A`: capture one-sentence rationale; update cell.
3. Iterate until matrix has no `unset` or `gap`.
4. Discovery is "matrix-complete" when every cell is `covered (cite)`, `deferred (pointer)`, or `N/A (rationale)`.

Sweep converts reactive gap-filling into a deliberate observable process. Run many times during a discovery's lifetime.

## End-of-discovery review

External audit is **not** a mode of this skill — it lives in `/touchstone:design-review`, which recognizes `type: discovery` (or path matches `**/research/**/*-discovery.md`) and applies a discovery-specific system prompt (audit ownership/invariants, platform-layer separation, E2E flows, lifecycle re-walk, failure coverage, matrix completeness, hidden open questions).

Sweep is the *internal* completeness mechanic (Discovery owns it). The external quality gate lives in `/touchstone:design-review`. Different purposes, different cadence:

| | Sweep (this skill) | `/touchstone:design-review` |
|---|---|---|
| Purpose | Iterate matrix to completeness | Independent audit of assembled doc |
| Driven by | Empty/gap cells in §0 | Outside critique |
| Cadence | Frequent — every authoring session | Major checkpoint / pre-handoff to `/touchstone:design-spec` |

Run `/touchstone:design-review <discovery-doc-path>` once the matrix is complete. Critical/High findings block hand-off to `/touchstone:design-spec`.

## Matrix Mode

Display-only. Renders the §0 matrix in a compact summary, color-coded by cell state. Useful for quick "where are we" checks without opening the full doc.

## Usage

```
/touchstone:arch-discovery setup                          # bootstrap config + first doc
/touchstone:arch-discovery <slug>                         # interactive scaffold or resume
/touchstone:arch-discovery <slug> sweep                   # iterate matrix gaps
/touchstone:arch-discovery <slug> matrix                  # display matrix only
```

For end-of-discovery audit, hand off to: `/touchstone:design-review <discovery-doc-path>`.

### Argument parsing

Parse left-to-right:
1. If first token is `setup` → run Setup Mode and exit.
2. Next non-keyword token (not `sweep` / `matrix`) → `topic_slug`.
3. If `sweep` / `matrix` appears → run that mode.
4. If no mode specified → Discovery Mode (scaffold or resume).

## Output

- `<discovery_dir>/<topic>/YYYY-MM-DD-<slug>-discovery.md` (the doc)
- Status header lifecycle: `Discovery (in progress)` → `Discovery (matrix-complete)` → `Discovery (reviewed)`. Manual transitions on user approval; the skill does not auto-promote.
- Sibling ADRs in project's ADR dir for any decisions surfaced during sweep.

## Related

- Bundled inputs (read by Discovery Mode): `template.md`, `lenses.md`, `coverage-matrix.md`.
- Workflow slot, sibling-skill integration table, and authoring anti-patterns: `README.md`.
