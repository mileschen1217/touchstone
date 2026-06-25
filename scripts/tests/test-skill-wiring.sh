#!/usr/bin/env bash
# Grep-based regression test for markdown skill wiring.
# Asserts the front-end skill wiring is present in the skill sources.
# Exit 0 = ALL GREEN; non-zero = RED.
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
fail=0
# The dropped PRD-producer token — constructed from pieces so the literal never appears
# in this source file (the operational sweep greps scripts/tests/ and must return no match).
tp='to''-prd'

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

# chains core sub-skills
chk "crucible-grill"       "skills/crucible/SKILL.md" "grill-with-docs"
chk "crucible-design-spec" "skills/crucible/SKILL.md" "touchstone:design-spec"
# states the inline grill discharges the pre-spec grill gate
chk "crucible-grill-disch" "skills/crucible/SKILL.md" "discharge.*grill gate|grill gate.*discharge"
# mid-chain architect-critique Critical/High halts + surfaces to clear, no Open-Questions fold, no auto-advance, then human accept
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

# --- NEW MODEL (Phase 2.9): standing-decision-aware crucible, native want-layer, both-arms ground-and-sweep ---

# crucible: brainstorm conditional, grill unconditional, keystone conditional structural-fork
chk "crucible-brainstorm-conditional" "skills/crucible/SKILL.md" "brainstorm[^.]{0,40}conditional|conditional[^.]{0,40}brainstorm"
chk "crucible-grill-unconditional"    "skills/crucible/SKILL.md" "grill[^.]{0,40}unconditional|unconditional[^.]{0,40}grill"
# crucible-keystone-conditional: require keystone + conditional + fork-token ALL within a ±3-line window.
# A single stray "not-yet-ratified" without conditionality/keystone will FAIL.
if awk '
  /keystone/{k=NR}
  /conditional/{c=NR}
  /structural.?fork|not.?yet.?ratified/{f=NR}
  k && c && f && (k-c<=3 && c-k<=3) && (k-f<=3 && f-k<=3) && (c-f<=3 && f-c<=3) {found=1}
  END{exit !found}
' "$root/skills/crucible/SKILL.md"; then
  echo "ok crucible-keystone-conditional"; else echo "FAIL crucible-keystone-conditional"; fail=$((fail+1)); fi
chk "crucible-surfaces-conflict"      "skills/crucible/SKILL.md" "standing.?decision|ratified|conflict"

# crucible chain tail = grill -> design-spec (first-match order, fence-aware, in the chain section);
# the dropped PRD-producer token ($tp) MUST NOT appear between them.
if awk -v tp="$tp" '
  /^## What it chains/{inchain=1; next}
  inchain && /^## /{exit}
  !inchain{next}
  /grill-with-docs/&&!g{g=NR}
  /touchstone:design-spec/&&!d{d=NR}
  $0 ~ tp {found_tp=NR}
  END{exit !(g&&d && g<d && found_tp==0)}
' "$root/skills/crucible/SKILL.md"; then
  echo "ok crucible-chain-tail"; else echo "FAIL crucible-chain-tail"; fail=$((fail+1)); fi

# crucible: zero occurrences of the dropped PRD-producer token (count == 0, body AND description frontmatter)
if grep -qi "$tp" "$root/skills/crucible/SKILL.md"; then
  echo "FAIL crucible-no-${tp}"; fail=$((fail+1)); else echo "ok crucible-no-${tp}"; fi

# design-spec: native always-on want-layer; no orphaned PRD-branch precedence
chk "ds-native-want" "skills/design-spec/SKILL.md" "want.?layer|## User Stories"
if grep -nE "PRD branch|PRD inheritance|PRD > parent|PRD over parent" \
   "$root/skills/design-spec/SKILL.md" "$root/skills/design-spec/references/draft-workflow.md" >/dev/null 2>&1; then
  echo "FAIL ds-no-prd-branch"; fail=$((fail+1)); else echo "ok ds-no-prd-branch"; fi

# ground-and-sweep fragment: content (both tests + root + scope rule) + bridge frontmatter
chk "ground-and-sweep-content"     "skills/_shared/ground-and-sweep.md" "ground.?before.?assert"
chk "ground-and-sweep-content-2"   "skills/_shared/ground-and-sweep.md" "sweep.?to.?dry|saturation"
chk "ground-and-sweep-root"        "skills/_shared/ground-and-sweep.md" "intension.?extension"
chk "ground-and-sweep-scope-rule"  "skills/_shared/ground-and-sweep.md" "superset|full subject|true.?subject"
chk "ground-and-sweep-frontmatter" "skills/_shared/ground-and-sweep.md" "kind: bridge"
chk "ground-and-sweep-killon"      "skills/_shared/ground-and-sweep.md" "kill-on: lever-discipline-mechanisation"

# both arms load the fragment (deterministic floor)
chk "gas-load-design-spec"   "skills/design-spec/SKILL.md"   "ground-and-sweep\.md"
chk "gas-load-design-review" "skills/design-review/SKILL.md" "ground-and-sweep\.md"
# design-review injects it into the cold reviewer envelope: assert the real instruction shape —
# the FB section contains a Read instruction for ground-and-sweep.md with inject, verbatim, AND
# envelope all co-occurring within an ~8-line window (the genuine prose: "Read
# `skills/_shared/ground-and-sweep.md` and inject it verbatim into the reviewer envelope").
# dr-injects-gas: on EACH ground-and-sweep.md line, RESET window state and start fresh.
# Requires Read + inject + verbatim + envelope ALL in the same window (≤3 lines after anchor).
# found=1 freezes on first complete window; a later incomplete window cannot un-set it.
# Missing ANY of the four tokens in every window ⟹ found stays 0 ⟹ FAIL.
if awk '
  /ground-and-sweep\.md/ {
    g=NR; has_read=0; has_inj=0; has_verb=0; has_env=0
    if (/Read/) has_read=1
    if (/inject/) has_inj=1
    if (/verbatim/) has_verb=1
    if (/envelope/) has_env=1
    next
  }
  g && !found && NR-g<=3 {
    if (/Read/) has_read=1
    if (/inject/) has_inj=1
    if (/verbatim/) has_verb=1
    if (/envelope/) has_env=1
    if (has_read && has_inj && has_verb && has_env) found=1
  }
  END{exit !found}
' "$root/skills/design-review/SKILL.md"; then
  echo "ok dr-injects-gas"; else echo "FAIL dr-injects-gas"; fail=$((fail+1)); fi

# dropped-PRD-producer-token operational sweep clean: no operational file under
# skills/ or scripts/tests/ (including this harness — the literal is absent here)
# nor CONTEXT.md/README.md contains the dropped token; ADR/research/spec history exempt.
sweep_targets=()
while IFS= read -r -d '' f; do
  sweep_targets+=("$f")
done < <(find "$root/skills" "$root/scripts/tests" \( -name '*.md' -o -name '*.sh' \) -print0 2>/dev/null)
if grep -ln "$tp" "${sweep_targets[@]}" "$root/CONTEXT.md" "$root/README.md" >/dev/null 2>&1; then
  echo "FAIL ${tp}-operational-sweep-clean"; fail=$((fail+1)); \
  grep -ln "$tp" "${sweep_targets[@]}" "$root/CONTEXT.md" "$root/README.md"; \
else echo "ok ${tp}-operational-sweep-clean"; fi

# --- test-evidence lens (ADR-0025) + governance invariant folded into code-review ---

# (a) test-evidence core question — "would this test go red" / witness-the-behaviour phrasing
chk "cr-test-evidence-core-question" \
  "skills/code-review/references/reviewer-prompts.md" \
  "would this test go red|witness.*behav|behav.*witness"

# (b) governance invariant: generic reviewer self-selects lenses; specialist dispatch only for
#     measurably under-reviewed deep domains
chk "cr-governance-self-selects" \
  "skills/code-review/SKILL.md" \
  "self-selects? domain lenses|self.selects? .* diff"
chk "cr-governance-measurably" \
  "skills/code-review/SKILL.md" \
  "measurably.{0,30}under.review|specialist.*measurably"

# (c) regression-presence trigger-split note — fires on fix commits regardless of test files touched
chk "cr-regression-trigger-split" \
  "skills/code-review/SKILL.md" \
  "regardless of whether test files|fix commits.*regardless"

# (d) no new test-specific reviewer agent/dispatch — the lens is folded into generic-diff
if [ -f "$root/agents/test-reviewer.md" ] || [ -f "$root/agents/test-file-reviewer.md" ] || \
   [ -f "$root/agents/test-quality-reviewer.md" ]; then
  echo "FAIL cr-no-new-test-agent: a new test-specific agent file was added under agents/"; fail=$((fail+1))
else
  echo "ok cr-no-new-test-agent"
fi
# confirm the test-evidence content lives in the generic-diff prompt, not a new dispatch section
chk "cr-test-evidence-in-generic-diff" \
  "skills/code-review/references/reviewer-prompts.md" \
  "touches test files|test.evidence"

# (e) batch path carries a reference to the test-evidence lens (ADR-0025: applies to per-commit AND batch)
chk "cr-batch-carries-test-evidence-ref" \
  "skills/code-review/references/batch-mode.md" \
  "test.evidence|reviewer-prompts.*generic-diff|generic-diff.*reviewer-prompts"

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
