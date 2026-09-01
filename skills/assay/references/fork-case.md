---
referenced-by: [assay]
load-when: "a structural fork entry with two-plus viable approaches and durability stakes"
kind: bridge
---

# Structural fork case (loaded on the fork trigger only)

**Structural fork case** — a fork entry with ≥2 viable approaches and durability stakes: author an ADR per `adr-authoring.md` (the skill root, one level up) with the flip-trigger, bet-owner, and assumptions fields, the human as bet-owner; grade it against `arch-rubric.md` (same directory). For a fork worth critique evidence, dispatch the two critique arms per the arm-dispatch mechanics in `${CLAUDE_PLUGIN_ROOT}/skills/_shared/provenance.md`. This case's deltas: lenses `arch-validation` (cc, label `arch-validation-cc`) and `arch-pressure-test` (codex, label `arch-pressure-test-codex`); the subject is `--subject-file <proposal>`; no role string is needed. The fallback when the codex arm is unavailable is recorded degraded per that same reference.

**Synthesis (host-side, this session):** validated design (cc) first, then the pressure-test results (codex); flag every adversarial finding that contradicts a validated decision; one verdict, the more conservative of the two. Codex arm absent or failed → validation only, recorded `degraded` per `${CLAUDE_PLUGIN_ROOT}/skills/_shared/provenance.md`; cc never stands in for the adversarial half. Adaptable, omit only with the reason recorded in the ADR.
