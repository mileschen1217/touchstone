---
kind: workflow
adr_id: 0024
status: Accepted
date: 2026-06-25
supersedes: 0012
kill-on: a-real-bidirectional-tracker-consumer-appears
---

# ADR-0024: The agent is the shim — epic-tracker portability by one-way projection, not a storage adapter

## Status

Accepted. Decided during Stage 1.5 grill-with-docs for Phase 2.11 of the
`skill-ceiling` epic. **Supersedes ADR-0012** (canonical-form storage adapter
contract), whose adapter was implemented but never gained a second backend or an
external consumer.

## Triggered by

Phase 2.10's content-level first-principles audit (finding 10) flagged the
`epic-driven-roadmap` storage adapter as premature abstraction: ~1100 LOC of
canonical-form / sidecar / shim code (plus ~960 LOC of adapter-internal tests and
golden fixtures) serving **one** backend (local-markdown) with **zero** external
consumers, justified by hypothetical GitHub / Obsidian / Linear futures.

## Context

ADR-0012 split `epic-driven-roadmap` into a procedure layer (SKILL.md prose) and
a storage adapter layer (deterministic script), communicating through a versioned
canonical `EpicData` form. The adapter was a **bidirectional** shim: `read(slug)
→ EpicData`, `write(slug, EpicData)`, with schema validation on read and
loud throws when a backend could not hold a field. The entire machinery —
schema, sidecar passthrough, round-trip golden tests — exists to serve **one
requirement: lossless bidirectional round-trip of every field through any
backend**, so a configured backend could *be* the source of truth.

Two facts undercut that requirement on this substrate:

1. **The LLM agent natively reads and writes any format.** It does not need a
   coded shim to turn a markdown index into a GitHub Issue body or back — that
   conversion is exactly what the agent does. The adapter re-implements, in
   ~1100 deterministic lines, a capability the substrate already has.

2. **No tracker is ever the authoritative author of epic structure.** In real
   use the developer and the agent both edit the local `.md`; the shared tracker
   (already driven by `gh`, never by the adapter) is a downstream broadcast. The
   bidirectional, swap-the-live-backend model was never exercised — and it
   re-introduces the dual-home / drift the adapter was meant to prevent.

ADR-0012 rejected "LLM parse in the procedure layer" because a missing field
could silently become `None` and mis-judge the close gate — a silent
false-green at the storage boundary. That fear was specific to a **second
backend silently dropping a field across a round-trip**. With **one local home
and no swap**, that failure mode does not exist: the close gate reads the same
`.md` a human reads; there is no second representation to lose fidelity against.

## Decision

1. **The agent is the universal shim — both directions.** Remove the storage
   adapter, canonical-form schema, sidecar passthrough, the selector, the
   adapter CLI, the conftest registration, and all adapter-internal tests and
   golden fixtures. No coded shim sits between the skill and any backend.

2. **Portability = one-way projection.** The local markdown index
   (`.touchstone/epics/<slug>/index.md`) is the single source of truth for
   work-content. A tracker card (GitHub / GitLab Issue, Jira, Linear) is a
   **projection** — the agent renders the index's *shared subset* (aim,
   phases-as-checklist, status, back-link) onto the card at need. Close-only
   internal artifacts (retrospective, Doc Reckoning, Evidence
   Reckoning) are not projected. Prefer reusing a community render skill (e.g.
   `to-github-issue`); for GitHub, inline `gh issue create` may suffice. Do not
   pre-build Jira / GitLab / Linear renderers until a real consumer exists.

3. **Reverse reconciliation, if ever needed, is also the agent's job —
   semantically, not as a contract.** If a tracker edit must flow back, the
   agent fetches tracker state via `gh` / CLI / MCP, diffs it against the local
   index, and updates the index. No schema, no round-trip guarantee.

4. **The only deterministic per-tracker artifact is a field-location mapping** —
   a small declarative table of where each index field lives on a platform
   (which API field / card location). It keeps field retrieval unambiguous
   during projection / reconciliation. It is a lookup table, not a round-trip
   adapter, and is authored per-platform only when that platform gains a real
   consumer.

5. **The local-side deterministic floor stays — and is where the behavioural
   guarantee now lives.** The adapter gave a *scriptable* close that a unit test
   could drive and check. With the adapter gone the close is *agent-performed*
   (prose), which no test can drive — so the behavioural guarantee that close
   actually stamps `landed` / marks phases done **shifts** from "a test drives the
   close" to "**a close-check gates the agent**": at close the agent runs a
   mechanical check (status ∈ enum; `started` present; `landed` is `YYYY-MM-DD`
   when done; exactly one Phases table with ≥1 row; every phase done) and **shows
   its output** as the evidence (claim ≤ evidence). If the agent forgot to stamp a
   field, the check fails loud and close cannot be claimed — that is the floor,
   not a procedure-driving test. The check is a **thin, read-only helper** (header-
   driven Status lookup, ~tens of lines), and it must be a real invocable artifact
   so that (i) the close prose can run it and (ii) negative fixtures can test it.
   This is **not** a return of the adapter: the prohibition is on a *storage
   adapter* (typed parse + schema + sidecar + bidirectional round-trip), not on a
   small gate-input check. The remaining tests are **structural / contract** —
   they verify the template parses, fields are extractable, and the check accepts
   a valid closed index and rejects malformed ones; they do NOT claim to witness
   the agent performing a close. The floor also doubles as a generation
   forcing-function: a missing field fails the check, so the agent must fill it.

6. **Keep the canonical-minimum discipline as template-field design.** ADR-0012's
   load-bearing review test survives, reframed: every field in the index
   *template* must answer "which gate reads this?" — if none, it does not belong
   in the gated template. This is now single-home template-design discipline,
   not a cross-backend contract.

## Consequences

**Positive**

- **~2000 LOC removed** (adapter source + adapter-internal tests + golden /
  error fixtures), plus the selector, the prose-purity CLI assertion, and the
  conftest registration. The skill writes its index directly.
- **Honesty preserved at lower cost.** One home + the gate reading the same
  `.md` a human reads eliminates the cross-backend silent-drop failure mode
  ADR-0012 feared; the surviving mechanical floor (template + structural tests +
  shown-output close check) carries the rest.
- **Portability is still real** — and cheaper, because projecting a shared
  subset one-way needs no parse, no schema-on-read, no unstorable-field throw.

**Negative / costs**

- **The (never-used) live-backend swap is gone.** If a genuine bidirectional
  consumer ever appears (a team that authors epic structure *in* a tracker and
  needs it as upstream truth), build a render skill + a field-location map for
  that platform then — `kill-on:` records this revisit trigger.
- **Reverse reconciliation is now agent-judgment, not a typed contract.** That
  is acceptable while no tracker is an upstream author; it is the same bet as
  the one-way decision.

## Alternatives considered

- **Keep the adapter as-is.** Rejected: one backend, zero consumers, ~2000 LOC
  for a capability the substrate has natively — textbook premature abstraction.
- **Shrink the adapter to one-way but keep a coded shim.** Rejected: still code
  for what the agent does natively; the projection is a render the agent
  performs, not a module.
- **Replace the adapter with a typed index-validator module/CLI** (a parser that
  deserialises the index into a typed record + schema). Rejected (grill option B):
  that re-creates a mini version of the adapter and over-specs a markdown plugin.
  The line is between a *typed storage parser* (rejected) and a *thin read-only
  close-check* (pt5, accepted): the latter greps a header-located Status column
  and a few frontmatter fields, holds no schema, and exists to gate the agent's
  close — it is the testable home of the mechanical floor, not a storage layer.
