---
injected-by: [assay, design-spec]
referenced-by: [design-spec template § Risks / Open Questions]
kind: bridge
---

# Human-question template

Every question put to the human — an `AskUserQuestion` call, a pointwise
elicitation, a `## Open Questions` entry — is answerable from the question
alone, with no repo access and no conversation scrollback. Three parts, in
this order:

1. **Context** — one or two sentences: what you are doing and why this needs
   the human (the decision or tacit fact that is theirs, not yours to look up).
   Any code or coined term (AC-N, REQ-N, ADR, file name) is spelled out with what
   it refers to.
2. **Options** — each option with its consequence: what happens downstream if
   this one is picked (cost, what becomes impossible, what it unblocks).
3. **Recommendation** — your leaning and a one-line reason.
