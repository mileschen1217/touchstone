---
type: handoff
direction: inbound
date: 2026-06-19
from_repo: obsidian-ai_explosion_kb
from_doc_audit_pointer: "ai_explosion_kb/Loop Engineering vs touchstone — first-principles 推導.md"
to_epic: touchstone-as-harness
kind: design-input
related:
  - docs/handoffs/2026-06-01-from-claude-code-config-discipline-gaps.md
---

# Inbound handoff — touchstone's positioning floor & the harness terminus (first-principles)

**Sender:** Obsidian `ai_explosion_kb`, first-principles session 2026-06-18/19.
**Canonical content:** `ai_explosion_kb/Loop Engineering vs touchstone — first-principles 推導.md` (the full derivation trail + Mermaid + applicability boundary). This handoff is the *actionable distillate* for touchstone maintainers — the asks, not the proof.
**Kind:** design-input / strategy. No code change requested yet; this fixes touchstone's *coordinates* and names one strategic decision (whether/when to build touchstone-as-harness).

## TL;DR

A first-principles descent on "loop engineering vs touchstone" grounded out at **two non-intersecting force-sets**, which pins touchstone's job precisely:

- **loop engineering** roots in `G1 (intent/accountability non-delegable) × G2 (bounded supervision bandwidth)` → it optimizes the **scarce human**. Price-sensitive.
- **touchstone** roots in `F1 (representation ≠ reality) × F2 (no total oracle / taste)` → it guarantees the **correctness invariant** `claim ≤ evidence`. Price-independent.

They couple through ONE channel: **verification cost (F1×F2) is the largest line-item drawing on scarce attention (G1×G2)**. ∴ touchstone is not loop engineering's competitor — it is the *precondition supplier* that lets a loop run unattended (you cannot parallelize or automate an unreliable unit).

Three things follow that touchstone should act on. ↓

## Ask 1 — Hold the positioning floor: F1×F2, not G1×G2

**Finding.** Mapped to Addy Osmani's ladder, touchstone = **harness-engineering** discipline (attacks the *verification* root), specialized to **F1×F2 + honesty spine**, at spec/epic grain. The other two ladder rungs attack the *attention* root on orthogonal axes: **factory** (space — parallel fleets) and **loop** (time — self-restart). Runtime containment is always `loop ⊃ factory ⊃ harness`; harness is the foundation both stand on.

**Ask.** Keep touchstone on the F1×F2 axis. Do **not** grow temporal/scheduling/fleet features (cron, loop, goal-restart, worktree fan-out) — those are CC-native loop/factory territory (G1×G2). touchstone's only interface to that world is: **drive verification cost → 0 and emit a machine-readable verdict** (`result.json` / `review.result.json`). Build the quality core, not the heartbeat. This is a floor, not a preference: F2 (taste not fully formalizable) is *why* touchstone is inherently human-in-loop — `[unverified]` and builder≠reviewer are floor necessities, not conservatism.

## Ask 2 — Adopt the gate-placement taxonomy as the design constraint

**Finding.** Inside CC, a deterministic gate has exactly three possible positions, with hard ceilings:

| Gate position | Achievable in CC? | Property |
|---|---|---|
| **inline** (anywhere in a workflow sequence) | ✗ agent-mediated only (Workflow JS is a sandbox — can't run shell itself) | ~99%, LLM on the execution path |
| **event-bound** (commit / stop / tool-use hook) | ✓ `type:command` hook, shell + exit code, no LLM | 100%, but event-bound & synchronous-blocking |
| **external** (push boundary → CI) | ✓ runner the agent can't touch | 100% **+ un-forgeable** |

**Two precise consequences for touchstone's gate design:**

1. **The strongest gate touchstone can ship in CC today = the CI-handoff pattern**, not an inline one. Architecture: CC (subscription OAuth) orchestrates + executes → `git push` → CI runs the *real* oracle (full suite, no timeout, on a machine the agent can't write to) → CC reads the verdict via `gh`. The trust boundary is the **push**, not the harness.
2. **"un-forgeable independence" is a trust-boundary property, NOT a harness property.** An agent with write access to the repo can hollow out tests / weaken the oracle definition so it genuinely returns 0 — *switching harness does not fix this* (a self-built harness whose agent still writes the test files has identical forgeability). Independence comes only from putting the oracle in a band the agent can't reach. Corollary: touchstone's `builder ≠ reviewer` is the *inline approximation* of that boundary; the *physical* version is CI. Don't sell harness-swap as the independence fix — sell the boundary.

## Ask 3 — Name the terminus explicitly: skill is the ceiling, harness is the endpoint

**Finding (the strategic one).** `orchestrator = the determinism layer`: whoever sits on top decides how deterministic an *inline* gate can be.

- **CC on top** (today — touchstone-as-skill): top is an agent → every inline action goes through an agent → inline gate caps at ~99%.
- **program on top** (calling CC): top is deterministic code → it can `exec` a gate as a program step *and* call an agent as an agent step → **inline gate becomes pure program, 100%.** The workflow becomes `agent & program mixed`, program on top.

So the **only** structural way to get freely-placeable inline determinism is the **inversion**: lift the discipline into a deterministic orchestration layer that sits *above* CC, demoting CC/codex to called executors. There, `builder ≠ reviewer` stops being "please don't let two agents peek" and becomes a **program-enforced step**; a gate stops being "an agent runs the tests" and becomes the orchestrator's own `exec` + exit-code read.

**∴ touchstone-as-skill is the ceiling of the CC-inline coordinate, not the endpoint. The endpoint is touchstone-as-harness.**

**The honestly-marked cost (decisive).** This inversion is a **B2 cost-arbitrage decision, not a free capability upgrade**:

- Anthropic has announced **programmatic agent usage (incl. `claude -p`, Agent SDK) will count as API usage** (currently paused — assume it eventually lands). Any "external program calls CC" path is therefore **per-token API**, not subscription.
- Deep symmetry: the subscription prices the *human-in-the-loop interactive band*. Loop engineering's whole goal is to remove the human from inner prompting — and the moment you automate the human out, you leave the band the subscription prices. You cannot buy "unattended loop" at the subscription rate; the billing reclassification closes exactly that arbitrage.
- **The CI route (Ask 2) keeps the subscription** (CI runs tests, doesn't call Claude). The harness route does not.

**Ask.** When touchstone's roadmap considers a harness/SDK orchestration layer, frame it as: *unattended-loop value > per-token cost + lost subscription?* — **Yes → build touchstone-as-harness (API-billed). No → stay touchstone-as-skill + CI for independence.** Personal / low-frequency / human-couplable use → stay inline+CI. High-frequency / unattended / productized → invert. Do not present the harness as strictly-better; mark the band-exit cost in any proposal.

## Supporting model (for whoever picks this up)

**Two deterministic layers sandwich one stochastic layer** — the shape every touchstone workflow already implies:

| Layer | Nature | Owner |
|---|---|---|
| orchestration skeleton (task → gate → review control flow) | **deterministic** | orchestrator |
| each gate's acceptance oracle (exit code) | **deterministic** | frozen spec / GWT |
| task internals (how the agent writes the code) | **stochastic** | unmanaged |

- **spec-freeze = the gating variable.** Freezing the spec doesn't make *execution* deterministic — it **moves F2 (taste) out of every cycle**. Before freeze each cycle asks "is this what we want?" (F2, needs a human, no exit code → un-gateable). After freeze each cycle asks "does it match the frozen spec?" (F1 only → deterministic → gateable). The phase boundary lands on that cut. **Freezability (per-cycle F2 density) decides whether a phase can be spun-off + hard-gated at all** — exploration/design-aesthetic-as-deliverable can't be frozen, so it stays human-coupled no matter the band. This validates touchstone's contract-first order (Problem→Scope→AC(GWT)→Arch→Interfaces) and ATDD's RED-before-impl: an acceptance test authored *before* implementation is one the agent **can't edit to match its output** = structural anti-Goodhart, not request-based "don't cheat."
- **"Not fit" is a first-class edge, not an exception.** Deterministic only describes the happy path. When runtime evidence shows F2 leaked past the freeze, the inner loop returns `BLOCKED` and kicks back across the boundary to the orchestrator (which can solve F2: amend spec/workflow, re-spin-off; `resume` re-runs only the changed suffix). CC Workflow nesting is **1 level only** → big workflows are **not** one mega nested script but the **orchestrator sequencing modules across turns, reading each result before the next**. The seam between modules = the orchestrator being structurally re-invoked = "kick back to orchestrator" is architecturally built-in. **module grain = one freezable mini-spec + one hard gate + a clean typed contract = your epic task contract (`contract.md` in / `result.json` out).** Deterministic *inside* a module, human-orchestrated *between* modules.

## Recommendation

This is design-input, not a bug. Suggested handling:

1. **Accept Asks 1 & 2 as standing design constraints** — they describe what touchstone already is and where its strongest gate lives; cheap to ratify, prevents scope drift into loop/factory territory.
2. **Open (or stub) epic `touchstone-as-harness`** to hold Ask 3 as a *deferred, cost-gated* direction — not to build now, but so the terminus is named and the B2 trigger condition (unattended/high-freq/productize) is written down rather than rediscovered later.
3. If maintainers disagree with the positioning floor (Ask 1) — e.g. touchstone *should* grow loop features — reply on the canonical note; that's the one claim whose rejection changes everything downstream.

## Provenance

- First-principles session: Obsidian project, 2026-06-18 (descent) → 2026-06-19 (landing + terminus).
- Canonical derivation: `ai_explosion_kb/Loop Engineering vs touchstone — first-principles 推導.md` (status: budding; full descent trail, Mermaid, applicability-boundary table, Osmani anchor).
- Application-layer companion: `ai_explosion_kb/Loop Engineering — 意圖、社群實作與 touchstone 適配.md`.
- External anchor: Addy Osmani — Factory Model / Agent Harness Engineering / Loop Engineering (addyosmani.com).
- This handoff lives in touchstone's `docs/handoffs/` (committed, durable); the sender keeps the canonical content in the Obsidian vault note above.
