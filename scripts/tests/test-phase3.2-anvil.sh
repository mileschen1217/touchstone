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

echo "$fail"
exit "$fail"
