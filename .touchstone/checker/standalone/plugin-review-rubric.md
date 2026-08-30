# plugin-review rubric — four lens items

Prose input for a reviewer, not a checker. Nothing here is executed: a reviewer
reads the plugin's load sets with this file in its prompt, returns findings, and
scores every criterion below. `plugin-review.sh` only composes and records.

**Scoring.** Every criterion scores the *plugin*, not the review: `2` = the named
observation was made over the named scope and found nothing; `1` = it found one
instance; `0` = it found more than one, or the scope could not be read. Item
score = item weight × Σ(its criteria). Weighted maximum = **72** (item 1 3×8,
item 2 3×8, item 3 2×6, item 4 2×6).

**Threshold — 90 % of the weighted maximum** (≥ 64.8 / 72). The threshold governs
**iteration only**: reaching it stops the loop, it is not a push gate. The push
gate stays C + H = 0 (`check-review-summary.sh`).

**Plateau.** Round n ≥ 2 stops when the weighted total did **not rise** against
the previous round (`total ≤ previous total`) and no new C/H finding appeared —
not when the totals are equal, because the same input scores differently twice.

---

## Item 1 — semantic duplicate or contradiction within one load set (weight 3)

- [C1.1] Two files in the same `stages[*].load_set` state the same rule in
  different words: grep the rule's key noun across that stage's load set and read
  every hit.
- [C1.2] A pointer that also copies: a sentence naming a single home (`single
  home`, `canonical`, `see <path>`) followed by a restatement of that home's
  content in the same file — count the sentences after each pointer.
- [C1.3] Two files in one load set give conflicting instructions for the same
  actor and moment (one says MUST, the other says optional / never): grep the
  actor noun and compare the modal verbs.
- [C1.4] The same identifier is defined twice with different extensions (a term,
  a status enum, a file-name convention): grep the identifier, count definition
  sites.

## Item 2 — rule without consumer (weight 3)

- [C2.1] A MUST/SHALL sentence whose actor never appears in any body reachable
  from an entry: grep the actor noun across the union of the load sets, count 0.
- [C2.2] A named artifact, flag, field, or directory that no other node reads or
  writes: grep the name across the tree, count non-defining hits.
- [C2.3] A rule stated with no observable failure — nothing in the tree checks
  it, and no body says what happens when it is broken: grep for the rule's noun
  in the checker and hook set, count 0.
- [C2.4] A frontmatter declaration (`injected-by:`, `referenced-by:`, `Callers —`)
  whose named consumer's body never names the declaring file: this is the map's
  `false_edges` list — read it and confirm each entry.

## Item 3 — architecture-level declared-vs-actual (weight 2)

- [C3.1] A file claims a routing or ownership fact the map contradicts (an edge
  it says exists is absent from `edges`, or vice versa): read the claim, look up
  the pair in the map JSON.
- [C3.2] An entry's declared stage in its own body disagrees with the stage it
  occupies in `stages`: compare the two.
- [C3.3] A node in `orphans` that a body describes as reachable, or a node in
  `test_only` that a body describes as production: read each listed id.

## Item 4 — whole-workflow semantics (weight 2)

- [C4.1] A stage hands the next stage an artifact the next stage never reads:
  grep the producing stage's output name inside the consuming stage's load set,
  count 0.
- [C4.2] The workflow's terminal states are not exhaustive — a stage body names
  an outcome no downstream body handles: list the outcomes, grep each downstream.
- [C4.3] The same workflow step is described with two different orderings in two
  entries: grep the step's name, compare the surrounding sequence.
