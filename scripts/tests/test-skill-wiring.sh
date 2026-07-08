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
# (path is ${CLAUDE_PLUGIN_ROOT}-prefixed and quoted, so allow an optional quote
# between the script name and the subcommand)
chk "draft-workflow-has-spec-extract-digest" \
  "skills/design-spec/references/draft-workflow.md" \
  "spec-extract\.sh\"? digest"

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
chk "crucible-assay"       "skills/crucible/SKILL.md" "touchstone:assay"
chk "crucible-design-spec" "skills/crucible/SKILL.md" "touchstone:design-spec"
# purged chain tokens: crucible carries ZERO grill / brainstorm / retired-skill references.
# The retired skill token is built from pieces so the literal never appears in this
# source file (the operational sweep greps scripts/ and must return no match) — the
# same trick as the tp token above.
rk='key''stone'
for tok in grill brainstorm "$rk"; do
  if grep -qi "$tok" "$root/skills/crucible/SKILL.md"; then
    echo "FAIL crucible-no-$tok: token present"; fail=$((fail+1))
  else echo "ok crucible-no-$tok"; fi
done
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
# Phase 3.2 A4: crucible NOW invokes /touchstone:design-review pre-accept (3→2 front-load, ADR-0026).
# The former negative check is FLIPPED to positive: design-review token MUST be present.
# writing-plans is still absent (crucible does NOT invoke the build phase's planning step).
if grep -qE "/touchstone:design-review" "$root/skills/crucible/SKILL.md"; then
  echo "ok crucible-has-design-review-token"; else echo "FAIL crucible-has-design-review-token: /touchstone:design-review not found in crucible"; fail=$((fail+1)); fi
if grep -qE "superpowers:writing-plans|/superpowers:writing-plans" "$root/skills/crucible/SKILL.md"; then
  echo "FAIL crucible-no-writing-plans-token"; fail=$((fail+1)); else echo "ok crucible-no-writing-plans-token"; fi
# PRD+seams pre-accept light check (Phase 1, interview-mechanics epic)
chk "crucible-light-check"       "skills/crucible/SKILL.md" "light check"
chk "crucible-lc-fresh-context"  "skills/crucible/SKILL.md" "fresh-context sonnet"
chk "crucible-lc-converge-once"  "skills/crucible/SKILL.md" "re-dispatch once"
chk "crucible-lc-incomplete"     "skills/crucible/SKILL.md" "light check incomplete"
chk "crucible-lc-no-fabricate"   "skills/crucible/SKILL.md" "never fabricate a verdict"
chk "crucible-prdseams-no-drgate" "skills/crucible/SKILL.md" "not pass the design-review gate"
# suite consistency layer in the authoring template (Phase 1, interview-mechanics epic)
chk "authoring-fm-canon"          "docs/skill-authoring-template.md" "disable-model-invocation"
chk "authoring-kind-nonofficial"  "docs/skill-authoring-template.md" "non-official"
chk "authoring-negative-routing"  "docs/skill-authoring-template.md" "When NOT to use"
chk "authoring-live-human"        "docs/skill-authoring-template.md" "live responsive user"
chk "authoring-thin-wrapper"      "docs/skill-authoring-template.md" "in-chain composite"
chk "authoring-bounded-example"   "docs/skill-authoring-template.md" "an example, not a rule"
chk "authoring-self-desc-names"   "docs/skill-authoring-template.md" "opaque codes"
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

# crucible: assay unconditional, chain position explore -> assay -> design-spec
chk "crucible-assay-unconditional" "skills/crucible/SKILL.md" "assay[^.]{0,40}unconditional|unconditional[^.]{0,40}assay"
if awk '
  /^## What it chains/{inchain=1; next}
  inchain && /^## /{exit}
  !inchain{next}
  /\*\*explore\*\*/&&!e{e=NR}
  /touchstone:assay/&&!a{a=NR}
  /touchstone:design-spec/&&!d{d=NR}
  END{exit !(e&&a&&d && e<a && a<d)}
' "$root/skills/crucible/SKILL.md"; then
  echo "ok crucible-chain-order"; else echo "FAIL crucible-chain-order"; fail=$((fail+1)); fi
# crucible gates design-spec on assay's readiness ruling
chk "crucible-readiness-gate" "skills/crucible/SKILL.md" "readiness ruling"
chk "crucible-surfaces-conflict"      "skills/crucible/SKILL.md" "standing.?decision|ratified|conflict"

# crucible chain tail = assay -> design-spec (first-match order, in the chain section);
# the dropped PRD-producer token ($tp) MUST NOT appear between them.
if awk -v tp="$tp" '
  /^## What it chains/{inchain=1; next}
  inchain && /^## /{exit}
  !inchain{next}
  /touchstone:assay/&&!g{g=NR}
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

# (b) governance: SKILL.md carries the BEHAVIORAL self-select rule; the maintainer
#     CAP rationale (measurably-under-reviewed → add specialist) lives in README.
chk "cr-governance-self-selects" \
  "skills/code-review/SKILL.md" \
  "self-selects? domain lenses|self.selects? .* diff"
chk "cr-governance-cap-in-readme" \
  "skills/code-review/README.md" \
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

# catch-attribution sweep step is wired into the epic-close reference (REQ-6)
chk "close-has-catch-attribution-sweep" \
  "skills/epic-driven-roadmap/references/close-and-doc-reckoning.md" \
  "## Catch-attribution sweep"

# --- assay: pre-contract interview instrument (skill-body floor) ---
chk "assay-frontmatter-name"    "skills/assay/SKILL.md" "^name: assay"
chk "assay-dual-tag-loadbearing" "skills/assay/SKILL.md" "load-bearing"
chk "assay-dual-tag-probecost"  "skills/assay/SKILL.md" "probe-cost"
chk "assay-bold-pass"           "skills/assay/SKILL.md" "bold pass"
chk "assay-blast-radius"        "skills/assay/SKILL.md" "blast radius"
chk "assay-want-probe"          "skills/assay/SKILL.md" "want-vs-should-want"
chk "assay-quadrants"           "skills/assay/SKILL.md" "unknown knowns"
chk "assay-readiness-criterion" "skills/assay/SKILL.md" "resolved or flip-triggered"
chk "assay-explicit-yes"        "skills/assay/SKILL.md" "explicit yes"
chk "assay-nonyes-taxonomy"     "skills/assay/SKILL.md" "whatever you think"
chk "assay-flip-registry"       "skills/assay/SKILL.md" "flip-trigger registry"
chk "assay-deferred-log"        "skills/assay/SKILL.md" "deferred log"
chk "assay-record-append"       "skills/assay/SKILL.md" "APPENDs? a new dated section"
chk "assay-deviation-log"       "skills/assay/SKILL.md" "deviation log"
chk "assay-honest-ceiling"      "skills/assay/SKILL.md" "never proves them zero"
chk "assay-noninteractive"      "skills/assay/SKILL.md" "non-interactive"
chk "assay-unformed-escape"     "skills/assay/SKILL.md" "out-of-band"
chk "assay-writeback"           "skills/assay/SKILL.md" "admission boundary"
chk "assay-adr-pointer"         "skills/assay/SKILL.md" "adr-authoring\.md"
chk "assay-rubric-pointer"      "skills/assay/SKILL.md" "references/arch-rubric\.md"
# interview presentation mechanics + self-describing names (Phase 1, interview-mechanics epic)
chk "assay-one-question-per-msg" "skills/assay/SKILL.md" "ONE question per message"
chk "assay-question-leaning"     "skills/assay/SKILL.md" "leaning and a one-line reason"
chk "assay-askuserquestion"      "skills/assay/SKILL.md" "AskUserQuestion"
chk "assay-plain-dialogue"       "skills/assay/SKILL.md" "no skill-internal section names"
chk "assay-facts-self-lookup"    "skills/assay/SKILL.md" "decisions and tacit knowledge"
chk "assay-predict3-stop"        "skills/assay/SKILL.md" "three questions"
chk "assay-correction-reopens"   "skills/assay/SKILL.md" "reopens the question queue"
chk "assay-laydown-leaning"      "skills/assay/SKILL.md" "carry your leaning"
chk "assay-unknown-sources"      "skills/assay/SKILL.md" "laydown residuals"
chk "assay-laydown-never-skipped" "skills/assay/SKILL.md" "never skips the laydown"
# self-describing internal names: no bare-numbered stage headings remain
if grep -qE '^#{2,3} (Stage [0-9]|[0-9][abc]? —)' "$root/skills/assay/SKILL.md"; then
  echo "FAIL assay-opaque-headings: bare-numbered section heading present"; fail=$((fail+1))
else echo "ok assay-opaque-headings"; fi
# the three structural-fork bet fields are documented in the migrated ADR procedure
chk "assay-adr-flip-field"      "skills/assay/adr-authoring.md" "Flip-trigger:"
chk "assay-adr-betowner-field"  "skills/assay/adr-authoring.md" "Bet-owner:"
chk "assay-adr-assumptions-field" "skills/assay/adr-authoring.md" "Assumptions:"
# migrated assets present
[ -f "$root/skills/assay/adr-authoring.md" ] && echo "ok assay-adr-file" \
  || { echo "FAIL assay-adr-file: skills/assay/adr-authoring.md missing"; fail=$((fail+1)); }
[ -f "$root/skills/assay/references/arch-rubric.md" ] && echo "ok assay-rubric-file" \
  || { echo "FAIL assay-rubric-file: skills/assay/references/arch-rubric.md missing"; fail=$((fail+1)); }
# assay body size norm (guideline enforced at 200 like crucible)
alc="$(wc -l < "$root/skills/assay/SKILL.md" 2>/dev/null || echo 999)"
[ "$alc" -le 200 ] && echo "ok assay-line-count ($alc)" || { echo "FAIL assay-line-count: $alc > 200"; fail=$((fail+1)); }

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
