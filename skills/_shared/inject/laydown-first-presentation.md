---
injected-by: [assay]
---

# Laydown-first presentation (shared protocol)

Presentation rules for interactive skills that lay a full picture before the
human. A consumer loads this file and follows it, carrying only its own delta
(what its "full picture" contains) — it never restates these rules.

## Carrier rules

- Full-picture content travels on exactly two carriers, together: (1) an
  **end-turn plain-text message** — the turn's final text, after all tool
  calls — and (2) a mirror into the consumer's **durable record** file.
- Never carry load-bearing content ONLY in text emitted before a tool call
  or in AskUserQuestion option previews — both are known non-universal
  carriers (some client surfaces do not display them).

## Full picture before per-item

- Present the COMPLETE picture in one message before any per-item
  discussion; the human chooses what to discuss — the AI never pre-selects.
- While the human grills or adds rows: answer, fold changes into the
  picture, re-present the delta — still no per-item questioning.

## Tiered depth

- The end-turn message is **coverage-complete** — every row of the full
  picture is present — with depth tiered by ONE principle: a row still
  awaiting the human's ruling or attention this turn gets **full text**
  (anchor examples: a row about to be questioned, a row conflicting with
  the human's existing ledger, an AI-proposed larger move — examples, not
  an exhaustive rule); a resolved row gets a **one-line digest** (anchor
  examples: settled by the AI's own lookup, already ruled by the human).
- On collision, full text wins: a row meeting any full-text condition gets
  full text.
- The durable record always carries the full table — it is the full-text
  layer's home; tiering applies to the end-turn message only.

## User-start gate

- Per-item questioning begins only when the user explicitly says to start.
  Waiting is the default state after presentation; silence never advances.

## AskUserQuestion scope

- AskUserQuestion is for per-item rulings AFTER the full picture is already
  visible — never for delivering the picture itself.
