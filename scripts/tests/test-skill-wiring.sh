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

chk "template-has-us-entry"  "skills/design-spec/template.md" "^[[:space:]]*-[[:space:]]+US-[0-9]+ —"
chk "template-has-traces-to" "skills/design-spec/template.md" "^traces-to: US-"
# adjacency: ## User Stories is IMMEDIATELY between ## Scope and ## Acceptance Criteria
# (no intervening top-level heading), fence-aware over the ordered ## heading list
if awk '
  /^```/{f=!f;next} f{next}
  /^## /{ h[++n]=$0 }
  END{
    for(i=1;i<=n;i++) if(h[i] ~ /^## User Stories[[:space:]]*$/){
      ok = (i>1 && h[i-1] ~ /^## Scope/) && (i<n && h[i+1] ~ /^## Acceptance Criteria[[:space:]]*$/)
      exit !ok
    }
    exit 1
  }
' "$root/skills/design-spec/template.md"; then
  echo "ok template-section-adjacency"; else echo "FAIL template-section-adjacency"; fail=$((fail+1)); fi
# traces-to is inside a requirement block (a `### Requirement:` precedes the first traces-to)
if awk '/^### Requirement:/{r=NR} /^traces-to:/{t=NR} END{ exit !(r>0 && t>0 && r<t) }' "$root/skills/design-spec/template.md"; then
  echo "ok template-traces-in-req"; else echo "FAIL template-traces-in-req"; fail=$((fail+1)); fi

# live branch in SKILL.md
chk "skill-prd-branch"        "skills/design-spec/SKILL.md" "PRD"
# detail body in draft-workflow.md — per-clause, PRD-specific (each falsifiable before the edit)
chk "dw-prd-precedence"       "skills/design-spec/references/draft-workflow.md" "PRD > parent|PRD over parent"
chk "dw-prd-present-signal"   "skills/design-spec/references/draft-workflow.md" "supplied to Step 0|PRD is .?present"
chk "dw-prd-why-intention"    "skills/design-spec/references/draft-workflow.md" "why.*Foundation\\.Intention|Foundation\\.Intention"
chk "dw-prd-stories-mirror"   "skills/design-spec/references/draft-workflow.md" "## User Stories|user-stories"
chk "dw-prd-us-preserved"     "skills/design-spec/references/draft-workflow.md" "US-N"
chk "dw-prd-parent-framing"   "skills/design-spec/references/draft-workflow.md" "phase framing|parent supplies"
chk "dw-prd-scope-differ"     "skills/design-spec/references/draft-workflow.md" "scope differ|Does this spec.?s scope differ"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
