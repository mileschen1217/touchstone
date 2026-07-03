---
injected-by: [anvil, code-review, design-review]
kind: bridge
---

**design-soundness honor-check** — the two-arm definition the touchstone review surfaces
load-and-inject verbatim into every cold-dispatched reviewer. The feedforward arm fires at
`design-review` (subject = the spec document); the feedback arm fires at deliverable review
(subject = delivered code vs the spec's `## Architecture` commitments).

**Injector requirement (warm orchestrator, at injection time):** also load
`${CLAUDE_PLUGIN_ROOT}/skills/keystone/references/arch-rubric.md` and inject its content
into the cold prompt alongside this fragment. The cold reviewer cannot resolve plugin
paths — the rubric must arrive as content, never as a path.

---

## Shared: what a structural commitment is

A **structural commitment** is a normative SHALL statement in a spec's `## Architecture`
section that constrains the shape of the delivered code — e.g. "module M SHALL be deep /
SHALL NOT leak its orchestration sequence to callers." It is grounded in the keystone
arch-rubric, whose force text is injected alongside this fragment — apply that injected
content; do not go looking for a file.

A commitment is **normative** when it uses SHALL or SHALL NOT and names a component +
constraint. A section that merely describes the system shape without these constraints
is **descriptive-only** — it does not constitute a structural commitment.

---

## Feedback arm (deliverable review — code vs spec)

**Scope:** apply this arm to the **whole deliverable** against the **whole ## Architecture**
section of the governing spec. This is a subsystem-level check, not per-diff.

**Honor-judgment rule:**

1. Read the spec's `## Architecture` section and enumerate its structural commitments (SHALL
   / SHALL NOT statements).
2. For each commitment, inspect the delivered code and judge:
   - **Honored** — the code satisfies the commitment (e.g. the module is deep: callers need
     not know internal state or sequencing). Raise no finding for this commitment.
   - **Violated** — the code clearly contradicts the commitment (e.g. the module exposes
     fine-grained mutators that leak the orchestration sequence; same-name-two-meaning fields).
     Raise one finding per violated commitment, citing the specific commitment text.
   - **Ambiguous** — you cannot determine whether the code honors the commitment. Mark it
     `[unverified: <reason>]`. Do NOT pass by default. A `[unverified]` mark is honest and
     allowed; a silent pass-by-default is not.

3. When `## Architecture` carries multiple commitments, raise **one finding per violated
   commitment** (commitment-granularity). Honor honored commitments silently; raise none for
   them.

**Honest ceiling:** this arm catches **declared-and-violated** — a spec declared a structural
commitment that the delivered code violated. It does **NOT** claim to catch
**commitment-less accreted** shallow modules (historical shallow code with no governing spec).
That is a distinct deferred increment. Do not over-claim.

---

## Feedforward arm (design-review — spec document)

**Scope:** apply this arm to the spec document itself (not the code).

**Depth-stakes decision rule:** a component has depth stakes if it:
- hides a non-trivial implementation decision, OR
- holds or mutates state, OR
- sequences operations a caller could otherwise mis-order.

A component is **purely additive** only if it adds behaviour within an existing module's
established interface without introducing any of the above. The `no structural commitment —
additive` escape requires explicitly answering this question, not a silent skip.

**Descriptive-only detection:** if the spec has a `## Architecture` section that is
**descriptive-only** (old-style system shape with no normative SHALL commitments) on a feature
whose components have depth stakes per the rule above, raise a design-soundness finding:
"structural commitment is missing — the ## Architecture section is descriptive-only; it
should state per-component SHALL commitments grounded in arch-rubric.md."

If `## Architecture` states `no structural commitment — additive` explicitly, treat as
zero commitments (no finding). If `## Architecture` is absent entirely, the floor passes
vacuously; a depth-stakes feature with no section should still receive a finding here.
