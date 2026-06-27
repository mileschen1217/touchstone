#!/usr/bin/env bash
# Phase 3.2 anvil + front-end seam wiring tests.
# shellcheck disable=SC2016  # chk's 2nd arg is an eval string — single-quoting is intentional (deferred expansion)
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
chk "A1 no dangling link to architect-dispatch.md (inbound links removed)" \
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

# --- A5: new ADR supersedes 0015 (union != substitution) — located by GLOB, not a hard-coded number ---
# shellcheck disable=SC2034
adr="$(find docs/adr/ -name '*consolidated-design-review*' -maxdepth 1 2>/dev/null | head -1 | xargs basename 2>/dev/null || true)"
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

# --- B1: check-stage-return.py validator, fail-closed ---
sr=$(mktemp -d)
printf '{"schema":"stage-return/v1","stage":"plan-review","status":"DONE","artifacts":["p.md"]}' > "$sr/done.json"
chk "B1 well-formed DONE → DONE" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/done.json")" = "status=DONE" ]'
printf '{"schema":"stage-return/v1","stage":"plan-review","status":"BLOCKED","reason":"C+H=2"}' > "$sr/blk.json"
chk "B1 BLOCKED+reason → BLOCKED" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/blk.json")" = "status=BLOCKED" ]'
printf '{"schema":"stage-return/v1","stage":"plan-review","status":"NEEDS_HUMAN"}' > "$sr/nh.json"
chk "B1 NEEDS_HUMAN without reason → BLOCKED (fail closed)" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/nh.json")" = "status=BLOCKED" ]'
printf '{"schema":"stage-return/v1","stage":"plan-review","status":"DONE","reason":"x","artifacts":["p.md"]}' > "$sr/baddone.json"
chk "B1 DONE carrying a reason → BLOCKED (exclusion direction)" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/baddone.json")" = "status=BLOCKED" ]'
printf '{"schema":"stage-return/v1","stage":"plan-review","status":"DONE"}' > "$sr/noart.json"
chk "B1 DONE without artifacts → BLOCKED (DONE must produce an artifact)" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/noart.json")" = "status=BLOCKED" ]'
printf '{"schema":"stage-return/v1","stage":"plan-review","status":"BLOCKED","reason":"r","artifacts":["x"]}' > "$sr/artblk.json"
chk "B1 BLOCKED carrying artifacts → BLOCKED (reaches the artifacts rule with full fixture)" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/artblk.json")" = "status=BLOCKED" ]'
printf '{"schema":"stage-return/v1","stage":"bogus","status":"DONE","artifacts":["p.md"]}' > "$sr/badstage.json"
chk "B1 unknown stage → BLOCKED" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/badstage.json")" = "status=BLOCKED" ]'
printf 'not json' > "$sr/bad.json"
chk "B1 unparseable → BLOCKED" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/bad.json")" = "status=BLOCKED" ]'
chk "B1 missing file → BLOCKED" \
  '[ "$(python3 scripts/check-stage-return.py "$sr/nope.json")" = "status=BLOCKED" ]'
rm -rf "$sr"

# --- B2: normalize-stage-return.sh adapter ---
td=$(mktemp -d)
# review stage: clean (C+H=0, not degraded) → DONE
printf '{"status":"ok","providers_expected":["cc","codex"],"providers_used":["cc","codex"]}' > "$td/review.result.json"
printf 'findings...\nSTAGE-REVIEW-SUMMARY: critical=0 high=0 degraded=false\n' > "$td/review.md"
chk "B2 clean review → DONE" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=DONE" ]'
# C+H>=1 → BLOCKED
printf 'findings...\nSTAGE-REVIEW-SUMMARY: critical=1 high=2 degraded=false\n' > "$td/review.md"
chk "B2 C+H>=1 review → BLOCKED" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=BLOCKED" ]'
# degraded=true → NEEDS_HUMAN. The reviewer composite computes degraded per provenance.md
# Operation 3 and writes it into the sentinel (the adapter TRUSTS the sentinel — degraded is NEVER
# stored in review.result.json). Make the fixture realistic: providers_used ⊊ providers_expected.
printf '{"status":"ok","providers_expected":["cc","codex"],"providers_used":["cc"]}' > "$td/review.result.json"
printf 'findings...\nSTAGE-REVIEW-SUMMARY: critical=0 high=0 degraded=true\n' > "$td/review.md"
chk "B2 degraded review → NEEDS_HUMAN" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=NEEDS_HUMAN" ]'
# missing sentinel → BLOCKED (fail closed)
printf 'findings... no sentinel\n' > "$td/review.md"
chk "B2 missing sentinel → BLOCKED" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=BLOCKED" ]'
# entry-precondition: exit 0 → DONE
printf 'PRE-CHECK OK\n' > "$td/precheck.out"; echo 0 > "$td/precheck.rc"
chk "B2 precheck exit0 → DONE" \
  '[ "$(bash scripts/normalize-stage-return.sh entry-precondition "$td")" = "status=DONE" ]'
printf 'BLOCK: stale\n' > "$td/precheck.out"; echo 1 > "$td/precheck.rc"
chk "B2 precheck nonzero → BLOCKED" \
  '[ "$(bash scripts/normalize-stage-return.sh entry-precondition "$td")" = "status=BLOCKED" ]'
# fail-closed guards (FIX 1): missing review.result.json, unknown status, duplicate sentinel
rm -f "$td/review.result.json"
printf 'findings...\nSTAGE-REVIEW-SUMMARY: critical=0 high=0 degraded=false\n' > "$td/review.md"
chk "B2 missing review.result.json → BLOCKED" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=BLOCKED" ]'
printf '{"status":"bogus_status"}' > "$td/review.result.json"
chk "B2 status not in enum → BLOCKED" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=BLOCKED" ]'
printf '{"status":"ok"}' > "$td/review.result.json"
printf 'STAGE-REVIEW-SUMMARY: critical=0 high=0 degraded=false\nextra\nSTAGE-REVIEW-SUMMARY: critical=0 high=0 degraded=false\n' > "$td/review.md"
chk "B2 duplicate sentinel → BLOCKED" \
  '[ "$(bash scripts/normalize-stage-return.sh plan-review "$td")" = "status=BLOCKED" ]'
rm -rf "$td"

# --- B3: anvil SKILL.md plain orchestrator ---
# shellcheck disable=SC2034
A=skills/anvil/SKILL.md
chk "B3 anvil SKILL.md exists, user-invocable" \
  'test -f "$A" && grep -qE "user-invocable: true" "$A"'
chk "B6 anvil is plain orchestrator, NOT Workflow-tool" \
  'grep -qiE "plain orchestrator" "$A" && ! grep -qiE "Workflow-tool (JS )?script that (anvil|it) (is|runs)" "$A"'
chk "B7 anvil documents the fixed stage sequence" \
  'grep -qE "entry-precondition" "$A" && grep -qE "writing-plans" "$A" && grep -qE "plan-review" "$A" && grep -qiE "final.*review" "$A"'
chk "B7 anvil runs the writing-plans boundary check" \
  'grep -qiE "boundary check|non-empty|exists.*task" "$A"'
chk "B11 anvil consumes the structured-return via the adapter+validator" \
  'grep -qE "normalize-stage-return|stage-return" "$A"'
chk "B12 anvil stops before ship (no push/PR/merge)" \
  'grep -qiE "stops? (at|before).*(branch|ship)|never (push|open a PR|merge)" "$A"'
chk "B13 anvil never promotes AC to verified" \
  'grep -qiE "never (promote|mark).*(verified)|\[unverified\].*(survive|intact)" "$A"'
chk "B15 anvil honest-ceiling bounded (no per-task over-claim)" \
  'grep -qiE "honest ceiling" "$A" && ! grep -qiE "program-enforced per-task|hard gate" "$A"'
chk "B11 anvil escalates NEEDS_HUMAN/BLOCKED (halt-on-stuck)" \
  'grep -qE "NEEDS_HUMAN" "$A" && grep -qE "BLOCKED" "$A" && grep -qiE "halt|escalat|surface" "$A"'

# --- B4: dogfood instrumentation ---
# NOTE: these tests witness that anvil DOCUMENTS the dogfood report shape; they do NOT verify
# a real anvil run produced the artifact. AC-14 live behaviour is [unverified] pending the first
# end-to-end anvil dogfood run.
chk "B14 anvil documents the dogfood report shape (cost + catch-attribution fields specified)" \
  'grep -qiE "dogfood" skills/anvil/SKILL.md && grep -qiE "catch-attribution" skills/anvil/SKILL.md'
chk "B14 anvil documents honest token degradation annotation" \
  'grep -qE "\[unverified: token capture\]" skills/anvil/SKILL.md'
chk "B14 anvil documents provenance floor fields (contract + date + commit hash)" \
  'grep -qiE "commit hash|rev-parse" skills/anvil/SKILL.md'

# --- B5: anvil registered + suite green ---
chk "B5 anvil skill dir present with SKILL.md" 'test -f skills/anvil/SKILL.md'
# Registration check: skills are auto-discovered by directory (no manifest skill list —
# the other skills aren't listed in plugin.json either; presence of the dir IS registration).

echo "$fail"
exit "$fail"
