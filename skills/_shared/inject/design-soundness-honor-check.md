---
injected-by: [anvil, code-review, design-review]
kind: bridge
---

**design-soundness honor-check** — the two-arm definition the touchstone review surfaces
load-and-inject verbatim into every cold-dispatched reviewer. The feedforward arm fires at
`design-review` (subject = the spec document); the feedback arm fires at deliverable review
(subject = delivered code vs the spec's structural commitments — its `depth-stakes:` REQs in
six-section form, or its `## Architecture` section in legacy form).

**Injector requirement (warm orchestrator, at injection time):** also load
`${CLAUDE_PLUGIN_ROOT}/skills/assay/references/arch-rubric.md` and inject its content
into the cold prompt alongside this fragment. The cold reviewer cannot resolve plugin
paths — the rubric must arrive as content, never as a path.

---

## Shared: what a structural commitment is

A **structural commitment** is a normative SHALL statement that constrains the shape of the
delivered code — homed in a `depth-stakes:` REQ (six-section form) or a `## Architecture`
section (legacy form) — e.g. "module M SHALL be deep / SHALL NOT leak its orchestration
sequence to callers." It is grounded in the assay
arch-rubric, whose force text is injected alongside this fragment — apply that injected
content; do not go looking for a file.

A commitment is **normative** when it uses SHALL or SHALL NOT and names a component +
constraint. A section that merely describes the system shape without these constraints
is **descriptive-only** — it does not constitute a structural commitment.

---

## Feedback arm (deliverable review — code vs spec)

**Scope:** apply this arm to the **whole deliverable** against the governing spec's
structural commitments — for six-section specs, the **depth-stakes REQ set** (REQs carrying a
`depth-stakes:` marker); for pre-P2 specs, the **whole ## Architecture** section. This is a
subsystem-level check, not per-diff.

**Honor-judgment rule:**

1. Read the spec's structural commitments — the depth-stakes REQs (new form) or the
   `## Architecture` section (legacy) — and enumerate its SHALL / SHALL NOT statements.
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

**Missing-commitment detection (six-section form, the default):** a component with depth
stakes per the rule above MUST carry a `depth-stakes:` REQ marker with a per-component SHALL
commitment grounded in the arch-rubric. A depth-stakes component with no such marker/SHALL →
raise a design-soundness finding: "structural commitment is missing — component <X> has depth
stakes but no `depth-stakes:` REQ marker with a SHALL." A purely additive component needs no
marker (no finding).

**Legacy form (pre-P2 specs with a `## Architecture` section):** if the section is
**descriptive-only** (old-style system shape, no normative SHALL) on a depth-stakes feature,
raise the same missing-commitment finding; an explicit `no structural commitment — additive`
is zero commitments (no finding); an absent `## Architecture` section on a depth-stakes
feature still receives the finding.
