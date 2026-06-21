#!/usr/bin/env bash
# Grep-based regression test for markdown skill wiring.
# Backs AC-9/11/12/14 prose — asserts the wiring is present in the skill sources.
# Exit 0 = ALL GREEN; non-zero = RED.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fail=0

chk() { # name file pattern description
  local name="$1" file="$root/$2" pattern="$3"
  if grep -qiE "$pattern" "$file" 2>/dev/null; then
    echo "ok $name"
  else
    echo "FAIL $name: pattern /$pattern/ not found in $2"
    fail=$((fail+1))
  fi
}

# skills/design-review/SKILL.md — precheck script reference
chk "design-review-has-precheck-script" \
  "skills/design-review/SKILL.md" \
  "design-review-precheck\.sh"

# skills/design-review/SKILL.md — do not dispatch rule (case-insensitive)
chk "design-review-has-do-not-dispatch" \
  "skills/design-review/SKILL.md" \
  "do not dispatch"

# skills/design-spec/references/methodology.md — untrusted-data directive
chk "methodology-has-untrusted-data" \
  "skills/design-spec/references/methodology.md" \
  "UNTRUSTED DATA"

# skills/design-spec/references/methodology.md — no-completeness-verdict rule
chk "methodology-has-no-completeness-verdict" \
  "skills/design-spec/references/methodology.md" \
  "NEVER emit a completeness verdict|no completeness verdict"

# skills/design-spec/references/draft-workflow.md — challenger_id
chk "draft-workflow-has-challenger-id" \
  "skills/design-spec/references/draft-workflow.md" \
  "challenger_id"

# skills/design-spec/references/draft-workflow.md — spec-extract.sh digest
chk "draft-workflow-has-spec-extract-digest" \
  "skills/design-spec/references/draft-workflow.md" \
  "spec-extract\.sh digest"

# skills/design-spec/references/draft-workflow.md — untrusted-data directive
chk "draft-workflow-has-untrusted-data" \
  "skills/design-spec/references/draft-workflow.md" \
  "UNTRUSTED DATA"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
