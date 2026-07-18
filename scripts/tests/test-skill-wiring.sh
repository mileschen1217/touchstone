#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
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
# adjacency (six-section form): ## User Stories is IMMEDIATELY between
# ## Source-level Deposit and ## Acceptance Criteria (no intervening top-level
# heading), fence-aware over the ordered ## heading list
if awk '
  /^```/{f=!f;next} f{next}
  /^## /{ h[++n]=$0 }
  END{
    for(i=1;i<=n;i++) if(h[i] ~ /^## User Stories[[:space:]]*$/){
      ok = (i>1 && h[i-1] ~ /^## Source-level Deposit/) && (i<n && h[i+1] ~ /^## Acceptance Criteria[[:space:]]*$/)
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
chk "crucible-light-check"       "skills/crucible/SKILL.md" "^Before presenting a PRD\+seams light contract"
chk "crucible-lc-fresh-context"  "skills/crucible/SKILL.md" "fresh-context sonnet"
chk "crucible-lc-converge-once"  "skills/crucible/SKILL.md" "re-dispatch once"
chk "crucible-lc-incomplete"     "skills/crucible/SKILL.md" "light check incomplete"
chk "crucible-lc-no-fabricate"   "skills/crucible/SKILL.md" "never fabricate a verdict"
chk "crucible-prdseams-no-drgate" "skills/crucible/SKILL.md" "not pass the design-review gate"
# suite consistency layer in the authoring template (Phase 1, interview-mechanics epic)
chk "authoring-fm-canon"          "docs/skill-authoring-template.md" "disable-model-invocation"
chk "authoring-kind-nonofficial"  "docs/skill-authoring-template.md" "non-official"
chk "authoring-negative-routing"  "docs/skill-authoring-template.md" "MUST name when NOT to use it"
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
chk "assay-one-question-per-msg" "skills/assay/SKILL.md" "^- Ask exactly ONE question per message"
chk "assay-question-leaning"     "skills/assay/SKILL.md" "leaning and a one-line reason"
chk "assay-askuserquestion"      "skills/assay/SKILL.md" "AskUserQuestion"
chk "assay-plain-dialogue"       "skills/assay/SKILL.md" "no skill-internal section names"
chk "assay-facts-self-lookup"    "skills/assay/SKILL.md" "decisions and tacit knowledge"
chk "assay-predict3-stop"        "skills/assay/SKILL.md" "three questions"
chk "assay-correction-reopens"   "skills/assay/SKILL.md" "reopens the question queue"
chk "assay-laydown-leaning"      "skills/assay/SKILL.md" "carry your leaning"
chk "assay-unknown-sources"      "skills/assay/SKILL.md" "laydown residuals"
chk "assay-laydown-never-skipped" "skills/assay/SKILL.md" "never skips the laydown"
# REQ-1 AC-1: consensus render precedes the consequence-probe step
chk "assay-consensus-render-step" "skills/assay/SKILL.md" "[Cc]onsensus render"
chk "assay-render-before-probes"  "skills/assay/SKILL.md" "before.*consequence probe|BEFORE.*probes"
# REQ-1 AC-2: render precedes the readiness ask; the yes lands on it
chk "assay-yes-object-render"     "skills/assay/SKILL.md" "object of the .*yes|refers the human to that.*render"
# REQ-1 AC-3: record ## Consensus not persisted before the yes
chk "assay-no-preyes-persist"     "skills/assay/SKILL.md" "not.*written before the.*yes|persisted only at/after the.*yes"
# REQ-1 AC-4: reuses laydown-first with a one-line delta (single home)
chk "assay-render-reuses-laydown" "skills/assay/SKILL.md" "consensus render.*laydown-first|reuses.*laydown-first-presentation"
# REQ-1 AC-5: tier axis is load-bearing STATUS, not a literal load-bearing? tag column
chk "assay-render-tier-status"    "skills/assay/SKILL.md" "load-bearing STATUS|not a literal .load-bearing"
# REQ-1 AC-14: re-render on a correction before the next readiness ask
chk "assay-render-recorrection"   "skills/assay/SKILL.md" "re-render.*before the next readiness|never lands on a stale render"
# AC-14 re-render cross-referenced at its trigger site (falsified-probe path) — locks the final-review M2 fix
chk "assay-rerender-probe-site"   "skills/assay/SKILL.md" "re-renders the consensus"
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
# assay body size norm (200-line guideline is a WARN not a gate fail, matching
# check-md-surface-budget.sh's per-file policy; 500 is the hard cap — plan
# Global Constraints blessed assay/SKILL.md crossing 200 in REQ-3)
alc="$(wc -l < "$root/skills/assay/SKILL.md" 2>/dev/null || echo 999)"
if [ "$alc" -le 200 ]; then echo "ok assay-line-count ($alc)"
elif [ "$alc" -le 500 ]; then echo "WARN assay-line-count: $alc > 200 (guideline, not a gate)"
else echo "FAIL assay-line-count: $alc > 500 (hard cap)"; fail=$((fail+1)); fi

# --- assay v2: laydown-first presentation fragment (single home) ---
frag="skills/_shared/inject/laydown-first-presentation.md"
[ -f "$root/$frag" ] && echo "ok fragment-file" \
  || { echo "FAIL fragment-file: $frag missing"; fail=$((fail+1)); }
chk "fragment-injected-by-assay" "$frag" "^injected-by: \[assay\]"
chk "fragment-end-turn-carrier"  "$frag" "end-turn plain-text"
chk "fragment-record-mirror"     "$frag" "durable record"
chk "fragment-non-universal"     "$frag" "non-universal"
chk "fragment-user-start-gate"   "$frag" "explicitly says to start"
chk "fragment-auq-per-item"      "$frag" "per-item rulings"
chk "fragment-tiered-depth"     "$frag" "coverage-complete"
chk "fragment-full-table-home"  "$frag" "record always carries the full table"
# REQ-2 AC-8: scale trigger is AI-judged one-pass scannability, not a hardcoded count
chk "fragment-scale-trigger"     "$frag" "one-pass scannab"
chk "fragment-scale-not-hardcoded" "$frag" "not a hardcoded"
# REQ-2 AC-6: digest tier collapses to a counted record-file pointer WHERE mirrored; else stays inline
chk "fragment-scale-collapse"    "$frag" "counted.*record-file|count \+ .*record-file path"
chk "fragment-scale-not-persisted-inline" "$frag" "not yet persisted|stays one-line inline"
# REQ-2 AC-7: full-text tier is never collapsed
chk "fragment-scale-fulltext-safe" "$frag" "full-text tier is never collapsed|never collapse the full-text"
# REQ-2 AC-8: ambiguous → collapse digest (stricter), never silently drop
chk "fragment-scale-ambiguous"   "$frag" "ambiguous, collapse the digest tier"
# REQ-2 AC-15: human expand override, reversible
chk "fragment-scale-expand"      "$frag" "expand request|reversible by the human"
# carrier rule allows a consumer-declared deferred record section — locks the final-review M1 fix
chk "fragment-deferred-carrier"  "$frag" "record section \*\*deferred\*\*|deferred content into the record"
# REQ-3 AC-9: canonical tier-split rendering example incl. the scale-collapsed form
chk "fragment-canonical-example" "$frag" "[Cc]anonical rendering example"
chk "fragment-example-three-forms" "$frag" "scale-collapsed"
# REQ-3 AC-10: tags render as scannable badges; id is a handle beside the phrase
chk "fragment-example-badges"    "$frag" "badge"
chk "fragment-example-id-handle" "$frag" "handle beside"
# REQ-3 AC-11: §90 tightened to "never by row number alone" + id-handle permitted
chk "assay-row-number-alone"     "skills/assay/SKILL.md" "row number alone"
chk "assay-id-handle-permitted"  "skills/assay/SKILL.md" "id.*handle beside|visible.*id"

# --- assay v2: three-way alignment body ---
chk "assay-three-arms"          "skills/assay/SKILL.md" "three arms"
chk "assay-term-sheet"          "skills/assay/SKILL.md" "term sheet"
chk "assay-source-marker"       "skills/assay/SKILL.md" "source marker"
chk "assay-ledger-conflict-row" "skills/assay/SKILL.md" "its own assumption row"
chk "assay-loads-fragment"      "skills/assay/SKILL.md" "laydown-first-presentation\.md"
chk "assay-planned-handling"    "skills/assay/SKILL.md" "planned handling"
chk "assay-predict-published"   "skills/assay/SKILL.md" "predicted answer"
chk "assay-empty-queue"         "skills/assay/SKILL.md" "empty-queue statement"
chk "assay-consequence-probes"  "skills/assay/SKILL.md" "consequence probes"
chk "assay-probe-floor"         "skills/assay/SKILL.md" "per load-bearing ruling"
chk "assay-clean-round"         "skills/assay/SKILL.md" "zero corrections"
chk "assay-consensus-terminus"  "skills/assay/SKILL.md" "## Consensus"
chk "assay-trace-grammar"       "skills/assay/SKILL.md" "\[trace: "
chk "assay-no-seam-skeletons"   "skills/assay/SKILL.md" "no acceptance-seam skeletons|authors the seam"
chk "assay-record-frontmatter"  "skills/assay/SKILL.md" "frontmatter .subject:."
# REQ-4 AC-12: R-n defined at first use as a single dated sequence (not two per-type counters)
chk "assay-rn-single-sequence"  "skills/assay/SKILL.md" "single dated sequence"
# REQ-4 AC-13: load-bearing? tag scoped to assumption rows in the delta line (term-sheet rows carry a source marker)
chk "assay-delta-tag-scoped"    "skills/assay/SKILL.md" "assumption and bold-pass rows"

# --- confirmed-facts consume: design-spec (deep component) ---
chk "ds-generic-interface"  "skills/design-spec/SKILL.md" "facts sources in"
chk "ds-points-to-contract" "skills/design-spec/SKILL.md" "confirmed-facts-source\.md"
chk "ds-never-silent"       "skills/design-spec/SKILL.md" "NEEDS CLARIFICATION"
chk "ds-authors-ac-layer"   "skills/design-spec/SKILL.md" "authored HERE"
chk "ds-standalone-steering" "skills/design-spec/SKILL.md" "no qualified confirmed-facts source"
# retired routing knowledge must be gone (AC-1) — SKILL.md and references/
for pat in "Consume-or-elicit" "legacy Intention format" "foundation-gate\.md"; do
  if grep -rqiE "$pat" "$root/skills/design-spec/SKILL.md" "$root/skills/design-spec/references" 2>/dev/null; then
    echo "FAIL ds-no-routing($pat): retired token present"; fail=$((fail+1))
  else echo "ok ds-no-routing($pat)"; fi
done

# --- confirmed-facts handoff: crucible ---
chk "crucible-facts-source-handoff" "skills/crucible/SKILL.md" "record path as the facts source"
chk "crucible-points-to-contract"   "skills/crucible/SKILL.md" "confirmed-facts-source\.md"
chk "crucible-ask-or-mark"          "skills/crucible/SKILL.md" "NEEDS CLARIFICATION"
chk "crucible-prdseams-traced"      "skills/crucible/SKILL.md" "row-level cited rows"

# retired handoff: no live surface still instructs producing/consuming a guardrail block
# (docs/adr/ history exempt — dated ledger)
for gf in skills/assay/SKILL.md skills/design-spec/SKILL.md skills/crucible/SKILL.md \
          skills/_shared/foundation-gate.md CONTEXT.md README.md; do
  if grep -qi "guardrail" "$root/$gf"; then
    echo "FAIL no-guardrail-handoff: token present in $gf"; fail=$((fail+1))
  else echo "ok no-guardrail-handoff($(basename "$gf"))"; fi
done
# presentation-protocol fragment has exactly one consumer this epic (assay)
extra="$(grep -rln "laydown-first-presentation" "$root/skills" "$root/agents" 2>/dev/null \
  | grep -v "skills/assay/SKILL.md" | grep -v "_shared/inject/laydown-first-presentation.md" || true)"
if [ -n "$extra" ]; then
  echo "FAIL fragment-single-consumer: unexpected consumer(s): $extra"; fail=$((fail+1))
else echo "ok fragment-single-consumer"; fi

# --- assay v2 P2: confirmed-facts source contract fragment (single home) ---
cfs="skills/_shared/inject/confirmed-facts-source.md"
[ -f "$root/$cfs" ] && echo "ok cfs-file" \
  || { echo "FAIL cfs-file: $cfs missing"; fail=$((fail+1)); }
chk "cfs-injected-by"        "$cfs" "^injected-by: \[design-spec, crucible\]"
# three-part qualification
chk "cfs-part-marked-area"   "$cfs" "marked.*confirmed.*facts|confirmed-facts area"
chk "cfs-part-per-fact-cite" "$cfs" "per-fact.*citation|stable.*per-fact"
chk "cfs-part-confirm-stamp" "$cfs" "confirmation event stamp"
# two citation-granularity levels
chk "cfs-field-level"        "$cfs" "field-level"
chk "cfs-row-level"          "$cfs" "row-level"
# four never-silent triggers — one chk EACH (dropping any one goes RED; AC-9)
chk "cfs-trigger-absent"      "$cfs" "\*\*absent\*\*"
chk "cfs-trigger-contradict"  "$cfs" "\*\*contradict\*\*"
chk "cfs-trigger-missing"     "$cfs" "\*\*missing\*\*"
chk "cfs-trigger-unparseable" "$cfs" "\*\*unparseable\*\*"
chk "cfs-disposition"        "$cfs" "NEEDS CLARIFICATION"
# naming rule: the class is "confirmed-facts source", never a seam
chk "cfs-naming-rule"        "$cfs" "never.*seam|not.*a seam"
# examples are implementations, not qualifying conditions
chk "cfs-examples-not-condition" "$cfs" "example implementations|examples?, n(ot|ever) .*(qualifying|condition)"
# the seam-name is forbidden on ALL shipped surfaces (AC-7)
if grep -rqi "confirmed-facts seam" "$root/skills" "$root/agents" "$root/commands" "$root/CONTEXT.md" "$root/README.md" 2>/dev/null; then
  echo "FAIL cfs-no-seam-name: 'confirmed-facts seam' present on a shipped surface"; fail=$((fail+1))
else echo "ok cfs-no-seam-name"; fi

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; exit 0; else echo "RED: $fail failed"; exit 1; fi
