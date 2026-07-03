# Phase-ship moment

Run these two lines at the moment a phase's deliverable ships (PR merged /
release tagged), from the repo root:

- [ ] **Deterministic:** `scripts/metrics/phase-record.sh <epic-slug> <phase-label>`
      — appends the phase's gate-run metrics and the current open-entry count
      to `.touchstone/epics/<slug>/data-points.md` (cells honestly
      `[unverified: …]` when OTel is absent; never hand-copy the numbers).
      Running it also bounds the last still-open gate-run window.
- [ ] **Semantic:** invoke `/touchstone:insight` — ranked proposal digest over
      the full open-entry set; every ruling is recorded as a fact.
