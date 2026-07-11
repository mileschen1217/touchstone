---
injected-by: [design-spec, crucible]
referenced-by: [assay]
---

# Confirmed-facts source (shared contract)

The qualification contract for any source of human-confirmed facts that a
contract author (a spec, a PRD+seams light contract) consumes. A consumer
loads this file and follows it, carrying only its own delta — it never
restates these rules.

## Qualification (all three parts required)

1. A **marked confirmed-facts area** — the source designates which of its
   content is confirmed fact (not draft, not commentary).
2. A **stable per-fact citation** — each fact in that area is addressable by
   a stable id or anchor a consumer can cite.
3. A **human confirmation event stamp** — the source records the event where
   a human confirmed the area's content (e.g. a readiness ruling, a scaffold
   confirm).

An assay record's `## Consensus` section and an epic index's `## Foundation`
are two example implementations — examples only, never the qualifying
condition. Any source meeting the three parts qualifies, whoever produced it.

## Citation granularity (two levels)

- **field-level** — the confirmation stamp covers a whole marked block with
  no per-row ids (e.g. an epic index `## Foundation`). Feeds **Foundation
  fields only**; the citation resolves to the section.
- **row-level** — each fact carries a stable id (e.g. `[trace: A-2, T-3]`).
  Required for **contract-body facts** (Scope / Invariants /
  interface-contract facts); each adopted fact carries its `[trace: <id>]`.

A field-level source offered for a contract-body fact routes through the
failure disposition below — it never enters silently.

## Consumer obligations — never silent

Validate every adopted fact: its citation resolves and points to a
human-confirmed row (or, at field-level, a human-stamped block). Failure
triggers (stable names):

- **absent** — the fact is needed but no confirmed row in any supplied
  source carries it.
- **contradict** — the fact contradicts a confirmed row (including a
  conflict between two supplied sources).
- **missing** — the fact carries no citation at all (its own case, not a
  sub-case of unparseable).
- **unparseable** — a citation is present but cannot be resolved.

Every trigger disposes the same way: ask the human, or enter the fact only
as a `[NEEDS CLARIFICATION]` marker — never a silent adoption, never a
silent overwrite of a row the human confirmed. Foundation is not exempt:
with no qualified source, Foundation content is confirmed with the human
in-session (field-level evidence suffices) — never silently copied from
unconfirmed material.

## Naming

This artifact class is named **"confirmed-facts source"** — never a seam
("acceptance seam" keeps its own meaning).
