# Foundation-elicitation gate (shared)

The Baseline 3-field elicitation (intention / aim / out-of-scope), shared by `design-spec`
(Draft Mode Step 0) and `epic-driven-roadmap` (Scaffold step 0). Run it before any expensive
drafting/scaffolding — it catches wrong-scope work while it is still cheap. Each caller wraps
this gate with its own inheritance handling and records the confirmed foundation in its own
target (see **Caller contract** at the end).

## Reuse check (FIRST)

If a foundation was already confirmed earlier in THIS SAME skill invocation, do NOT re-elicit.
Emit this EXACT log line verbatim (fixed emit string — do not paraphrase, do not reword):
"Foundation already confirmed this session — reusing", reuse the confirmed foundation, and skip
to the caller's record step. Do NOT emit the from-scratch opener. Reuse is same-invocation only;
it never spans separate invocations.

## 1. From-scratch opener

Open with this EXACT phrase (fixed emit string): "Please describe the intended work in your own
words." The substring "describe the intended work in your own words" is what the bypass fixtures
match (Step-0 reached) and what the from-scratch-opener check forbids elsewhere — keep it
verbatim, do not paraphrase. No fixed follow-up questions — let the user give context freely.

## 2. Sharpening exchange

Engage in a SHORT sharpening exchange. Ask only questions in the ALLOWED column of the caller's
Step-0 question-boundary table. Stop once intention / aim / out-of-scope are crisp. Never ask a
FORBIDDEN-column question (architecture, files, dependencies, tests, API shape, effort, rollout,
or fix strategy) — those are design-phase decisions. Do NOT slide into requirements/design
exploration (→ brainstorming) or domain-vocabulary grilling (→ grill-with-docs). If the user
prods toward design, deflect with ONLY this generic phrase — "that's a design decision for a
later stage" — and return to the three fields. Do NOT name or restate the specific design topic
raised (no echoing "endpoint", "migration path", "rollout", etc.) — naming it engages the design
and trips the shallow-boundary check.

## 3. Synthesise the draft

Present using these EXACT field labels (verbatim — the fixtures match them case-sensitively):
"Intention (why):", "Aim:", "Out of scope:". The SYNTHESISED aim must not contain a vague token
{usually, typically, should, elegant, complex, careful, better}; if it would, do NOT carry it
into the draft — re-prompt for an OBSERVABLE formulation (ask what the user would observe or
measure when done; "what would you observe when this is done?" is a good default). Do not
synthesise until the aim is observable. Out-of-scope sentinel: if the user declines to name any
out-of-scope route after one re-prompt ("can you name one thing this work will NOT touch, even if
related?"), record this EXACT sentinel verbatim (fixed string — do not paraphrase, this literal
only): "(no explicit boundary declared)" — this is the one allowed placeholder, no other — AND add
a matching entry to the caller's Risks / Open Questions section.

## 4. Confirm

Surface the draft and ask, with this exact phrase: "Please confirm or edit this foundation." Do
not proceed until confirmed. If the user insists on an aim that contains a vague token, warn with
this EXACT phrase verbatim (fixed emit string — do not paraphrase, do not reword): "(aim contains
a vague token — accept anyway?)". On accept, record the user's aim verbatim AND add this EXACT
risk note verbatim (do not paraphrase): "(aim contains an unverifiable token — user-confirmed)".

## Caller contract

- The caller may run an inheritance pre-step BEFORE the opener (e.g. `design-spec` inherits a
  parent epic's `## Foundation`); when inheritance applies, the caller uses its own inheritance
  prompt INSTEAD of the from-scratch opener. Epic scaffold is the origin — no inheritance.
- On confirm, the caller records the foundation in its own target: `design-spec` → `## Foundation`;
  `epic-driven-roadmap` → the `**Aim:**` headline + `## Foundation`.
