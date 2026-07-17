---
injected-by: [design-review, anvil]
referenced-by: [design-spec, code-review, crucible]
kind: bridge
---

# Severity-tiered stopping rule (single home)

The one normative definition of how a bounded AI review loop in this suite
terminates. A consumer loads this file and carries only its own site delta; no
site restates the rule (`check-dup-block.sh` backstops restated copies).

**Vocabulary.** Tier A = deterministic machine verdict; Tier B = deterministic
trigger + judgment disposition; Tier C = judgment only. T = 3
(calibration-adjustable: an adjustment is a human ruling recorded in the epic's
calibration ledger, applied as a spec/skill edit). Autonomous budget = initial
review + at most ONE re-verify dispatch. "Zero new findings" is a stopping
criterion nowhere in the suite.

**Initial round — decide by the verdict:**

| verdict | action |
|---|---|
| ≥ 3 same-class C/H | enumeration clause first (suspend, one human ruling, sweep all sites), then the matching row below |
| any Critical, or High ≥ T | fix all → ONE combined re-verify dispatch (single dispatch covers all fixes; boundary pin: H=T re-verifies, H=T−1 closes) |
| 0 Critical and High < T | fix all → close; fix diff rides the verdict to the next existing human checkpoint (clean round: nothing to fix, no diff attaches) |

**Re-verify round — budget spent; no further autonomous dispatch on any path:**

| verdict | action |
|---|---|
| any Critical | blocked escalation (three-path menu at the checkpoint); further rounds only per the no-unauthorized-third-round rule |
| High only (any count) | fix; diff + markers ride the verdict to the checkpoint (the human may authorize more rounds there) |
| ≥ 3 same-class (C or H) | the class question rides the blocked item / closing verdict to the checkpoint — the enumeration clause never fires autonomously here |

**Every round:**
- Residual Medium/Low: marker lines ride the verdict to the human; a transient-bridge Low passes.
- A dispatch that fails before returning a verdict is a technical failure, not a
  round: one technical retry (outside the budget); still failing → blocked path
  noted "re-verify incomplete". Never a silently skipped re-verify, never a
  fabricated verdict.

**Challenge-pass adaptation** (findings are ungraded markers; the C/H tiers do not apply):
- Rounds: initial challenge + ONE re-challenge after resolutions; every unresolved marker blocks.
- Marker routing by question content, not the REQ-N tag: US/REQ-semantic (the
  answer would change a US sentence or a REQ SHALL headline) → the human;
  otherwise AC-level → resolved by the authoring AI, logged. The terminal human
  accept covers both.

## Enumeration clause (≥ 3 same-class C/H)

When three or more High or Critical findings in one round share defect class and
fix shape, suspend fixing and obtain one human boundary ruling before sweeping
all sites. No per-site fixing; one boundary question to the human; the ruling
then sweeps ALL sites (including unreported ones) before the single re-verify
round. The Critical floor is unchanged — after the ruling sweep, re-verify
remains mandatory when Criticals were present. Same-class determination is
loop-runner judgment (Tier C) on the deterministic third-finding trigger — when
in doubt, treat as same class (one ask is cheaper than a rediscovery round) —
with the class definition recorded in the ruling line. The ruling ask is
synchronous by design: the suspended round depends on it (a dependency-point
exception, not a new exception class); the suspension does not consume the
autonomous budget — the suspended round resumes after the ruling and completes as
the same round. A cross-engagement recurrence may only graduate as a
deterministic check with red/green fixtures (graduation trigger: the same
boundary appears in a second engagement's ruling; proposed to the human, never
automatic); the suite's skill prose gains no new standing rule sentence from a
single ruling.

Ruling line format (in the engagement record):
```
ruling:<date> | class: <recorded class definition> | ruling: <human decision> | swept-sites: <comma-separated site list>
```

## Blocked escalation (Critical survives re-verify)

When a Critical finding survives the re-verify round, mark the artifact blocked
and surface it batched at the next existing human checkpoint. The artifact stays
non-passing (spec not accepted / commit not made / batch not closed). All blocked
lines are presented together with the three-path menu at the next checkpoint
(terminal accept / PR approve / batch report); no synchronous mid-flow human ask
occurs for them — except where a next work item depended on a blocked item, in
which case the ask happens at the dependency point.

Blocked line format (one line in the engagement record — four fields separated by
pipes; multiple values within one field separated by commas):
```
<item id> | <surviving blocking findings: Critical, or US/REQ-semantic challenge markers unresolved after the bounded re-challenge> | <final-round verdict ref> | <dependents>
```
Each human re-authorization appends a `| reauth:<date>` suffix to the item's
blocked line; the re-authorization count IS the number of such suffixes.

Three-path menu at the checkpoint: authorize one more round (resets the
autonomous budget once) / change approach / cut scope. Re-authorization is
uncapped — each is an explicit human act; the count is tracked per blocked item
(on its blocked line); from that item's second re-authorization onward the
orchestrator surfaces the change-approach doctrine (same error class surviving a
fix round = change path) alongside the menu.

## No unauthorized third round

While a re-verify round reports any Critical, the loop SHALL NOT dispatch a
further review round without explicit human authorization (a recorded
authorization line). The three-path menu is the only path past this point.
