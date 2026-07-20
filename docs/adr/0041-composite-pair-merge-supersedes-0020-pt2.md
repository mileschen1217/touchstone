---
kind: workflow
adr_id: 0041
status: Accepted
date: 2026-07-20
supersedes: 0020 (pt 2's composite-pair application only)
---

# ADR-0041: Composite-pair merge (supersedes ADR-0020 pt 2's pair ruling; the general deep-module-over-merge rule stands)

## Status

Accepted. The decision itself was made by the human at the P3 Batch 2 spec accept
(`.touchstone/epics/v2-dilute/2026-07-19-cross-provider-slim-design.md`, confirmed-fact F2:
architect/reviewer 兩腳色合一, miles 逐項裁定 2026-07-19); this ADR records it against the
standing corpus after the post-merge fresh-session live review (the spec's deferred
live-witness half) caught the un-superseded contradiction.

## Context

ADR-0020 pt 2 (2026-06-23) ruled the two Pattern-A composites (`cross-provider-architect`,
`cross-provider-reviewer`) NOT merged, on that date's measurements: shared in-body scaffold
~20 lines, ~84/194 lines differing, genuinely different synthesis; flip-trigger (0016 pt 4:
3rd composite OR shared >50 lines) not met. It warned a `{architect|reviewer}`-parameterized
engine would be a shallow module.

By P3 (2026-07-19) the measured basis had moved: the shared substance had grown past the
standing flip-trigger — `pattern-a-base.md` (31 lines) + shared `provenance.md` consumption +
near-identical skill skeletons + the two codex wrapper agents' duplicated cold prompts, which
the dup-block checker could only hold as two baseline-exempted fingerprint clusters
("cross-provider composite pair", "codex agent trio") — a standing mechanical witness that
the pair now shared more than it diverged. The v2-dilute fitness (每契約元素說得出消費者)
also exposed that the architect composite had a single caller (assay structural-fork).

## Decision

Merge the pair into one composite (`cross-provider-reviewer`, internal role 二值
`review` | `architecture-critique`) and 4 arm agents into 2. The shallow-module risk 0020
named is mitigated, not ignored: the role enum is closed at two; each role's lens, synthesis
rule, and fallback row is a cohesive, separately-grep-able section; the dispatch matrix has
a single home; the divergent expertise (validation rubric / adversarial pressure-test)
travels as content blocks via the envelope `system_prompt`, not as interface parameters the
caller must understand.

**0020's general rule stands unchanged:** prefer two cohesive deep modules over one
parameterized shallow module; merge only when the shared substance dominates. What changed is
the pair's measured facts crossing 0016 pt 4's own flip-trigger — this is the trigger
firing, not the rule bending.

## Consequences

- Callers address one name; `architecture-critique` is an envelope role, not a skill.
- The Codex wrapper carries one deliberate new capability seam: a bounded Bash-read
  exception to return the `-o` result file verbatim (transport), and the CC arm's critique
  Bash bound is prompt-level (spec REQ-2's 明文 residual risk).
- Flip-trigger (re-split): if a third internal role appears, or a role's section grows past
  what one skill file holds cohesively (~half the file), re-open the split question.
- Ratchet from the miss that surfaced this ADR: design-review's doc lens now sweeps the ADR
  corpus for standing decisions a spec reverses (same commit as this file).
