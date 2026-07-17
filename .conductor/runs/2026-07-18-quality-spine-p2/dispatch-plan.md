# Dispatch plan — quality-spine P2 build (conductor, inline topology)

Run: quality-spine-p2-20260718 · commander: claude-opus-4-8 · doctrine_rev 33ec134
Spec: .touchstone/specs/2026-07-17-quality-spine-p2-loop-hardening-design.md (accepted, 15 REQ / 42 AC)
Wrapper: anvil (SDD replaced by conductor per human directive); retained obligations =
final cross-vendor review, branch-only stop, spec REQ-1 stopping rules bind all build-period
review events, REQ-9 attestation-ledger line per doctrine-carrying cold dispatch.

## 1. Entry decision

- **Write shape: inline (0-worker).** Commander keeps the pen; mode discipline (per-wave
  contract intent, journal, checker on the one dispatched result, human-reserved acceptance)
  still applies.
- **Read breadth: 0** until acceptance. **Advisor: unavailable** (no /advisor this session;
  moment_id 1 logged advisor_unavailable).
- **Grounds:** amortization brake fails for every discretionary edit offload (below), and no
  necessity ground is truthfully citable — Opus 1M context holds the ~15-file + fixtures +
  42-AC corpus (corpus-exceeds-context false), the REQ write surfaces overlap heavily
  (batch-mode.md touched by REQ-1/5/8/14 → clean disjoint-write partition impossible),
  no wall-clock deadline.
- **Task family: write-heavy** (deliverable write surface = skills/ + scripts/ + docs/ edits;
  non-empty).
- **Price row:** constants row `write-heavy@forced-1w/2026-07-17T16:13:12Z` cited for the
  brake; NO `discipline-price` row exists for write-heavy (ablation-pair-only) → **refusal
  ground disabled**, annotate `[pending-measurement]` on the refusal axis. Gate opens
  regardless (accepted spec, high value, committed build).
- Human veto: none (human directed this build; topology is commander's within it).

## 2. Shape & precedent

`task-shape: kind=doc+script-build, write_surface=skills/+scripts/+docs/+.touchstone/checker/`
family: write-heavy
`precedent: no-match` (.conductor/precedent.jsonl empty — first conductor run in touchstone)

## 3. Brake line (wave N — the one mandated dispatch)

brake: offload=[{tier:mid,W≈6000,r=0.4}] save=3600 pay=30498 verdict=fail
ground=none(doctrine-mandated) constants_row=write-heavy@forced-1w/2026-07-17T16:13:12Z
r_rev=2026-07-17 k_note="fresh-context verifier is the one non-discretionary offload
(§ Verification, builder may not hold it); economics-fail non-blocking per § Amortization
brake boundary. All build editing stays inline (discretionary offload fails brake:
break-even W≈50830 out-tok/worker, no edit group approaches it)."

## 4. Subtask table (inline waves — audit degrades to the judgment stream per § Single-writer)

| wave | task-group | REQ/AC | grade (inline) | why-not-a-script |
|---|---|---|---|---|
| W1 | stopping-rule single-home fragment + 5 wiring sites + enum/blocked/no-3rd-round | REQ-1/2/3/15 + AC-41/42 | frontier (new shared contract text, cross-file invariant: one home, 5 deltas) | designing a normative fragment + site deltas is authoring, not pattern-apply |
| W2 | witness lines + presence checker | REQ-5 + AC-13/14/15/39 | frontier (new checker logic + fixtures + 2 intake sites) | checker semantics + red/green fixtures need judgment |
| W3 | template six-sections + traces() vocab + live-bearing index + soundness migration | REQ-6/7/8 + AC-16..22/40 | frontier (digest-semantics invariant: spec-extract byte-identical; template restructure) | digest-preserving edits + checker both-forms need judgment |
| W4 | attestation ledger close + ADR-0017 rewrite + fragment conversions | REQ-9/10/11 + AC-23..28 | frontier (measurement ruling n=14/13y; ADR policy rewrite; 3 conversion sites) | policy ruling + conversion correctness need judgment |
| W5 | residual P1 edits + U-a core fragment + dup-block baseline | REQ-13/14 + AC-31..36 | mid/frontier (mechanical thinning + baseline deletes, but single-home design) | baseline-fingerprint correctness + fragment wording need judgment |
| W6 | H-6 arm record verification (P2 own design-review already ran) | REQ-12 + AC-29/30 | inline verify (record already exists: h6-arm-record.md) | reading/confirming an existing record |
| W7 | net-bytes + full suite green + FRESH-CONTEXT VERIFY (dispatched) + anvil final review | REQ-1 AC-5 + AC-34/37 + acceptance | mid worker (fresh verifier) + tier-0 (suite) | acceptance may not be builder-held (§ Verification) |

Deviation log: opens at first deviation event.
