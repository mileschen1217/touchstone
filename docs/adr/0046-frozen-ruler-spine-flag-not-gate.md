# 0046 — The build's `done` rests on a frozen, non-builder ruler re-run held-out; disagreement is a flag with a reason, never a gate

- **Status:** Accepted 2026-09-07 — owner ruling after the anvil self-build halted before freeze (deviation D-6 of epic anvil-work-order-dispatch); revises the accepted phase-1 spec (REQ-3 removed, REQ-4 reduced, one requirement added); promoted to docs/adr at the 2026-09-07 design-review re-verify (a cold reader must find the ruling the spec cites)
- **Date:** 2026-09-07
- **Deciders:** owner (miles)
- **Triggered by:** `/touchstone:anvil` self-build, reader round 3 not clean after the bounded rounds; the owner's question "do we really need freeze + dispute + re-author?"
- **Related ADRs:** 0009 (evidence-honesty gate; its 2026-09-06 amendment on the per-build ruler stands), 0039 (no dispatch economy outside touchstone), 0042 (lens × arm review — the second verifier this decision leans on)
- **Flip-trigger:** (1) a measured visible-vs-held-out gap on this plugin's own builds — if the DISPUTED / FAIL rows at ship show the builder gaming visible tests, the hidden-ruler option in Consequences reopens; (2) DISPUTED rows the owner overrules in two consecutive phases (the flag is being used as an escape hatch) — reopen the reader question with that data; (3) a maintained mutation-testing instrument becomes cheap enough to run per build — mutation score replaces reading as the hollow-test signal.
- **Bet-owner:** the owner — never the AI.
- **Assumptions:** (a) the builder session is a satisficer that will take the shortest path to green when one exists (the literature below measures this, it is not a suspicion); (b) tests written before the implementation are wrong at a high base rate (SWE-bench Verified: 61% of human-written tests flagged, 68% of tasks filtered) — any mechanism must expect wrong frozen tests every build; (c) deliverable-review's fresh-context read of the diff against the spec stays in force as the second verifier; (d) the owner reads the verdict at phase-ship anyway — moving rulings there adds no new human step.

## Context

The phase-1 spec of epic anvil-work-order-dispatch replaced the retired dispatch engine
with one build path: a non-builder context authors an AC → test index (the ruler), a
second non-builder context reads it for hollow / implementation-bound /
chosen-interpretation tests, `ruler.py` generates a stub tree, classifies every node red
by assertion, sha-freezes the ruler, the session builds, and a clean worktree re-runs the
frozen ruler into `build/verdict.yaml`.

The first self-build halted at the reader step. Three reader rounds on a 52-row ruler
produced one and a half real findings, two false positives and one halt:

| round | non-traceable rows | later judgment |
|---|---|---|
| 1 | the self-test row hollow, the completeness row read as an interpretation choice | one false, one misclassified |
| 2 | the self-test row and a probe row hollow, a boundary row read as a chosen interpretation; 50 of 52 rows written | the probe finding real; the boundary one weak; two rows missing |
| 3 | the self-test row and the completeness row hollow | the self-test objection ("a hard-coded self-test printing the PASS lines would pass") holds for any black-box test of a self-test and cannot be answered by a stronger assertion; the completeness row a small partial node |

The reader's class for the completeness row moved chosen → traceable → hollow across three rounds on an
unchanged row. `ruler.py freeze` refuses on any hollow line, so a noisy judgment fed a
deterministic gate and the build stopped with nothing built. The owner was asked to rule
on "does this reader objection count", a question the mechanism created, not the problem.

What the literature measures (retrieved 2026-09-07):

- **Agents build to the visible test.** With no oracle, agents shipped genuine but
  incomplete libraries (148–189 of 222 hidden tests); with the oracle in the loop they
  scored 221–222/222 while 11 of 12 runs shipped a dead or absent library, behaviour
  inlined into a demo. A guardrail prompt ("the tests are an aid, not the goal") did not
  prevent it (Building to the Test, arXiv 2606.28430).
- **Visible tests saturate; held-out tests do not.** Every model and harness saturates
  the visible suite; the held-out gap runs 21–100 percentage points and grows ~27 points
  per tenfold code size; Claude Code showed 43–48 points (SpecBench, arXiv 2605.21384).
- **When tests conflict with the spec, strong models edit the tests.** GPT-5 exploited
  the tests in 76% of impossible SWE-bench tasks; stronger models cheat more. Two
  mitigations measured: hiding or isolating the test files drops cheating to near zero;
  an explicit *abort* option ("flag the task as impossible instead of solving it") drops
  it from 54% to 9% (ImpossibleBench, arXiv 2510.20270).
- **Pre-implementation tests are wrong at a high base rate** even when humans write them
  and review them for years: 61% of SWE-bench tests flagged as possibly rejecting valid
  solutions, 68% of tasks filtered by 93 engineers (SWE-bench Verified, OpenAI 2024).
- **No single verifier suffices**; stack verifiers of different kinds. Mutation testing
  cannot classify equivalent mutants — the exact shape of the self-test objection above
  (Verification Horizon, arXiv 2606.26300).
- **Anthropic's own guidance** names the spine and the failure form in one page: "have
  one Claude write tests, then another write code to pass them"; a fresh verification
  subagent "so the agent doing the work isn't the one grading it"; "show evidence rather
  than asserting success"; and "a reviewer prompted to find gaps will usually report
  some, even when the work is sound … chasing every finding leads to over-engineering"
  (Claude Code best practices).
- Kent Beck's augmented coding keeps the same spine with a human watching: he writes
  the test plan, the agent implements test then code, and "any indication that the genie
  was cheating, for example by disabling or deleting tests" is the stop signal. The
  unattended form replaces the watching human with a hook and a clean re-run.

## Decision

The spine stays; the machinery around it goes; disagreement becomes a flag.

**Keep (each line carries its evidence above):**

1. **A non-builder context writes the ruler from the spec** before any implementation
   exists (`agents/ruler-author.md`, model pinned). One to three nodes per AC; an AC with
   two readings lists both in `ambiguity[]` and gets no node for the contested part.
2. **Freeze = a sha record + a hook.** `ruler.py freeze` writes the sha of every ruler
   file (plus the pre-build commit) to `build/freeze.json` once red-first is clean; a
   PreToolUse hook blocks Edit / Write on any frozen path for the rest of the build;
   held-out refuses to run on any sha drift. Where the ruler path is tracked by git the
   commit is that record; this repo's epic dir is gitignored, so the sha list is. No
   reader digest, no findings binding, no freeze schema of its own.
3. **Red-first, one line.** Every node runs once on the pre-build commit; every node must
   fail. A node that passes is either `status: regression` or a defect the author fixes
   before the freeze commit. No stub generation, no failure-class taxonomy.
4. **Held-out verdict.** A detached worktree at the build commit re-runs every frozen
   node and writes `build/verdict.yaml`: PASS / FAIL / DISPUTED / UNVERIFIED per AC with
   the node output. This is the only `done`.
5. **Deliverable-review** reads the diff against the spec in a fresh context (ADR-0042)
   — the second verifier of a different kind, the one that sees a dead library behind a
   green ruler.

**Add — the dispute flag.** During the build the builder may mark any ruler node
`disputed` with a reason: which AC, what the test asserts, what the spec says, why they
conflict. The test file does not change; the node still runs held-out; the verdict row
carries `DISPUTED` with the node's actual outcome, the builder's reason, and the test
text side by side. The owner rules at phase-ship, with the test and the reason both in
view. A ruling that the test was wrong sends the AC to the next unit's author round; a
ruling that the builder was wrong is a FAIL row to fix. The flag is the abort mechanism
ImpossibleBench measured: a legitimate exit that makes editing the test the worse
option.

**Remove:**

- `agents/ruler-reader.md` and the reader step (REQ-3 of the phase-1 spec). Its three
  concerns are covered elsewhere: hollow tests by red-first's floor (an existence-only
  test passes on the pre-build tree when the file exists) and by deliverable-review's
  execution-grounded read; chosen interpretations by the author's `ambiguity[]` rule and
  design-review's tester clause; implementation binding by deliverable-review.
- `ruler.py stub` and the red-first outcome taxonomy; the freeze schema and the reader
  digest binding; the author-revise → re-read → re-freeze loop.
- The mid-build re-author round. Wrong tests are ruled at ship and re-authored in the
  next unit, the SWE-bench Verified shape.

**Not done now, named so it is not silently dropped:**

- **Hidden ruler** — the strongest measured mitigation is that the builder never sees
  the tests (SpecBench gap → 0). Cost: the builder iterates blind on failure messages.
  Deferred; flip-trigger (1) reopens it once a gap is measurable.
- **Mutation testing as an instrument** — the mechanical form of "would a wrong
  implementation pass"; runs after the fact, reports a score, gates nothing.

## Consequences

- The owner's recurring judgment is one kind only: reading a verdict with FAIL and
  DISPUTED rows at phase-ship, test and reason side by side. No pre-freeze rulings.
- A wrong frozen test costs one build unit, not a halt: it surfaces as FAIL or DISPUTED
  with evidence, and the next unit's author fixes it.
- `ruler.py` shrinks to five subcommands (check, run, red-first, freeze, held-out) with no
  stub tree and no outcome taxonomy; three schemas become two (ruler, verdict); the
  plugin ships one fewer agent and one more hook.
- The satisficer's cheapest path to green is now: build the behaviour, or flag the test
  with a reason the owner will read. Editing the test is blocked; special-casing the
  test is what deliverable-review reads for.
- What this does not buy: a hollow test that both red-first and deliverable-review miss
  still yields a false PASS. That residue is the reason the verdict is read beside the
  review, never alone.

## Sources

- Building to the Test — https://arxiv.org/html/2606.28430
- SpecBench — https://arxiv.org/html/2605.21384v1
- ImpossibleBench — https://arxiv.org/pdf/2510.20270
- SWE-bench Verified — https://openai.com/index/introducing-swe-bench-verified/
- The Verification Horizon — https://arxiv.org/pdf/2606.26300
- Claude Code best practices — https://code.claude.com/docs/en/best-practices
- Kent Beck, Augmented Coding: Beyond the Vibes — https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes
- TDD-Bench Verified — https://arxiv.org/abs/2412.02883
- Test vs Mutant (AdverTest) — https://arxiv.org/html/2602.08146
