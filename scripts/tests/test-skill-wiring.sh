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

# chains the four sub-skills in invocation order
chk "crucible-brainstorm"  "skills/crucible/SKILL.md" "superpowers:brainstorming"
chk "crucible-grill"       "skills/crucible/SKILL.md" "grill-with-docs"
chk "crucible-to-prd"      "skills/crucible/SKILL.md" "to-prd"
chk "crucible-design-spec" "skills/crucible/SKILL.md" "touchstone:design-spec"
# Order check scoped to the `## What it chains` section (the numbered invocation list),
# FIRST-match per token — excludes the frontmatter description and trailing explanatory
# mentions, so neither a reordered list NOR a stray later mention can fool it.
if awk '
  /^## What it chains/{inchain=1; next}
  inchain && /^## /{exit}
  !inchain{next}
  /superpowers:brainstorming/&&!b{b=NR}
  /grill-with-docs/&&!g{g=NR}
  /to-prd/&&!p{p=NR}
  /touchstone:design-spec/&&!d{d=NR}
  END{exit !(b&&g&&p&&d && b<g && g<p && p<d)}
' "$root/skills/crucible/SKILL.md"; then
  echo "ok crucible-chain-order"; else echo "FAIL crucible-chain-order"; fail=$((fail+1)); fi
# documents the US-N id assignment
chk "crucible-us-assign"   "skills/crucible/SKILL.md" "assign each user-story a unique .?US-N|unique US-N id"
# states the inline grill discharges the pre-spec grill gate
chk "crucible-grill-disch" "skills/crucible/SKILL.md" "discharge.*grill gate|grill gate.*discharge"
# mid-chain Step-5 Critical/High halts + surfaces to clear, no Open-Questions fold, no auto-advance, then human accept
chk "crucible-midchain-halt"  "skills/crucible/SKILL.md" "Critical or High|Critical/High"
chk "crucible-midchain-clear" "skills/crucible/SKILL.md" "halt.*surface|surface.*clear|clear .?resolve or dismiss"
chk "crucible-no-oq-fold"     "skills/crucible/SKILL.md" "fold it into Open Questions|silently fold.*Open Questions"
chk "crucible-no-advance"     "skills/crucible/SKILL.md" "auto-advance"
chk "crucible-then-accept"    "skills/crucible/SKILL.md" "terminal human-accept"
# terminates at human accept, names the build phase, no auto gate/build
chk "crucible-human-accept" "skills/crucible/SKILL.md" "human accept"
chk "crucible-names-build"  "skills/crucible/SKILL.md" "build phase|/build"
chk "crucible-no-auto"      "skills/crucible/SKILL.md" "NOT auto-invoke"
# negative — body must NOT INVOKE the design-review gate NOR a writing-plans step.
# (A naming-only mention of /build as "the next stage" is allowed per spec OQ-5 — a negative
#  grep cannot distinguish naming from invoking; design-review + writing-plans tokens are absent
#  entirely, which IS grep-checkable.)
if grep -qE "/touchstone:design-review" "$root/skills/crucible/SKILL.md"; then
  echo "FAIL crucible-no-design-review-token"; fail=$((fail+1)); else echo "ok crucible-no-design-review-token"; fi
if grep -qE "superpowers:writing-plans|/superpowers:writing-plans" "$root/skills/crucible/SKILL.md"; then
  echo "FAIL crucible-no-writing-plans-token"; fail=$((fail+1)); else echo "ok crucible-no-writing-plans-token"; fi
# quality bar — <=200 lines
lc="$(wc -l < "$root/skills/crucible/SKILL.md")"
[ "$lc" -le 200 ] && echo "ok crucible-line-count ($lc)" || { echo "FAIL crucible-line-count: $lc > 200"; fail=$((fail+1)); }

# crucible is registered by its skill directory (skills are auto-discovered from skills/;
# the manifests carry no per-skill list — the other 11 skills aren't listed either).
[ -f "$root/skills/crucible/SKILL.md" ] && echo "ok crucible-skill-registered" || { echo "FAIL crucible-skill-registered: skills/crucible/SKILL.md missing"; fail=$((fail+1)); }
# versions parse and match across both manifests
if python3 - "$root" <<'PY'
import json,sys
root=sys.argv[1]
a=json.load(open(f"{root}/.claude-plugin/plugin.json")).get("version")
b=json.load(open(f"{root}/.claude-plugin/marketplace.json"))
# marketplace may nest version under a plugin entry; accept either top-level or any plugin entry
def has(v,o):
    if isinstance(o,dict):
        if o.get("version")==v: return True
        return any(has(v,x) for x in o.values())
    if isinstance(o,list):
        return any(has(v,x) for x in o)
    return False
sys.exit(0 if (a and has(a,b)) else 1)
PY
then echo "ok manifest-version-consistent"; else echo "FAIL manifest-version-consistent"; fail=$((fail+1)); fi

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
