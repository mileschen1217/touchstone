# touchstone CONTEXT

The canonical vocabulary the touchstone skill family operates in. SKILL.md bodies Read this file at Step 0 when source-as-truth discipline is adopted. Edit here only; no copies live in SKILL.md.

## What this document is

Constitution + bridge content for the source-as-truth discipline. "Constitution" sections are permanent; "enforceable-rule" sections carry `kill-on: lever-discipline-mechanisation` (a future linter/CI grep tool that would mechanise them).

## Skill / Mode / Discipline / Baseline — structural roles

Constitution.

Four structural roles for cross-cutting behavior in the touchstone plugin, distinguished by **activation scope**:

| Role | Activation scope | How turned on | Example |
|---|---|---|---|
| **Skill** | per-invocation | `Skill` tool call | `grill-with-docs` |
| **Mode** | per-session | user toggle (e.g. `/<mode-name>`) | `caveman`, `grounded-claims` |
| **Discipline** | per-project | `.claude/touchstone.yaml` `adopted_disciplines:` | `source-as-truth` |
| **Baseline** | per-plugin | hard-coded into plugin | `intention-first` |

The four are exhaustive and mutually exclusive — every cross-cutting rule fits exactly one role.

### Classification flow

Three sequential questions decide where a concept goes:

1. **Is it cross-cutting?** (modifies ≥2 stage skills' steps)
   - No → it's a **skill** (one entry point, one purpose).
2. **What's the natural activation scope?**
   - Single moment in a task → keep as skill (manual invoke each time).
   - Ambient within one work session, may flip mid-session → **Mode**.
   - Ambient for the lifetime of a project, set once → **Discipline**.
   - Cannot reasonably opt out at any scope → **Baseline**.
3. **Is it step-level mechanisable?** (expressible as "in skill X step Y, do Z")
   - No → it's prose, belongs in `CLAUDE.md`, not in the role taxonomy.

### Why these four roles

The roles map to **who has agency over the toggle**:

- Skill: caller decides per-invocation.
- Mode: user decides per-session (highest agency for ambient behavior).
- Discipline: project owner decides at setup (institutional commitment).
- Baseline: plugin author decides; users cannot opt out.

At any one skill Step, only currently-active modes + adopted disciplines + baselines fire. Each fire is a discrete enumerable rule, not ambient mood. Adding a new role-instance should not increase per-Step cognitive load unless that Step explicitly enumerates the new rule.

Roles compose; they don't accumulate as global modifiers.

### Current inventory

The live set of role-instances. Single source of truth — ADRs classify; this table records what exists and its status.

| Instance | Role | Status | Authority |
|---|---|---|---|
| `source-as-truth` | Discipline | Adopted, shipped | this doc (rationale: local .touchstone/docs/adr/0004-*) |
| `intention-first` | Baseline | Building (Epic D); legacy always-on 4Q exists | ADR-0003 |
| `grounded-claims` | Mode | Shipped, plugin-local (`skills/grounded-claims`) | ADR-0002 |
| `caveman` | Mode | External skill; not in plugin | global `~/.claude/skills/caveman` |

`grounded-claims` was formerly named `ground-as-source`; renamed to disambiguate from the `source-as-truth` Discipline (they govern different relationships — doc↔source vs claim↔evidence; see ADR-0002).

`grounded-claims` and the `testing-strategy` honesty gate are two instances of the **honesty spine** (§ Honesty spine) on different surfaces: `grounded-claims` governs **narration** (every sentence a session SAYS must cite or carry `[假設]`); `testing-strategy` governs **deliverable certification** (every AC the workflow marks done must be backed by a test at the right layer, or carry `[unverified]`). Siblings, not duplicates — narration-time vs gate-time.

### Fire ordering (when multiple fire at one Step)

When several baselines/disciplines/modes are active at the same skill Step, scope-framing fires before content-rules: **`intention-first` (Baseline) → `source-as-truth` (Discipline) → active Modes**. Rationale: the intention gate can reframe scope ("this is a fixture, not a spec") and abort the Step; running it first avoids wasted vocabulary-load cost.

## Honesty spine

Constitution. The load-bearing principle of the plugin: **a claim never exceeds its evidence; gaps are marked, not hidden** (`claim ≤ evidence`). Every stage is accountable to this spine — it is the thread the whole workflow exists to keep honest.

The spine reaches a stage through **two arms**:

- **Feedforward arm (anticipatory)** — *before* the work, the stage declares what it will claim and what evidence that claim needs, and marks unknowns as unknown. E.g. `design-spec` declares the Verification Strategy; `design-review` forces `[unverified]` on ambiguous live-bearing ACs.
- **Feedback arm (verifying)** — *after* the work, a mechanism measures whether the claim was actually backed and forces any gap to be marked. E.g. epic-close evidence reckoning; the `code-review batch` evidence-honesty criteria; `grounded-claims` per-sentence `[假設]` / citation.

**Not a fifth role.** The spine is content carried *through* the four roles, not an activation scope of its own: `grounded-claims` (Mode) carries it for narration, the `testing-strategy` gate for deliverable certification, `source-as-truth` (Discipline) for doc↔source. The roles say *when* a rule fires; the spine says *what truthfulness* the rule serves.

**Audit criterion — not a completeness checklist.** A stage need not have both arms. The defect is **silent false-green**: a claim that exceeds its evidence and is caught by no mechanism, in that stage or downstream. A one-armed (or armless) stage is fine when it makes sense — it is a gap only when it emits a claim that nothing ever closes. Feedforward⇄feedback began as a general control-axis diagnostic (is the suite feedforward-heavy or feedback-heavy?); that broader *audit* was dropped, but the axis itself is real and general — the honesty spine is its **first pillar** (per-delivery trust), not the whole axis (see ADR-0018 for the two-pillar derivation). The two arms here are honesty's instantiation of the feedforward/feedback axis, not a separate lens. (Origin: the `workflow-suite-audit` epic.)

## Four doc kinds

Constitution. Every doc is one of four kinds. Each has a lifecycle.

| Kind | Question it answers | Lifecycle | `kill-on:` required? |
|---|---|---|---|
| Navigation | Where does X live? | Permanent; ideally generated | No |
| Bridge | What's the rule / trap? | Mortal — declared `kill-on:` at birth | Yes |
| Workflow | How do we work? | Permanent; human-governed | No |
| Diagnostic | How did we discover this? | Permanent but inert; `evidence-for:` link | No |

## Bridge content gate — three principles

Enforceable-rule. `kill-on: lever-discipline-mechanisation`. Every bridge claim must pass **P1 (non-duplication)** / **P2 (falsifiable)** / **P3 (no single host)**, composed in that order; failing one is a defect, not "needs work". **Full rule + injectable text:** `skills/_shared/inject/bridge-content-gate.md` (single home — injected verbatim into cold reviewers by `design-spec` / `keystone` / `design-review`).

## Standing vs transient bridge

Constitution. Bridges have a second scope-span axis: **standing** (architecture docs dir, long-lived, `kill-on:` retires it, cold-start reads it) vs **transient** (specs dir, retires when the feature lands, epic-context only). Cold-start readers enter through standing bridges + navigation, never through specs. **Full table + injectable text:** `skills/_shared/inject/standing-vs-transient-bridge.md` (single home — injected by `keystone` / `design-review`).

## Three layers of knowledge — complementarity rule

Constitution. Navigation / Bridge / Source each answer one question. Complementary, not overlapping.

| Layer | The question | Trust |
|---|---|---|
| Navigation | "Where does X live?" | High (pointer) |
| Bridge | "What's the rule?" | Medium (drifts) |
| Source | "What does it do?" | Absolute (final arbiter) |

When in doubt: Where → Navigation; What's the rule → Bridge; What does it do → Source.

## Bridge proximity ladder

Enforceable-rule. `kill-on: lever-discipline-mechanisation`. Bridge content lives at one of four rungs, descending preference.

| Rung | Form | When |
|---|---|---|
| 1 | Type or test (source itself) | The fact can be encoded mechanically |
| 2 | `///` doc-comment on a symbol | Fact attaches to one symbol |
| 3 | `// BRIDGE` block at call-site | Fact attaches to one function body's call sequence |
| 4 | `.md` bridge doc | Cross-module / cross-language / negative-space / cold-discoverability fact |

Generic example: VLAN-port-membership update order = rung 3 (`// BRIDGE` block on the call sequence).

## Validation rubric (load-bearing)

Enforceable-rule. `kill-on: lever-discipline-mechanisation`. Every lever epic satisfies three signals.

- **Signal 1 — Compile-fail test (strongest):** the lever encodes its rule as compile-time guarantee. Rust: `compile_fail` doctest. TypeScript: `// @ts-expect-error` test. Python: `mypy --strict` failing on the symbol. Adapt to the language; the principle is encoding mechanically.
- **Signal 2 — Doc deletion:** every lever names a target bridge doc that becomes deletable on land. Epic close includes the deletion commit OR residual-content note.
- **Signal 3 — Cold-start delta:** measured before/after; pass if recon turns drop meaningfully. Advisory, not gating.

## Frontmatter schema

Constitution. Fields introduced by source-as-truth:

| Field | Required when | Value |
|---|---|---|
| `kind:` | every doc | one of `navigation`, `bridge`, `workflow`, `diagnostic` |
| `kill-on:` | `kind: bridge` | slug of the lever epic that retires the doc |
| `evidence-for:` | `kind: diagnostic` | path(s) to the workflow/ADR this diagnostic supports |
| `evidence:` | optional reciprocal on workflow/ADR | list of diagnostic paths supporting the decision |

`evidence-for:` ↔ `evidence:` makes the link bidirectional.

## Agent dispatch axis

Constitution. Classifies *how a multi-task plan is executed* — orthogonal to the four structural roles (which classify activation scope of cross-cutting behavior). Workflow kind; human-governed.

One decision, one knob:

- **Dispatch: inline vs delegate.** Inline = orchestrator executes directly, reusing its loaded context. Delegate = hand the work to a subagent.
- **Delegate ⟹ fresh × on-disk contract.** A one-shot agent reads `contract.md` and emits `result.json`; cross-step state lives on disk (commits + result), never in a persistent agent's memory.
- **Granularity knob (delegate only):** bundle cohesive / shared-read-set tasks into one contract to amortize re-read; split independent tasks for parallelism / isolation; stop bundling before the agent's context rots (~2–4 tasks). Token cost is amortized by bundling, never by keeping an agent alive across turns.

Two things are NOT dispatch patterns:

- **Exploration subagent** (read-only info-gathering) is a tool — fresh, in-context, ceremony-free. No contract.
- **Persistent resource** (live bench, warmed REPL) is resource management — the *resource* persists; the agent stays fresh and reconnects via a handle carried in the contract.

Decision unit = **phase** (the longest contiguous task run whose answer is constant). A uniform plan is one phase / one pattern; cut a new phase where the answer flips (e.g. a bench-bound phase appears).

Plans are written **dispatch-agnostic** (task + AC + files + sequence). At the plan→execution surface the orchestrator derives phase segmentation + bundling from each task's `Files` and dependency edges, **recommends** a pattern + rationale, and the human **picks**. Contracts are an execution-time projection of plan tasks — generate them only when delegating.

### Scope-change protocol

When a subagent discovers mid-run that an Acceptance Criterion requires acting outside its contract Scope, it neither silently expands nor dumb-stops: it emits a structured `scope_change_request` and the orchestrator adjudicates by **reversibility, not file location** (reversible + in-boundary → auto-approve + amend Scope + re-dispatch; irreversible or cross-boundary → escalate to human). Request + decision are logged to the epic scope-change ledger for audit and epic-close retro. Schema, adjudication policy, and ledger format have one home: the task-contract template § Scope-Change Protocol.

This protocol organizes intent and auditability only. It does **not** enforce safety — preventing an unauthorized irreversible action is CC's own permission mode / hooks / sandbox / git, configured by the operator.

## Two result.json artifacts (disambiguation)

Two distinct on-disk artifacts were historically both called "result.json schema v1". They are different contracts with different owners; never conflate.

| Term | **Task result** | **Review envelope** |
|---|---|---|
| Canonical name | `task-result.json` (`schema_version: 1.1`) | `review.result.json` (`review-envelope/v1`) |
| Filename on disk | `result.json` | `review.result.json` |
| Owner / source-of-truth | `epic-driven-roadmap` templates | `cross-provider-reviewer/references/provenance.md` (sole home — see § Dispatch provenance) |
| Written by | `codex-implementer`, `codex-tdd` | the Pattern A composite bodies (`cross-provider-*`) and the Pattern B `code-review` body. The codex review agents are thin forwarders — they emit only `raw_codex.jsonl`, never the envelope. |
| Answers | did the **task contract** execute? (files_changed, tests_passed, scope_change_request) | did the **review** run, and with what dispatch provenance? (raw evidence only — see § Dispatch provenance) |

The review-envelope filename is `review.result.json` (not bare `result.json`) so the two cannot collide when a task_dir is shared.

## Dispatch provenance

The audit trail of *which providers actually reviewed* and whether the intended cross-vendor scrutiny happened. Recorded in `review.result.json` and surfaced loudly to the human; **audit-available, never enforced** (ADR-0007).

> **Canonical contract:** `skills/cross-provider-reviewer/references/provenance.md` is the sole normative home for the `review-envelope/v1` schema, the correctness rules, and the banner format. This section is conceptual vocabulary — descriptive, not the contract. If the two ever disagree, provenance.md wins.

**Raw evidence only is stored** — no derived/judgement fields land on disk. Consumers (human, audit) derive the correctness readings from the raw arrays at read time; the rule can change without rewriting old data.

| Stored (raw) | Meaning |
|---|---|
| `providers_expected[]` | the provider set THIS invocation intended (default Pattern A = `{cc,codex}`; Pattern B swap = the single opposite-of-builder vendor; `with X` force = `{X}`) |
| `providers_used[]` | who actually produced a review |
| `builder_vendor` | Pattern B only — the vendor that built the code under review (for the builder≠reviewer check) |
| `session_id` | codex audit anchor, extracted from `raw_codex.jsonl` by the composite / code-review body (NOT by the thin codex agent) |
| `fallback_reason` | why a provider was absent, if any |

Two **correctness readings** (derived, not stored):

- **Quantity correctness** — `|providers_used| == |providers_expected|` and non-empty. Did we get the intended *number* of reviewers?
- **Vendor correctness** — did the intended cross-vendor property hold? Pattern A: both distinct vendors ran. Pattern B: reviewer vendor ≠ `builder_vendor` (the swap held). `with X` force: requirement waived → reading is satisfied.

These are orthogonal: a Pattern B run whose swapped reviewer fell back to the builder's own vendor is **quantity-correct (still 1 reviewer) but vendor-incorrect (swap failed)**.

**`degraded`** — derived banner trigger, NOT a stored field. Conceptually `degraded = (!quantity_correct || !vendor_correct) && providers_used non-empty`, relative to *this invocation's intent* (a deliberate `with X` single-vendor run is not degraded; a total failure with empty `providers_used` is `status: failed`, not degraded). When true, the composite / code-review body prepends a loud `⚠️ DEGRADED …` banner to the returned synthesis; the calling stage skill passes it through to the human and does **not** hard-block the C+H gate on it. But a loud banner (DEGRADED or PARTIAL) does require an **informed-consent checkpoint**: the caller must obtain explicit human acknowledgement before the workflow proceeds — a human checkpoint orthogonal to the C+H gate (the human may proceed, but only knowingly). The exact formula + banner wording are owned by provenance.md (above) — this is the concept, not the contract.

**Content quality is a separate axis.** `degraded` is about cross-vendor *completeness*. A provider that ran but returned unreliable output (e.g. codex JSONL with >5 malformed lines → `status: partial`) is surfaced by its own `⚠️ PARTIAL` banner, orthogonal to `degraded`; both can co-occur.

**Provenance reference** — the single shared doc describing how to compute the two correctness readings, format the banner, and write the raw fields. Read by BOTH the `cross-provider-*` composites (Pattern A) and the `code-review` skill body (Pattern B, no composite). One home, no drift.

Transport is agnostic: the request rides result.json (`status: needs-scope-expansion`) for one-shot subagents (stable), or the agent-teams `plan_approval_request` runtime channel (experimental) when enabled.

## Template co-location

Constitution. A template lives co-located with its sole owning skill at `skills/<skill>/templates/` (a `templates/` dir even for a single file). The root `templates/` dir is reserved for templates shared by 2+ skills. Skills reference their templates by **plugin-relative path**, never an absolute `~/.claude/skills/m-*` path.

`skills/_shared/` holds cross-skill instruction blocks governed by the **no-single-host principle** (ADR-0020 Amendment 2026-06-24, same root as the Bridge proximity ladder § below): home a fragment at its most-local authoritative single host; a fragment is shared ⟺ no single host can own it — i.e., the fragment expresses genuinely cross-cutting doctrine where divergence would be a bug. `≥2` consumers is the derived floor (1 consumer ⇒ that consumer IS the host ⇒ never shared), NOT the governing rule (e.g. `config-resolver.md`). Fragments in `_shared/` operate at **principle-altitude** (cross-cutting first-principle doctrine, ADR-0020 pt4) — not rule-level implementations, which live inside individual skills. Single-skill assets stay co-located in `skills/<skill>/`. **Dual-use carve-out:** a fragment that is read warm by an orchestrator AND cold-injected into a reviewer (its consumers declared in `referenced-by:` + `injected-by:` frontmatter) may live in `skills/_shared/` and be injected from there — it is not required to move to `_shared/inject/` (see `ground-and-sweep.md`). Cold-ONLY fragments default to `skills/_shared/inject/`.

`skills/_shared/inject/` is a distinct sub-home for **injectable doctrine fragments** — standing doctrine that a cold-dispatched reviewer receives verbatim (the reviewer cannot see CONTEXT.md). Each fragment declares `injected-by: [skills]` (and `referenced-by:` for warm-orchestrator citers) so its blast radius is visible. CONTEXT.md keeps a one-line glossary definition + a pointer; the fragment is the single home of the full rule (see ADR-0017).

## Requirement-layer vocabulary

The layers **above** the AC — the human "what" that ACs make checkable. Settled 2026-06-20/21 (skill-ceiling Phase 2 grill + a layering first-principles analysis). **3-layer model along the intension–extension axis, host-agnostic.** The three layers are three points on one continuum (intension → extension): **user-story → requirement → AC**. _Note_: a prior 2-layer framing was superseded by the layering drill.

**user-story** — the external/user-faced contract (the need + situation: "As an actor, I want X, so that Y"), carrying a stable `US-N` id (the anchor `traces-to:` points back to). The **intensional pole** (F-need): recognizable as the user's need, deliberately under-specified for verification. **Always produced (always-3-layer, decided 2026-06-22).** touchstone defaults to authoring user-story → requirement → AC; **solo/non-solo is a read-depth choice, NOT a production switch** — a solo reader reads the requirement directly, a non-solo reader also reads the story. (Supersedes the earlier "folds into `requirement` when solo" framing: folding was about *production*; the decision makes production uniform and lets the *audience* pick depth. Sound because the story→requirement completeness floor is solo-independent — see § story→requirement completeness; only the two-party access difficulty toggles with audience, and designing for its presence costs solo nothing.) _Avoid_: branching the production mechanism on solo/non-solo — produce all three layers, always.

**PRD** — the **want-layer** of the contract spine: `why` (one-sentence intention) + `US-N` user-stories + out-of-scope. In touchstone wiring the want-layer is **always-on and native to `design-spec`** — the `## User Stories` section IS the single canonical home of the PRD layer (ADR-0021 addendum). There is no separately-produced PRD artifact, no separate chained PRD step, and no cross-artifact mirror. A shareable external PRD is an **out-of-band human action** when a real external-share need arises; touchstone owns only the want-layer inside the canonical design-spec. _Avoid_: producing a separate PRD document as part of touchstone's wiring — the single canonical lives in the spec's `## User Stories`; a separately-chained PRD producer was removed (ADR-0021).

**`touchstone:crucible` (front-end contract orchestrator)** — the single front-end skill that chains: `superpowers:brainstorming` (conditional — run when scope is genuinely unclear) → `grill-with-docs` (unconditional) → `touchstone:keystone` (conditional — structural fork when artifact count is open) → `/touchstone:design-spec` (always). The want-layer (why + US-N) is native to design-spec; no separate PRD-producer step exists in the chain (ADR-0021). The AI authors the whole contract spine (why + US-N user-stories + requirements + ACs) in one pass; the human accepts **once** at the contract. It **reimplements none** of its sub-skills and adds only the chaining and US-N id discipline. It **terminates at human accept** and hands the accepted contract to `anvil` (§ Build-phase vocabulary); it auto-invokes the **consolidated design-review gate** before its terminal human-accept (the 3→2 front-load, ADR-0026); it does **not** invoke build (that is the `anvil` phase). _Avoid_: inserting a separate PRD-producer step between grill and design-spec — the chain tail is grill → design-spec (ADR-0021); making crucible emit requirements itself (design-spec authors those); or carrying it past human accept into the gate/build.

**requirement** — the internally-verifiable **explicit rule** (a SHALL / obligation statement), the **mid-point** of the axis and the **always-present anchor**. It is load-bearing because the completeness arm partitions a *rule's* input domain — EP/BVA/Nagy need an explicit rule to partition against; story + AC alone leave the rule implicit and branch-completeness uncheckable. Host-agnostic (matches IEEE 830 "requirement" and OpenSpec's `### Requirement:`). **Anti-redundancy discipline (template-enforced):** a requirement must add **rule-altitude precision (a partition-able domain)** over its user-story — NOT merely reword it in SHALL form; a requirement that only rewords its story is a smell → collapse it (this is the Spec-Kit redundancy critique). _Avoid_: treating a requirement as a test or a GWT block (that is the AC); a requirement is the explicit rule, an AC is its enumerated branch.

**AC (acceptance criterion)** — the agent-executable check under a requirement, written Given/When/Then, carrying a stable `AC-N` id; the unit the honesty spine accounts for (AC coverage, `[unverified]`, live-bearing all key on the AC). The **host-agnostic spine name** for the GWT-check layer. One requirement has ≥1 AC (happy + sad). _Avoid_: calling it "scenario" in spine prose — `scenario` is the OpenSpec substrate's name for this same object (see mapping below); the spine stays host-agnostic.

**AC ↔ scenario (reference-template word)** — OpenSpec's spec shape names this same GWT-check object `#### Scenario:`, nested under `### Requirement:`. touchstone **borrows that partition shape as a reference only** — the OpenSpec dependency was dropped 2026-06-15 (touchstone owns its doc architecture; the storage substrate is the local `.md` file, NOT OpenSpec). So `AC` is touchstone's **native** spine term; `scenario` is merely the reference shape's word for the same concept — there is no live `opsx` binding and no AC↔scenario adapter mapping to maintain. _Avoid_: (1) renaming AC→scenario in the spine — large churn (AC-N ids, ledger `missing-AC`, `[unverified]`, checkers) for a non-binding reference; (2) calling OpenSpec "the substrate" — it is a reference template shape, not a bound engine/storage (no `config.yaml` overlay, `validate`, archive-merge, or living-`specs/` lifecycle).

**`[NEEDS CLARIFICATION: <question>]`** — a **feedforward** (specification-gap) marker: this requirement or AC lacks the information to author it correctly. Adopted from GitHub Spec-Kit. Distinct from `[unverified]` (a **feedback** / verification-gap marker — see § Verification vocabulary): clarification = "not enough info yet, not ready to Build"; unverified = "well-formed but no evidence confirms its Then". **Upstream → downstream, not co-occurring on one AC**: resolve `[NEEDS CLARIFICATION]` → well-formed AC → (later, at verify) possibly `[unverified]`. Attaches to a **requirement OR an AC**; `[unverified]` attaches only to an AC. Gate: count > 0 blocks "ready for Build" at design-review — the feedforward analog of how `[unverified]` is reckoned at Evidence Reckoning. _Avoid_: collapsing the two markers — it erases the spine's feedforward / feedback arm split and the ledger's `missing-AC` vs `false-green` attribution.

**requirement→AC completeness (feedforward arm)** — the spine's **feedforward** check: "is the AC set the RIGHT set for its requirements?" Distinct from **AC coverage** (the **feedback** check "was each AC verified?", § Verification vocabulary). Three parts: (1) a **challenge-pass** (generative — Example Mapping / Gáspár Nagy's 5 techniques / EP/BVA used as prompts) that surfaces missing cases and emits `[NEEDS CLARIFICATION]`; (2) a **structural-completeness** gate (mechanical, blocking); (3) **semantic completeness** (human-only). The mechanism + insertion point are an open implementation decision, not fixed here. _Avoid_: calling the whole arm "the completeness gate" — only part (2) is a gate; part (1) is generative and part (3) is a human judgment.

**story→requirement completeness (feedforward, the rung ABOVE requirement→AC)** — "is the requirement set the RIGHT set for its user-stories?" Settled 2026-06-22 (first-principles drill `2026-06-21-story-requirement-completeness-first-principles.md`): it hits the **SAME floor** as requirement→AC semantic completeness (intension–extension / no finite ground-truth total) — so it is **NOT a new problem** and **reuses the same 3-part shape**, one rung up: (1) **generative step = recognition** (`brainstorming`), NOT EP/BVA — there is no rule-domain to partition at the story rung, so the systematic Nagy-5 / EP-BVA challenge stays at requirement→AC; (2) **structural slice** = every `US-N` has ≥1 requirement with `traces-to: US-N` + zero unresolved `[NEEDS CLARIFICATION]` — **mechanized (decided 2026-06-22)**: the structural-floor checker is extended to enforce it (parity with the requirement→AC structural check), with US-N stories mirrored into the design-spec so the check stays single-file. A deterministic floor here is cheap, doubles as a forcing function (the author must confront every US to satisfy `traces-to`), and is the structural guard that stops `/build` industrialising a silently-dropped story; (3) **semantic completeness = human** (PRD approval; no mechanical oracle). _Avoid_: putting an adversarial systematic challenge at the story rung — PRD-level "did we miss a requirement?" is recognition-handled, not partitioned.

**`traces-to: US-N`** — the requirement field naming the parent `user-story` it serves; the link the story→requirement structural slice checks (every US-N picked up by ≥1 requirement). Catches the one story-rung false-green: **a user-story silently dropped** (requirements cover 4 of 5 stories, story #5 has no requirement). _Avoid_: treating `traces-to` as proof of *semantic* coverage — it is a structural trace (the link exists), not a judgment that the requirement adequately serves the story (that is anti-redundancy + human).

**structural completeness** — the mechanically-checkable slice of requirement→AC completeness: **every requirement has ≥1 AC** and **zero unresolved `[NEEDS CLARIFICATION]`** (and happy+sad present per requirement *if* ACs carry a polarity tag — tag deferred; until then happy/sad coverage is the challenge-pass's job via Nagy's positive↔negative). A deterministic checker CAN decide it. _Avoid_: folding EP/BVA "did you partition correctly" into this gate — that needs domain judgment (semantic), so it lives in the challenge-pass, not the mechanical check.

**semantic completeness** — "does the requirement/AC set capture what the user actually needs" — the unknown-unknowns problem; **no mechanical oracle** (IEEE 830: completeness has no formal verifier). Permanently human-in-the-loop; the challenge-pass only *raises* the floor, never certifies it. _Avoid_: a mechanical "semantic completeness" check — claiming to verify it is itself a meta-level `claim > evidence` (a false-green about requirements).

## Build-phase vocabulary

The back-end half of the contract spine: the layers **below** human-accept that turn an accepted contract into a reviewed deliverable. Settled 2026-06-27 (skill-ceiling Phase 3.2 grill). `crucible` (§ Requirement-layer vocabulary) is the symmetric **front-end** orchestrator (terminates *at* human-accept); `anvil` is the **back-end** orchestrator (begins *from* the accepted contract).

**`touchstone:anvil` (back-end contract executor)** — the single back-end skill that takes the **accepted contract** (the design-spec crucible produced + the human accepted, already design-reviewed pre-accept) and runs the downstream pipeline behind one surface: **entry-precondition (the Phase-3.1 spine-integrity gate — freshness + structural floor) → `superpowers:writing-plans` → plan-review → `superpowers:subagent-driven-development` (SDD) → final cross-vendor review**. (Note: the *design-review* gate is **crucible's**, run pre-accept under the 3→2 front-load — it is NOT anvil's first stage; anvil's first stage is the lighter entry-precondition check that the already-reviewed contract is fresh.) Named for the forging series (touchstone / crucible / keystone): the crucible melts raw need into a contract, the **anvil** is the fixed surface the deliverable is hammered into shape against — the fixedness *is* the product (the deterministic stage backbone). It **reimplements none** of its sub-skills (invokes `writing-plans` + SDD at their boundaries) and adds only the deterministic stage sequencing + **stage-level** independent staffing of the cross-vendor final review (NOT per-task program-enforced independence — that stays SDD's soft loop, Level-B deferred; see honest ceiling). _Avoid_: calling it a "build" skill bare — "Build" is overloaded (see below); anvil spans plan→review, not just the coding stage.

**build orchestrator ≠ Stage-5 "Build"** — disambiguation. The global-workflow Stage 5 "Build (ATDD outer + TDD inner)" is the *coding* stage (SDD/TDD), which is **one stage inside anvil**. `anvil` (the build orchestrator) spans the whole accepted-contract → reviewed-deliverable pipeline (entry-precondition through final review), i.e. roughly global Stages 4–6 (the design-review gate itself is crucible's, pre-accept). _Avoid_: reading "build" as only the TDD/coding stage when it names the orchestrator.

**anvil span (the two human checkpoints)** — anvil is framed by exactly two human touch-points and nothing in between: **(top)** the human accepts the contract (crucible's terminus, anvil's entry precondition); **(bottom)** the human gives one **final-accept** on the reviewed deliverable sitting on a branch. anvil **stops at the reviewed deliverable on a branch** — SDD's per-task local commits are inside it (reversible), but **ship (push / PR / merge / release) is NOT** anvil's: ship stays the human-governed Stage 7 (outward-facing + hard-to-reverse → human-confirmed). _Avoid_: letting anvil auto-push/PR/merge — it presents for final-accept, the human ships.

**Level-A sequencing determinism** — the CORE of anvil: a **plain orchestrator skill** (a SKILL.md procedure that chains the sub-skills sequentially — the crucible precedent, NOT a Workflow-tool JS script; the `cross-provider-architect` review BLOCKED the Workflow substrate because SDD's in-session interactivity + opacity + the concurrency cap make it unbuildable there) that enforces the stage **order** and makes each inter-stage gate **un-skippable** even by a tired / context-compacted controller ("determinism is the product"). Determinism is **procedure-borne** (the written stage sequence + a structured-return contract anvil inspects), not JS-engine-borne. _Avoid_: equating Level-A with hard gates — it makes the *sequence* deterministic, not the *verifications* (see honest ceiling); and do NOT describe it as a Workflow-tool script (rejected for v1).

**Level-B per-task independence (program-enforced builder≠reviewer)** — the OPTIONAL deepening increment: re-own SDD's inner loop so the builder≠reviewer swap is a program-enforced control-flow step (distinct `agentType`s, swap can't be skipped). HYBRID (reuse SDD's scripts/templates, own the loop). NOT baseline — SDD is trusted-official and its whole design *is* the swap, so the soft inner-swap is low marginal risk; Level-B is a later increment, not v1. _Avoid_: treating Level-B as required for anvil to be honest — Level-A alone already buys deterministic sequencing + independent staffing.

**honest ceiling (anvil)** — the explicit limit anvil must NOT over-claim. **Level-A buys exactly two things:** (1) **deterministic stage sequencing** + (2) **independently-staffed cross-vendor FINAL review** (the final-review vendor ≠ builder) + collapsed human verify-cost (the planned ends). It does **NOT** buy: **hard gates** (the gate verifications inside stay agent-executed / soft, only deterministically sequenced + independently staffed); nor **program-enforced *per-task* builder≠reviewer** — the per-task swap stays **SDD's own soft internal loop**, which anvil does not strengthen in Level-A (that is the deferred Level-B claim). Scope "program-enforced independence" to the **stage level** (final review staffing), never to the per-task inner loop. Coercive/hard enforcement needs the harness/done-gate (a different rung — `touchstone-as-harness`). **Applied to sweep:** sweep's semantic saturation has no mechanical oracle (§ ground-and-sweep, intension-extension floor), so anvil **sequences-and-staffs** the gates that apply sweep but **does not verify** sweep is complete; its honest claim is "the sweep-applying gates were sequenced + independently staffed," never "sweep was verified complete." _Avoid_: marketing anvil as a hard gate, as program-enforcing the per-task swap, or as a sweep-verifier — all three are `claim > evidence` for Level-A.

**all-Q-hoisted-to-contract (the anvil precondition)** — anvil may run the downstream pipeline autonomously **iff** every quality judgment is lifted UP to the AC contract, so each downstream gate degrades to H / spec-compliance (machine-checkable `claim ≤ evidence`) with zero residual "is this good enough" taste. This is a HARD dependency, not conservatism: without contract-completeness (the feedforward arm — § Requirement-layer vocabulary), anvil is not merely weaker but **actively dangerous** — it *industrialises* a requirement-layer false-green (the whole pipeline endorses one contract gap; the human's end-accept is the only catch). anvil does **not** re-do completeness; it **checks the precondition holds at entry** via the spine-integrity entry gate (Phase 3.1, shipped: freshness + `traces-to` structural check over the attested surface). _Avoid_: running anvil against a contract whose challenge-result is stale or whose structural floor is unmet — that is the one failure mode the entry gate exists to block.

**anvil FLOOR (one linear gated pass)** — anvil is ONE linear gated pass, NOT a self-restart / cron / fleet / retry-loop. A **bounded inner convergence loop** (SDD's per-task review→fix loop) is allowed; an **unbounded throughput/fleet loop** is forbidden (that is throughput-manufacturing = G2, never touchstone's mission). _Avoid_: growing anvil into a "keep spawning until N green" loop — that manufactures throughput, not honest delivery.

**halt-on-stuck (anvil escape hatch)** — when an inner agent is stuck (a gate cannot converge), anvil **escalates to the human**, it does not silently retry-forever or pass-anyway. So anvil is **"autonomous + halt-on-stuck"**, never fully unattended. _Avoid_: describing anvil as "unattended" — the halt-on-stuck escape hatch is load-bearing for the honesty spine (a stuck gate must surface, not silently false-green).

## Verification vocabulary

Terms shipped by the `testing-strategy` epic (closed 2026-05-27). The evidence-honesty lens these terms describe is live in `code-review batch` and the `epic-driven-roadmap` close procedure.

**AC coverage (semantic)** — a per-AC judgment: does some test assert this AC's Then-clause? Decided by a fresh reviewer reading test source (LLM-judged), not measured. Boolean per AC: covered, or `[unverified: reason]`. _Avoid_: bare "coverage" — it reads as code-coverage %. This is NOT line/branch percentage and is never tool-measured. The deterministic tool only checks the standing spec state — every AC enumerable, every `[unverified]` carries a reason (a structural floor) — never computes a %.

**evidence-honesty criteria** — checks the existing reviewer applies during normal review: reads test source, judges AC↔test semantic coverage, forces `[unverified: reason]` on any AC it cannot confirm. A **lens, not a separate pass or agent** — the existing `code-reviewer` / `cross-provider-reviewer` runs it at gates that already exist (declare-strategy @ design-review, advisory @ batch). _Avoid_: "audit" / "auditor" / "honesty gate" — each nominalizes the lens into a standalone activity and wrongly invites a new agent, a new pass, or a new Review-Gate row. Say "the reviewer applies the evidence-honesty criteria".

**Evidence Reckoning** — the one genuinely new checkpoint: at epic close, every AC is reckoned — covered, or carried as an enumerated `[unverified: reason]` (live-bearing ACs may not use `[unverified]`). Blocking: the reckoning must be complete + clean or consciously waived. It hangs on the existing epic-close procedure; it is NOT a new row in the Review Gate table.

**evidence** (for an AC) — what backs the claim that an AC is done, scoped by phase. **P1**: in-repo test source + the AC's covered/`[unverified]` state, which the reviewer reads directly. **P2**: a **live artifact** (captured output of actually exercising a live-bearing behaviour against the real boundary — not a static proxy or mock), which needs provenance (P1 does not; deferred to P2). _Note_: the bedrock gloss "powered-on / 通電開一次" is narrative only — the glossary term is **live artifact**, paired with **live-bearing AC**. _Avoid_: treating the production diff or commit timing as evidence — the lens is production-source-agnostic and commit-agnostic; the accounting unit is the AC, never the commit.

**live artifact** (P2) — the captured output of actually exercising a live-bearing behaviour against the real boundary (not a static proxy or mock). It is a **product**, not an act: a file/transcript/log that gets fed to a fresh-context reviewer for authentication. _Avoid_: "powered-on artifact" as a glossary term (too device-leaning; the gloss is narrative-only); also avoid "live evidence" as a parallel noun — it is a narrative gloss for the same product, the canonical term is **live artifact**. Don't conflate the artifact with the reviewer that reads it (product ≠ judge).

**producer** (P2) — whatever actually powers on the live path and leaves a live artifact behind: a perf script invoking the real code, a hook firing in a real session, a build LLM session dispatching `Agent()`. Varies by dim. **Constraint: producer ≠ judge** — the producer may be a build session, but never the fresh-context reviewer that authenticates the artifact (else it rationalises work it produced; this is the existing builder ≠ reviewer discipline). _Avoid_: assuming a producer is always a shell command — an `Agent()` dispatch can only be produced by an LLM session, not a CLI.

**provenance** (P2) — the out-of-band marks a live artifact must carry so the reviewer can authenticate it as a real, current run: ① which producer/invocation made it (re-runnable or identifiable) + ② freshness (tied to current code: commit/timestamp). Authentication burden scales with how fakeable the producer is (a hand-pasteable perf log demands ① + ② harder; a real `Agent()` transcript is largely self-attesting). The deterministic floor checks only that the artifact exists and is referenced by its AC — it never judges authenticity; that is the reviewer's. _Avoid_: a crypto-attestation / signing engine — over-engineering for a markdown plugin whose close has a human in the loop (cf. ADR-0009 over-spec guard).

**challenge-result** — the JSON attestation (`<spec-stem>.challenge.json`, schema `challenge-result/v2`) that an INDEPENDENT challenger (challenger_id ≠ author_id) ran the requirement→AC completeness challenge-pass over a spec: `author_id`, `challenger_id`, `input_digest` (attested surface), `normalizer_version`, `findings[]`. Validated by `scripts/check-challenge-result.py`; fails closed. _Avoid_: treating it as a coverage record — it carries clarification findings, not a verdict.

**attested surface** — the portion of a spec a `challenge-result` vouches for: the normalized bodies of `## Foundation` + `## User Stories` + `## Acceptance Criteria` (want-layer + AC), hashed into `input_digest` by `spec-extract.sh digest`. A post-accept edit to any attested section changes the digest → the attestation goes stale. _Avoid_: assuming AC-only — that was the pre-3.1 gap.

**freshness (challenge-pass sense)** — whether a `challenge-result`'s `input_digest` still matches the spec's current attested-surface digest AND its `normalizer_version` matches the extractor's. Distinct from **provenance freshness** (P2 — the commit/timestamp tie of a live artifact): this is a design-time spec-vs-attestation match, not runtime artifact recency. _Avoid_: conflating the two.

**live-bearing predicate** — an AC is **live-bearing** ⟺ its Given/When/Then asserts a behaviour that cannot be discharged offline (un-owned / wired / deployed / real-scale boundary); classify by behaviour, not a keyword list; if ambiguous, treat as live-bearing. **Full predicate + injectable text** (the verbatim text `design-review` and `code-review batch` load-and-inject into their cold reviewer): `skills/_shared/inject/live-bearing-predicate.md` (single home).

**AC-coverage-honesty principle** — `claim ≤ evidence` for ACs: an AC may not be claimed done unless evidence asserts its Then-clause; mark `[unverified: reason]` otherwise (never pass by default); an AC done with neither is a silent false-green. Baseline/spine — injected **unconditionally**. **Full rule + injectable text:** `skills/_shared/inject/ac-coverage-honesty-principle.md` (single home — injected by `design-review` / `code-review batch`).

**ground-and-sweep doctrine** — two orthogonal per-unit tests (ground-before-assert + sweep-to-dry) applied on both the feedforward (design-spec) and feedback (design-review) arms. **Single home:** `skills/_shared/ground-and-sweep.md` (dual-use carve-out — see § Template co-location and ADR-0017).

**design-soundness lens (two-arm)** — the design-quality arm: a **feedforward arm (FF)** applied at `design-review` (subject = spec document) that uses the depth-stakes decision rule to detect components whose `## Architecture` is descriptive-only (no SHALL commitments) and raises a missing-commitment finding; and a **feedback arm (FB)** applied at deliverable review (`anvil` Stage-5 final review + `code-review batch`) that enumerates the spec's SHALL commitments and judges each as honored, violated, or `[unverified: reason]` against the whole deliverable vs the whole `## Architecture`. The two-arm definition is the single home; consuming surfaces load-and-inject it verbatim and never restate it inline. **Single home:** `skills/_shared/inject/design-soundness-honor-check.md`. _Avoid_: copy-pasting the fragment body into consumer surfaces (a static body copy is the AC-13 violation); also avoid applying the FB arm to per-diff scope (it is subsystem scope — whole deliverable vs whole `## Architecture`).

## Epic-tracker projection vocabulary

The `epic-driven-roadmap` skill keeps its work-content in a local markdown index (`.touchstone/epics/<slug>/index.md`) as the single source of truth. Shared trackers (GitHub / GitLab Issues, Jira, Linear) are downstream **projections** of that index, never a second home. (Supersedes the storage-adapter model of ADR-0012 — the bidirectional code adapter solved a non-problem for an LLM substrate; the agent is the shim.)

**agent-as-universal-shim** — the LLM natively reads and writes any format, so no code shim sits between the skill and a backend. Forward projection (render the index onto a tracker card) and any reverse reconciliation (read a tracker via `gh` / CLI / MCP, diff, self-update the index) are both done by the agent semantically. _Avoid_: "storage adapter" / "shim layer" as a code component — the shim is the agent, not a script.

**projection** — the one-way render of the index's shared subset (aim, phases-as-checklist, status, back-link) onto a tracker card, produced at need. Lossy by design: close-only internal artifacts (retrospective, Doc Reckoning, Evidence Reckoning) are not projected. _Avoid_: "sync" — implies bidirectional parity; projection is one-way local→tracker.

**reconciliation** — the reverse path, built only if a real consumer needs it: the agent fetches tracker state and diffs it against the local index, then updates the index. Semantic, agent-performed, no schema or round-trip contract. Not a standing mechanism (YAGNI until a tracker is a genuine upstream author).

**field-location mapping** — the only deterministic per-tracker artifact: a small declarative table of where each index field lives on a platform (which API field / card location holds slug, status, phases). Keeps field retrieval unambiguous during projection / reconciliation. Not a round-trip adapter — a lookup table.

**canonical minimum** (template-field discipline) — the index template holds only what a touchstone gate reasons about (slug / status / started / landed / aim / intention / out_of_scope / phases[].{n,title,status,landed} / retrospective / open_questions). Decorative or backend-specific fields stay out of the gated set. **Review test (kept from ADR-0012):** every proposed index field must answer "which gate reads this?" — if none, it does not belong in the gated template. This is now template-design discipline for one local home, not a cross-backend contract.
