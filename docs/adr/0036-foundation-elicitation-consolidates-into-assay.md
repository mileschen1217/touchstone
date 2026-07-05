# 0036 — Foundation elicitation consolidates into assay (crucible chain)

- **Status:** Accepted (human-ruled 2026-07-06, assay interview)
- **Deciders:** miles (bet-owner), AI (proposer)
- **Triggered by:** `/touchstone:assay` (gate-reaudit run, 2026-07-06 — structural-fork case)
- **Related ADRs:** 0035 (this executes its deferred flip-trigger). The intention-first Baseline itself stands — only its chain-position moves (its classification decision predates this public ledger).
- **Flip-trigger:** the miss ledger or an assay deviation log accumulates ≥2 entries across ≥2 epics where a wrong-scope defect passed the contract stage because intention/aim/out-of-scope was not re-elicited at design-spec time inside a crucible chain (i.e. assay's extraction missed what foundation-gate's later-positioned re-ask would have caught). Revisit point: the owning epic's insight round rules a re-split.
- **Bet-owner:** miles
- **Assumptions (bets, not implementation facts):**
  1. assay Stage-1b's extraction is a strict superset of foundation-gate's 3 fields in chain context (static measurement 2026-07-06: 3/3 fields overlap — intention↔intent, aim↔what-done-looks-like, out-of-scope↔unstated-constraints partial + guardrail head's explicit out-of-scope).
  2. The consistency-check value of asking the same human the same 3 questions twice in one sitting is lower than the interview-fatigue cost; today's double-ask is accidental (zero designed hand-off), not designed redundancy.
  3. Scaffold-time elicitation (epic-driven-roadmap Step 0) and direct design-spec invocation keep foundation-gate alive on the non-crucible paths, which remain sufficient there.

## Context

v0.16.0 wired assay as crucible's unconditional pre-contract interview. Measurement (the assay run's discovery probe, 2026-07-06): all 3
foundation-gate fields (intention / aim / out-of-scope) have a counterpart in assay
Stage-1b's 4 asks; no hand-off exists in any skill text — inside one crucible run the
human answers the closest pair twice. ADR-0035 deferred exactly this with a
measure-then-rule flip-trigger; the measurement now exists and the bet-owner ruled.

## Decision

Inside the crucible chain, **assay is the single human-elicitation surface** for
foundation content. design-spec's Draft Mode consumes the assay guardrail block's
head (scope / contract facts / out-of-scope) as its Foundation fields and does NOT
re-elicit when an assay record exists for the subject. foundation-gate survives
unchanged on the two non-chain paths: epic-driven-roadmap Scaffold (Step 0) and
direct `/touchstone:design-spec` invocation without a prior assay record.
`scripts/check-foundation-gate-structure.sh` stays: the spec still carries a
Foundation block — only its source changes (assay head instead of fresh elicitation).

## Alternatives considered

1. **Hand-off/delta branch** (foundation-gate gains an "assay record exists → ask only
   the delta" case) — rejected by bet-owner: keeps two homes for one elicitation and
   adds a per-run conditional; the duplication root survives.
2. **Keep the double-ask as deliberate redundancy** — rejected: no designed
   consistency-check consumes the second answers; the redundancy is accidental.
3. **Status quo ("change nothing structural")** — rejected with the same evidence.

## Consequences

- Edits (Phase-2 PR, version bump): `skills/_shared/foundation-gate.md` caller
  contract (crucible-chain case → consume assay record), `skills/design-spec/SKILL.md`
  Draft Mode (consume-or-elicit branch), `skills/assay/SKILL.md` (Stage-3 head named
  as the foundation source for the chain consumer).
- Non-chain paths and the deterministic checker are untouched.
- `cross-provider-architect` critique dispatch was **omitted** (assay allows
  adaptation with recorded reason): the fork was ruled by the bet-owner on a complete
  static duplication measurement with alternatives explicitly weighed, and a cheap
  flip-trigger is installed; a critique pass on a doc-topology decision did not
  justify its cost.
