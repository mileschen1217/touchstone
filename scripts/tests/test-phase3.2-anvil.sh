#!/usr/bin/env bash
# Phase 3.2 anvil + front-end seam wiring tests.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1  # repo root
fail=0
chk(){ if eval "$2"; then echo "ok: $1"; else echo "FAIL: $1"; fail=1; fi; }

# --- A1: design-spec is pure authoring (no architect dispatch anywhere under design-spec/) ---
chk "A1 no architect dispatch in design-spec SKILL.md" \
  '! grep -qiE "cross-provider-architect|Architect dispatch|architect-identified" skills/design-spec/SKILL.md'
chk "A1 architect-dispatch.md deleted" \
  '! test -f skills/design-spec/references/architect-dispatch.md'
chk "A1 no architect dispatch left under design-spec/ tree (excluding tests fixtures)" \
  '! grep -rqiE "cross-provider-architect" skills/design-spec/SKILL.md skills/design-spec/references/ skills/design-spec/README.md skills/design-spec/template.md'
chk "A1 quick/with-vendor critique modifiers gone from SKILL.md" \
  '! grep -qE "design-spec <feature-name> (quick|with (codex|cc))" skills/design-spec/SKILL.md'
chk "A1 no dangling link to architect-dispatch.md (inbound links removed, AC-1)" \
  '! grep -rqE "architect-dispatch\.md" skills/design-spec/SKILL.md skills/design-spec/references/ skills/design-spec/README.md skills/design-spec/template.md'

# --- A2: design-review UNION rubric + lifecycle + sentinel ---
chk "A2 design-review names the design-soundness lens" \
  'grep -qiE "design-soundness" skills/design-review/SKILL.md'
chk "A2 design-review names the verification-honesty lens" \
  'grep -qiE "verification-honesty" skills/design-review/SKILL.md'
chk "A2 design-review requires a per-finding lens tag" \
  'grep -qiE "lens tag|\[lens:" skills/design-review/SKILL.md'
chk "A2 design-review dispatch asks for STAGE-REVIEW-SUMMARY sentinel" \
  'grep -q "STAGE-REVIEW-SUMMARY" skills/design-review/SKILL.md'
chk "A19 design-review now reviews accepted-candidate" \
  'grep -qiE "accepted-candidate" skills/design-review/SKILL.md'
chk "A19 old final-human-accepted-ONLY language removed" \
  '! grep -qiE "reviews the \*\*final, human-accepted\*\* artifact" skills/design-review/SKILL.md'

# --- A4: crucible writes accepted-candidate + design-review halt before accept ---
chk "A4 crucible writes accepted-candidate status" \
  'grep -qiE "accepted-candidate" skills/crucible/SKILL.md'
chk "A4 crucible chain tail invokes design-review before accept" \
  'grep -qiE "design-review" skills/crucible/SKILL.md'
chk "A16 crucible no longer halts on the design-spec architect critique" \
  '! grep -qiE "architect critique returns a Critical" skills/crucible/SKILL.md'

# --- A5: new ADR supersedes 0015 (union != substitution) — located by GLOB, not a hard-coded number (AC-5) ---
adr="$(ls docs/adr/ 2>/dev/null | grep -i "consolidated-design-review" | head -1)"
chk "A5 new consolidated-design-review ADR exists and states union" \
  '[ -n "$adr" ] && grep -qiE "union" "docs/adr/$adr"'
chk "A5 new ADR distinguishes substitution-ban from union" \
  '[ -n "$adr" ] && grep -qiE "substitution" "docs/adr/$adr"'
chk "A5 ADR-0015 marked superseded" \
  'grep -qiE "Superseded by" docs/adr/0015-critique-never-discharges-the-design-review-gate.md'
chk "A5 CONTEXT.md crucible entry no longer says crucible does-not-invoke design-review" \
  '! grep -qE "auto-invokes \*\*neither\*\* the design-review gate" CONTEXT.md'
chk "A15 CONTEXT.md anvil entry no longer over-claims unqualified program-enforced independence" \
  '! grep -qE "adds only the deterministic sequencing \+ program-enforced independence" CONTEXT.md'

echo "$fail"
exit "$fail"
