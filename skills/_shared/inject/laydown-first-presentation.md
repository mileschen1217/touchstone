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
  calls — and (2) a mirror into the consumer's **durable record** file. A
  consumer MAY declare a record section **deferred** — written only at a
  later consent point: the message carrier fires now, the file carrier at
  that point. Never mirror deferred content into the record early.
- Never carry load-bearing content ONLY in text emitted before a tool call
  or in AskUserQuestion option previews — both are known non-universal
  carriers.

## Full picture before per-item

- Present the COMPLETE picture in one message before any per-item
  discussion; the human chooses what to discuss — the AI never pre-selects.
- While the human grills or adds rows: answer, fold changes into the
  picture, re-present the delta — still no per-item questioning.

## Tiered depth

- The end-turn message is **coverage-complete** — every row present — with
  depth tiered by ONE principle: a row still awaiting the human's ruling or
  attention this turn gets **full text**; a resolved row gets a **one-line
  digest**. On collision, full text wins.
- **Scale notch.** When the tiered message would exceed **one-pass scannability**
  (the AI's functional judgement — not a hardcoded row or token count),
  collapse the DIGEST tier: rows already mirrored to the persisted record are
  replaced by an explicit count + the record-file path holding their full
  content — always the whole digest set, never a cherry-picked subset; rows
  not yet persisted (a deferred record section) stay one-line inline instead.
  The full-text tier is never collapsed. When the judgement is
  ambiguous, collapse the digest tier (the stricter default), signposted.
  Every collapse names the count + record-file path AND a short expand
  request the human can give to render the collapsed rows inline — the
  collapse is reversible by the human.
- The durable record always carries the full table — it is the full-text
  layer's home; tiering applies to the end-turn message only.

## User-start gate

- Per-item questioning begins only when the user explicitly says to start.
  Waiting is the default state after presentation; silence never advances.

## AskUserQuestion scope

- AskUserQuestion is for per-item rulings AFTER the full picture is already
  visible — never for delivering the picture itself.

## Canonical rendering example

Synthetic content — the FORM is canonical, not the wording: tags as distinct
scannable **badges**; the stable id as a **handle beside** the content phrase,
never id-alone. Three renderings of the ONE two-valued tier axis (full-text /
digest), not a third tier value:

**Awaiting zone (full text):**

> `[load-bearing? yes] [probe-cost cheap]` **the record is written incrementally**
> `(A-3)` — I am assuming the durable record is mirrored row-by-row during the
> interview, not only at the terminal step; this gates the collapse-to-pointer path.
> Leaning: confirm by lookup before relying on it.

**Resolved zone (one-line digest):**

> `[settled]` **term "readiness" = explicit yes + a clean probe round** `(T-2)` —
> ruled at Q-4.

**Scale-collapsed digest (large laydown, digest content already mirrored):**

> **Resolved rows: 18** — full content in `<record-file>.md § Alignment table`.
> To see any in full, say "expand the resolved rows" (or name one by its phrase).
