#!/usr/bin/env bash
# Smoke suite for the surviving deterministic checkers + the run-project-checks
# hook's classify_command. One green + one red case per target. Not a
# replacement for scripts/tests/ (removed) — just a fast sanity net.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fx="$here/fixtures"
scripts_dir="$(cd "$here/.." && pwd)"
hooks_dir="$(cd "$here/../../hooks" && pwd)"

fail=0

# expect_exit <label> <expected: zero|nonzero> -- <cmd...>
expect_exit() {
  label="$1"; want="$2"; shift 2
  out="$("$@" 2>&1)"; rc=$?
  if { [ "$want" = zero ] && [ "$rc" -eq 0 ]; } || { [ "$want" = nonzero ] && [ "$rc" -ne 0 ]; }; then
    echo "PASS: $label"
  else
    echo "FAIL: $label (rc=$rc, want=$want)"; echo "$out"
    fail=1
  fi
}

# expect_out <label> <fixed-string> -- <cmd...>  — output must contain the string
expect_out() {
  label="$1"; pat="$2"; shift 2
  out="$("$@" 2>&1)"
  if printf '%s' "$out" | grep -qF -- "$pat"; then echo "PASS: $label"; else echo "FAIL: $label (missing: $pat)"; echo "$out"; fail=1; fi
}

# ---- check-artifact.sh: one green + one red per kind; each violation class asserted by line
ax="$here/fixtures/artifacts"; ca="$scripts_dir/check-artifact.sh"
expect_exit "check-artifact spec green (bootstrap-shaped)" zero bash "$ca" spec "$ax/spec-green.yaml" --root "$ax"
expect_out "check-artifact spec: numeric literal without basis is a warning" "warn: requirements[REQ-1].acs[AC-3].then: numeric literal" bash "$ca" spec "$ax/spec-green.yaml" --root "$ax"
expect_exit "check-artifact spec red" nonzero bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: block without purpose" "delta.blocks[parser].purpose: required" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: invariant without check" "invariants[INV-1].check: required" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: dangling ledger id" "requirements[REQ-1].basis: 'Q-99' resolves to no ledger line" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: path token in phase_map" "phase_map.position: human-facing panel carries a path-like token" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: unknown key under REQ" "requirements[REQ-1].notes: unknown key" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: invalid status enum" "status: 'done' not in" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: invalid check enum" "invariants[INV-2].check: 'manual' not in" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: dangling traces_to" "requirements[REQ-1].traces_to: 'US-9' names no US id" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: duplicate AC id" "duplicate id AC-1" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: dangling edge endpoint" "delta.edges[0].to: 'nowhere' names no block id" bash "$ca" spec "$ax/spec-red.yaml" --root "$ax"
expect_out "check-artifact spec: missing phase_map" "phase_map: required" bash "$ca" spec "$ax/spec-red-nomap.yaml" --root "$ax"

expect_exit "check-artifact review green" zero bash "$ca" review "$ax/review-green.yaml" --root "$ax"
expect_exit "check-artifact review red" nonzero bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: duplicate F id" "duplicate id F-3" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: missing waiting_on_human" "waiting_on_human: required" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: field path unresolvable in target" "'requirements[REQ-99].acs[AC-1]' resolves to nothing in the target spec" bash "$ca" review "$ax/review-red.yaml" --root "$ax"
expect_out "check-artifact review: [*] on an empty list resolves to nothing" "'waiting_on_human[*]' resolves to nothing" bash "$ca" review "$ax/review-red-star.yaml" --root "$ax"
expect_out "check-artifact review: degraded without reason" "degraded_reason: required when degraded is true" bash "$ca" review "$ax/review-red.yaml" --root "$ax"

# degraded_reason carries a closed literal set (six shapes) — free-form prose is rejected
expect_exit "check-artifact review: degraded_reason free-form prose" nonzero bash "$ca" review "$ax/review-red-degraded-enum.yaml" --root "$ax"
expect_out "check-artifact review: degraded_reason outside the six literal shapes" "degraded_reason: 'codex was flaky today' does not match pattern" bash "$ca" review "$ax/review-red-degraded-enum.yaml" --root "$ax"
# the independence-lost fallback shape (a real gate producer) is admitted
expect_exit "check-artifact review: independence-lost degraded_reason admitted" zero bash "$ca" review "$ax/review-degraded-independence-green.yaml" --root "$ax"

# kind epic: the spec is the authority on live_bearing — a demoted row is rejected
expect_exit "check-artifact epic: spec-live AC demoted in reckoning" nonzero bash "$ca" epic "$ax/epic-close-red-live-demoted/epic.yaml" --root "$ax/epic-close-red-live-demoted"
expect_out "check-artifact epic: demotion names the spec authority" "contradicts the accepted spec's AC" bash "$ca" epic "$ax/epic-close-red-live-demoted/epic.yaml" --root "$ax/epic-close-red-live-demoted"
# kind epic: a phases[].spec path escaping the epic root is rejected (path guard)
expect_exit "check-artifact epic: phases[].spec escaping --root" nonzero bash "$ca" epic "$ax/epic-close-red-spec-escape/epic.yaml" --root "$ax/epic-close-red-spec-escape"
expect_out "check-artifact epic: escape names the guard" "escapes the --root directory" bash "$ca" epic "$ax/epic-close-red-spec-escape/epic.yaml" --root "$ax/epic-close-red-spec-escape"
# kind epic: duplicate reckoning rows for one AC are rejected
expect_exit "check-artifact epic: duplicate reckoning row" nonzero bash "$ca" epic "$ax/epic-close-red-dup-reckoning/epic.yaml" --root "$ax/epic-close-red-dup-reckoning"
expect_out "check-artifact epic: duplicate row named" "duplicate row for the same AC" bash "$ca" epic "$ax/epic-close-red-dup-reckoning/epic.yaml" --root "$ax/epic-close-red-dup-reckoning"

# AC ids restart per spec — a multi-spec epic's reckoning joins by (spec, ac)
expect_exit "check-artifact epic: multi-spec reckoning joined by (spec, ac)" zero bash "$ca" epic "$ax/epic-close-green-multispec/epic.yaml" --root "$ax/epic-close-green-multispec"
expect_exit "check-artifact epic: spec-less row on an id two specs define" nonzero bash "$ca" epic "$ax/epic-close-red-ambiguous-row/epic.yaml" --root "$ax/epic-close-red-ambiguous-row"
expect_out "check-artifact epic: ambiguous row names the rule" "the row must carry \`spec:\` naming one of them" bash "$ca" epic "$ax/epic-close-red-ambiguous-row/epic.yaml" --root "$ax/epic-close-red-ambiguous-row"

# roadmap-render: a normal render fails loudly on an invalid epic dir (never a silent omission)
rrbad="$(mktemp -d)"; mkdir -p "$rrbad/.touchstone/epics/2026-01-01-broken"
printf 'not: [valid\n' > "$rrbad/.touchstone/epics/2026-01-01-broken/epic.yaml"
expect_exit "roadmap-render: invalid epic dir fails the render" nonzero bash "$scripts_dir/roadmap-render.sh" --root "$rrbad"
expect_out "roadmap-render: invalid dir named on stderr" "INVALID epic dir" bash "$scripts_dir/roadmap-render.sh" --root "$rrbad"
rm -rf "$rrbad"

# AC-3: waiting_on_human is a list of W-n objects — the legacy list-of-strings shape is rejected
expect_exit "check-artifact review: legacy waiting_on_human strings" nonzero bash "$ca" review "$ax/review-red-legacy-w.yaml" --root "$ax"
expect_out "check-artifact review: legacy waiting_on_human[0] not an object" "waiting_on_human[0]: expected object" bash "$ca" review "$ax/review-red-legacy-w.yaml" --root "$ax"

# AC-5: duplicate W-n id
expect_exit "check-artifact review: duplicate W id" nonzero bash "$ca" review "$ax/review-red-dup-w.yaml" --root "$ax"
expect_out "check-artifact review: duplicate W id names W-1" "duplicate id W-1" bash "$ca" review "$ax/review-red-dup-w.yaml" --root "$ax"

# AC-4: a finding's refs value must resolve to a US/REQ/AC/INV id in the target spec
expect_exit "check-artifact review: unresolved refs id" nonzero bash "$ca" review "$ax/review-red-ref.yaml" --root "$ax"
expect_out "check-artifact review: unresolved refs id names findings[F-1].refs[0]" "findings[F-1].refs[0]: 'AC-99' resolves to no id in spec-green.yaml" bash "$ca" review "$ax/review-red-ref.yaml" --root "$ax"

# AC-48: a finding with no field, no file and empty refs has no locator; file+line beside refs:[] is fine (green half below)
expect_exit "check-artifact review: no locator" nonzero bash "$ca" review "$ax/review-red-noloc.yaml" --root "$ax"
expect_out "check-artifact review: no locator names the finding" "findings[F-1]: no locator (field, file or refs)" bash "$ca" review "$ax/review-red-noloc.yaml" --root "$ax"
expect_exit "check-artifact review: empty providers" nonzero bash "$ca" review "$ax/review-red-providers-empty.yaml" --root "$ax"
expect_out "check-artifact review: empty providers names minItems" "providers: minItems 1" bash "$ca" review "$ax/review-red-providers-empty.yaml" --root "$ax"
expect_exit "check-artifact review: found_by arm outside its lens providers" nonzero bash "$ca" review "$ax/review-red-foundby-arm.yaml" --root "$ax"
expect_out "check-artifact review: found_by arm outside its lens providers is named" "found_by: 'cc' is not an arm of lens 'design-soundness' in providers" bash "$ca" review "$ax/review-red-foundby-arm.yaml" --root "$ax"

# AC-29: found_by: [] fails the array's minItems 1
expect_exit "check-artifact review: found_by empty" nonzero bash "$ca" review "$ax/review-red-foundby-empty.yaml" --root "$ax"
expect_out "check-artifact review: found_by empty names minItems" "findings[F-1].found_by: minItems 1" bash "$ca" review "$ax/review-red-foundby-empty.yaml" --root "$ax"

# AC-14: coverage[] rows validate against delta.contracts[coverage-row] (review-green.yaml
# carries one); a conformance finding marked status: covered is rejected with the reason
# "covered rows belong in coverage[]" — not the generic enum message
expect_exit "check-artifact review: coverage row validates (green carries one)" zero bash "$ca" review "$ax/review-green.yaml" --root "$ax"
expect_exit "check-artifact review: conformance finding marked covered" nonzero bash "$ca" review "$ax/review-red-covered-in-findings.yaml" --root "$ax"
expect_out "check-artifact review: covered finding names the coverage[] reason" "findings[F-1].status: covered rows belong in coverage[]" bash "$ca" review "$ax/review-red-covered-in-findings.yaml" --root "$ax"

expect_exit "check-artifact review: read-back-incomplete degraded round admitted (AC-17)" zero bash "$ca" review "$ax/review-degraded-readback-green.yaml" --root "$ax"
expect_exit "check-artifact review: fragments_read missing on non-degraded round" nonzero bash "$ca" review "$ax/newform-round/review-red-missing-fragments.yaml" --root "$ax"
expect_out "check-artifact review: fragments_read missing names the entry and the rule" "providers[conformance].fragments_read: required unless the round is degraded" bash "$ca" review "$ax/newform-round/review-red-missing-fragments.yaml" --root "$ax"
expect_exit "check-artifact review: every providers entry carries fragments_read, degraded false" zero bash "$ca" review "$ax/review-green-fragments.yaml" --root "$ax"
expect_exit "check-artifact review: empty fragments_read list rejected" nonzero bash "$ca" review "$ax/review-red-fragments-empty.yaml" --root "$ax"
expect_out "check-artifact review: empty fragments_read names the entry" "providers[conformance].fragments_read: must not be empty" bash "$ca" review "$ax/review-red-fragments-empty.yaml" --root "$ax"
expect_exit "check-artifact review: plugin-review producer exempt from fragments_read (rubric-sliced lens, no manifest ids)" zero bash "$ca" review "$ax/review-green-plugin-review.yaml" --root "$ax"

expect_exit "check-artifact deviation green" zero bash "$ca" deviation "$ax/deviation-green.yaml" --root "$ax"
expect_exit "check-artifact deviation red" nonzero bash "$ca" deviation "$ax/deviation-red.yaml" --root "$ax"
expect_out "check-artifact deviation: missing which_stage_could_have_caught" "entries[D-1].which_stage_could_have_caught: required" bash "$ca" deviation "$ax/deviation-red.yaml" --root "$ax"
expect_out "check-artifact deviation: invalid panel" "entries[D-1].panel: 'flow' not in" bash "$ca" deviation "$ax/deviation-red.yaml" --root "$ax"

# AC-7: an entry's empty refs is legal only beside derived: true
expect_exit "check-artifact deviation: empty refs without derived" nonzero bash "$ca" deviation "$ax/deviation-red-refs-empty.yaml" --root "$ax"
expect_out "check-artifact deviation: empty refs without derived names entries[D-1].refs" "entries[D-1].refs: empty refs require derived: true" bash "$ca" deviation "$ax/deviation-red-refs-empty.yaml" --root "$ax"

# AC-1: the quiz block moved out of deviation — no `quiz:` property key remains in the
# schema (a header comment may still name the migration in prose; the grammar check is the
# absence of a `quiz:` property line), and a deviation fixture carrying a quiz block fails
# with an unknown-key error
if grep -qE '^[[:space:]]*quiz:' "$scripts_dir/../skills/_shared/schemas/deviation.schema.yaml"; then
  echo "FAIL: deviation.schema.yaml still declares a quiz: property"; fail=1
else
  echo "PASS: deviation.schema.yaml declares no quiz: property"
fi
expect_exit "check-artifact deviation: quiz block is now an unknown key" nonzero bash "$ca" deviation "$ax/deviation-red-quiz-key.yaml" --root "$ax"
expect_out "check-artifact deviation: quiz block names the unknown key" "quiz: unknown key" bash "$ca" deviation "$ax/deviation-red-quiz-key.yaml" --root "$ax"

# AC-20: metrics is a per-phase list — a duplicate phase and a non-40-hex measured_at both
# fail; a list with distinct phases (deviation-green-metrics.yaml) passes
expect_exit "check-artifact deviation: metrics duplicate phase" nonzero bash "$ca" deviation "$ax/deviation-red-metrics-dup.yaml" --root "$ax"
expect_out "check-artifact deviation: metrics duplicate phase names the phase" "metrics: duplicate phase 1" bash "$ca" deviation "$ax/deviation-red-metrics-dup.yaml" --root "$ax"
expect_exit "check-artifact deviation: metrics measured_at not 40-hex" nonzero bash "$ca" deviation "$ax/deviation-red-metrics-sha.yaml" --root "$ax"
expect_out "check-artifact deviation: metrics measured_at not 40-hex names the path" "metrics[0].measured_at" bash "$ca" deviation "$ax/deviation-red-metrics-sha.yaml" --root "$ax"
expect_exit "check-artifact deviation: valid metrics list (two distinct phases)" zero bash "$ca" deviation "$ax/deviation-green-metrics.yaml" --root "$ax"
expect_exit "check-artifact deviation: metrics stage_tokens missing stages" nonzero bash "$ca" deviation "$ax/deviation-red-metrics-stages.yaml" --root "$ax"
expect_out "check-artifact deviation: metrics stage_tokens missing stages names the path" "metrics[0].stage_tokens: stages 0-5 each exactly once" bash "$ca" deviation "$ax/deviation-red-metrics-stages.yaml" --root "$ax"

# ---- check-artifact.sh quiz kind (REQ-1 / AC-2): green + one red per violation class
expect_exit "check-artifact quiz green" zero bash "$ca" quiz "$ax/quiz-green.yaml" --root "$ax"
expect_exit "check-artifact quiz: duplicate QZ id" nonzero bash "$ca" quiz "$ax/quiz-red-dup-qz.yaml" --root "$ax"
expect_out "check-artifact quiz: duplicate QZ id names QZ-1" "duplicate id QZ-1" bash "$ca" quiz "$ax/quiz-red-dup-qz.yaml" --root "$ax"
expect_exit "check-artifact quiz: answered item with no result" nonzero bash "$ca" quiz "$ax/quiz-red-answer-no-result.yaml" --root "$ax"
expect_out "check-artifact quiz: answered item with no result names the rule" "items[QZ-1].result: required once answered" bash "$ca" quiz "$ax/quiz-red-answer-no-result.yaml" --root "$ax"
expect_exit "check-artifact quiz: unresolvable ref" nonzero bash "$ca" quiz "$ax/quiz-red-ref.yaml" --root "$ax"
expect_out "check-artifact quiz: unresolvable ref names the id" "items[QZ-1].refs[0]: 'AC-99' resolves to no id in phase1.spec.yaml" bash "$ca" quiz "$ax/quiz-red-ref.yaml" --root "$ax"
expect_exit "check-artifact quiz: non-int items[].phase" nonzero bash "$ca" quiz "$ax/quiz-red-item-phase.yaml" --root "$ax"
expect_out "check-artifact quiz: non-int items[].phase names the field" "items[QZ-1].phase: expected integer" bash "$ca" quiz "$ax/quiz-red-item-phase.yaml" --root "$ax"
expect_exit "check-artifact quiz: phase_summaries non-int phase / missing text" nonzero bash "$ca" quiz "$ax/quiz-red-summary.yaml" --root "$ax"
expect_out "check-artifact quiz: phase_summaries non-int phase" "phase_summaries[0].phase: expected integer" bash "$ca" quiz "$ax/quiz-red-summary.yaml" --root "$ax"
expect_out "check-artifact quiz: phase_summaries missing text" "phase_summaries[1].text: required" bash "$ca" quiz "$ax/quiz-red-summary.yaml" --root "$ax"
expect_exit "check-artifact quiz: retired legacy kind/expected_refs/answer_refs" nonzero bash "$ca" quiz "$ax/quiz-red-legacy.yaml" --root "$ax"
expect_out "check-artifact quiz: legacy kind is an unknown key" "items[QZ-1].kind: unknown key" bash "$ca" quiz "$ax/quiz-red-legacy.yaml" --root "$ax"
expect_out "check-artifact quiz: legacy expected_refs is an unknown key" "items[QZ-1].expected_refs: unknown key" bash "$ca" quiz "$ax/quiz-red-legacy.yaml" --root "$ax"
expect_out "check-artifact quiz: legacy answer_refs is an unknown key" "items[QZ-1].answer_refs: unknown key" bash "$ca" quiz "$ax/quiz-red-legacy.yaml" --root "$ax"

# ---- check-artifact.sh assay kind (REQ-2 / AC-6, AC-7): green + one red per violation class
expect_exit "check-artifact assay green" zero bash "$ca" assay "$ax/assay-green.yaml" --root "$ax"
expect_exit "check-artifact assay: missing consensus subsection" nonzero bash "$ca" assay "$ax/assay-red-consensus.yaml" --root "$ax"
expect_out "check-artifact assay: missing consensus subsection names it" "consensus.out_of_scope: required" bash "$ca" assay "$ax/assay-red-consensus.yaml" --root "$ax"
expect_exit "check-artifact assay: duplicate ledger id within a family" nonzero bash "$ca" assay "$ax/assay-red-dup-id.yaml" --root "$ax"
expect_out "check-artifact assay: duplicate ledger id within a family names T-1" "duplicate id T-1" bash "$ca" assay "$ax/assay-red-dup-id.yaml" --root "$ax"
expect_exit "check-artifact assay: readiness without date" nonzero bash "$ca" assay "$ax/assay-red-readiness.yaml" --root "$ax"
expect_out "check-artifact assay: readiness without date names it" "readiness.date: required" bash "$ca" assay "$ax/assay-red-readiness.yaml" --root "$ax"
# AC-7: a spec whose facts_source.record names an assay .yaml record resolves consensus ids
# by structured lookup (the .md read-compat half is exercised by spec-green.yaml + ledger.md
# above)
expect_exit "check-artifact spec: facts_source.record names an assay .yaml record (AC-7)" zero bash "$ca" spec "$ax/spec-assayledger-green.yaml" --root "$ax"

# ---- check-artifact.sh explore kind (REQ-3 / AC-13): green + one red per violation class
expect_exit "check-artifact explore green" zero bash "$ca" explore "$ax/explore-green.yaml" --root "$ax"
expect_exit "check-artifact explore: plateau false without reach_under_determined" nonzero bash "$ca" explore "$ax/explore-red-plateau.yaml" --root "$ax"
expect_out "check-artifact explore: plateau false without reach_under_determined names it" "reach_under_determined: required when plateau is false" bash "$ca" explore "$ax/explore-red-plateau.yaml" --root "$ax"
expect_exit "check-artifact explore: seam_maps entry without parties" nonzero bash "$ca" explore "$ax/explore-red-parties.yaml" --root "$ax"
expect_out "check-artifact explore: seam_maps entry without parties names it" "seam_maps[0].parties: required" bash "$ca" explore "$ax/explore-red-parties.yaml" --root "$ax"

# ---- check-artifact.sh epic kind (phase 6, epic-yaml): green (rich + minimal) and one
# red fixture per blocking close-gate rule; AC-1..AC-4, AC-35
expect_exit "check-artifact epic green" zero bash "$ca" epic "$ax/epic-green.yaml" --root "$ax"
expect_exit "check-artifact epic minimal green (required fields only)" zero bash "$ca" epic "$ax/epic-minimal-green.yaml" --root "$ax"
expect_exit "check-artifact epic close-green: fully-reckoned done epic (AC-35)" zero bash "$ca" epic "$ax/epic-close-green/epic.yaml" --root "$ax/epic-close-green"

expect_exit "check-artifact epic: dual hand-written form (AC-2)" nonzero bash "$ca" epic "$ax/epic-close-red-dual-form/epic.yaml" --root "$ax/epic-close-red-dual-form"
expect_out "check-artifact epic: dual hand-written form names the dual form" "index.md present beside epic.yaml with no generated-projection marker" bash "$ca" epic "$ax/epic-close-red-dual-form/epic.yaml" --root "$ax/epic-close-red-dual-form"

expect_exit "check-artifact epic: unreckoned AC on a done epic (AC-3)" nonzero bash "$ca" epic "$ax/epic-close-red-unreckoned-ac/epic.yaml" --root "$ax/epic-close-red-unreckoned-ac"
expect_out "check-artifact epic: unreckoned AC names the AC" "reckoning: AC-2 in sample.spec.yaml has no reckoning[] row" bash "$ca" epic "$ax/epic-close-red-unreckoned-ac/epic.yaml" --root "$ax/epic-close-red-unreckoned-ac"

expect_exit "check-artifact epic: empty reckoning row (no covered_by/unverified/waiver)" nonzero bash "$ca" epic "$ax/epic-close-red-empty-row/epic.yaml" --root "$ax/epic-close-red-empty-row"
expect_out "check-artifact epic: empty reckoning row names the row" "reckoning[AC-1]: no covered_by, no unverified mark, and no waiver" bash "$ca" epic "$ax/epic-close-red-empty-row/epic.yaml" --root "$ax/epic-close-red-empty-row"

expect_exit "check-artifact epic: live-bearing row with proxy-only covered_by (INV-5)" nonzero bash "$ca" epic "$ax/epic-close-red-live-bearing-proxy/epic.yaml" --root "$ax/epic-close-red-live-bearing-proxy"
expect_out "check-artifact epic: live-bearing proxy-only coverage is rejected, not 'field non-empty'" "live-bearing row requires live-artifact provenance" bash "$ca" epic "$ax/epic-close-red-live-bearing-proxy/epic.yaml" --root "$ax/epic-close-red-live-bearing-proxy"

expect_exit "check-artifact epic: unverified row with no issue" nonzero bash "$ca" epic "$ax/epic-close-red-unverified-no-issue/epic.yaml" --root "$ax/epic-close-red-unverified-no-issue"
expect_out "check-artifact epic: unverified row with no issue names the rule" "reckoning[AC-1].issue: required when unverified or waiver is set" bash "$ca" epic "$ax/epic-close-red-unverified-no-issue/epic.yaml" --root "$ax/epic-close-red-unverified-no-issue"

expect_exit "check-artifact epic: done epic with empty retrospective" nonzero bash "$ca" epic "$ax/epic-close-red-no-retrospective/epic.yaml" --root "$ax/epic-close-red-no-retrospective"
expect_out "check-artifact epic: empty retrospective names the rule" "retrospective: required (non-empty) when status is done" bash "$ca" epic "$ax/epic-close-red-no-retrospective/epic.yaml" --root "$ax/epic-close-red-no-retrospective"

expect_exit "check-artifact epic: phases[].n does not match its linked spec's phase (AC-4)" nonzero bash "$ca" epic "$ax/epic-close-red-phase-mismatch/epic.yaml" --root "$ax/epic-close-red-phase-mismatch"
expect_out "check-artifact epic: phase mismatch names both numbers" "phases[6].n: 6 does not match sample.spec.yaml's top-level phase (5)" bash "$ca" epic "$ax/epic-close-red-phase-mismatch/epic.yaml" --root "$ax/epic-close-red-phase-mismatch"

# AC-2 green half: an index.md carrying the generated-projection marker beside epic.yaml is legal
epic_marker_root="$(mktemp -d)"
cp "$ax/epic-close-red-dual-form/epic.yaml" "$epic_marker_root/epic.yaml"
printf '%s\n' '<!-- generated: projection of epic.yaml -->' > "$epic_marker_root/index.md"
expect_exit "check-artifact epic: generated-marker index.md beside epic.yaml is legal" zero bash "$ca" epic "$epic_marker_root/epic.yaml" --root "$epic_marker_root"
rm -rf "$epic_marker_root"

# AC-14: the usage line lists exactly the seven kinds
expect_out "check-artifact usage lists exactly seven kinds" "usage: check-artifact.sh <spec|review|deviation|quiz|assay|explore|epic> <file> [--root <dir>]" bash "$ca" bogus "$ax/spec-green.yaml"

# AC-15: the three hard-coded resolution branches (spec/review/deviation dispatched by
# `kind ==`) are gone — resolution reads each schema's declared `resolves` value instead.
# This grep targets the literal old ledger-resolution branch shape; it must find nothing.
if grep -qE "kind == 'review' and isinstance\(target_doc" "$ca"; then
  echo "FAIL: check-artifact.sh still carries a kind-specific resolution branch"; fail=1
else
  echo "PASS: check-artifact.sh resolution dispatch carries no kind-specific branch"
fi
if grep -q "resolves = schema.get('resolves')" "$ca"; then
  echo "PASS: check-artifact.sh resolution dispatch reads the schema's declared resolves value"
else
  echo "FAIL: check-artifact.sh does not read a declared resolves value"; fail=1
fi

python3 - "$ca" "$ax" <<'PY3' || { echo "FAIL: check-artifact edge cases"; fail=1; }
import subprocess, sys, os, tempfile, shutil
ca, ax = sys.argv[1], sys.argv[2]
t = tempfile.mkdtemp()
shutil.copy(os.path.join(ax, 'spec-green.yaml'), t); shutil.copy(os.path.join(ax, 'ledger.md'), t)
shutil.copy(os.path.join(ax, 'phase1.spec.yaml'), t)
def run(kind, text, name):
    p = os.path.join(t, name); open(p, 'w').write(text)
    r = subprocess.run(['bash', ca, kind, p, '--root', t], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr
base = open(os.path.join(ax, 'review-green.yaml')).read()
rc, out = run('review', base.replace('field: requirements[REQ-1].acs[AC-2].then', 'field: requirements[*].acs[AC-3].then'), 'r1.yaml')
assert rc == 0, out   # AC-3 sits under REQ-1; [*] must search every requirement
rc, out = run('review', base.replace('target: spec-green.yaml', 'target: ../spec-green.yaml'), 'r2.yaml')
assert rc == 1 and "escapes the --root" in out, out
open(os.path.join(t, 'ledger.md'), 'a').write('\n- Q-7a · suffixed id.\n')
spec = open(os.path.join(ax, 'spec-green.yaml')).read()
rc, out = run('spec', spec.replace('basis: [Q-1]', 'basis: [Q-7]'), 's1.yaml')
assert rc == 1 and "'Q-7' resolves to no ledger line" in out, out   # Q-7a must not resolve Q-7
rc, out = run('spec', spec.replace('date: 2026-01-01', 'date: "2026-01-01"'), 's2.yaml')
assert rc == 0, out   # quoted date string accepted
rc, out = run('spec', spec.replace('date: 2026-01-01', 'date: 20260101'), 's3.yaml')
assert rc == 1 and 'date: expected date' in out, out

# AC-4 green half: refs [AC-2] (a real id) exits 0
ref_red = open(os.path.join(ax, 'review-red-ref.yaml')).read()
rc, out = run('review', ref_red.replace('refs: [AC-99]', 'refs: [AC-2]'), 'r3.yaml')
assert rc == 0, out

# AC-48 green half: file + line beside refs: [] exits 0
noloc_red = open(os.path.join(ax, 'review-red-noloc.yaml')).read()
noloc_green = noloc_red.replace('refs: []', 'file: skills/design-review/SKILL.md\n    line: 12\n    refs: []')
rc, out = run('review', noloc_green, 'r4.yaml')
assert rc == 0, out

# quiz kind: refs: [] is rejected by the schema's minItems 1; an unanswered item (no
# answer, no result) with valid refs passes; a quiz item's refs must resolve in the
# phase-matched spec, and a phase with no spec under --root warns (exit unchanged) rather
# than errors
base_q = '''waived: false
items:
  - id: QZ-1
    phase: {phase}
    question: q
    refs: {refs}
    anchor: requirements[REQ-1].acs[AC-1]
{extra}'''
rc, out = run('quiz', base_q.format(phase=1, refs='[]', extra=''), 'q1.yaml')
assert rc == 1 and 'items[QZ-1].refs: minItems 1' in out, out
rc, out = run('quiz', base_q.format(phase=1, refs='[AC-1]', extra=''), 'q2.yaml')
assert rc == 0, out   # unanswered item, valid refs, passes
rc, out = run('quiz', base_q.format(phase=99, refs='[AC-1]', extra=''), 'q3.yaml')
assert rc == 0 and 'no spec for phase 99 found under --root' in out, out

# an answered item requires a result; once both are present it passes
answered = base_q.format(phase=1, refs='[AC-1]', extra='    answer: a\n')
rc, out = run('quiz', answered, 'q4.yaml')
assert rc == 1 and 'items[QZ-1].result: required once answered' in out, out
rc, out = run('quiz', answered.replace('anchor: requirements[REQ-1].acs[AC-1]\n', 'anchor: requirements[REQ-1].acs[AC-1]\n    result: pass\n'), 'q5.yaml')
assert rc == 0, out

# AC-20: one metrics entry passes; a 39-hex measured_at fails naming the path
base_m = '''entries: []
metrics:
  - phase: 1
    wall_clock_h: 1.0
    human_turns: 1
    dispatches: 1
    lens_h: {{coverage: 1}}
    stage_tokens: [{{stage: 0, tokens: 10}}, {{stage: 1, tokens: 1}}, {{stage: 2, tokens: 1}}, {{stage: 3, tokens: 1}}, {{stage: 4, tokens: 1}}, {{stage: 5, tokens: 1}}]
    false_edges: 0
    instrument_churn: {{shape_driven_lines: 1, other_lines: 0}}
    measured_at: {sha}
waiting_on_human: []
'''
sha40 = ('0123456789abcdef' * 3)[:40]
rc, out = run('deviation', base_m.format(sha=sha40), 'm1.yaml')
assert rc == 0, out
rc, out = run('deviation', base_m.format(sha=sha40[:39]), 'm2.yaml')
assert rc == 1 and 'metrics[0].measured_at' in out and 'does not match pattern' in out, out

# AC-14: a coverage row whose ref does not resolve in the target spec fails; a finding whose
# lens is NOT conformance carrying status: covered gets the plain enum rejection, never the
# coverage[]-specific message
rgreen = open(os.path.join(ax, 'review-green.yaml')).read()
cov_bad = rgreen.replace('ref: AC-1', 'ref: AC-99')
rc, out = run('review', cov_bad, 'cv1.yaml')
assert rc == 1 and "'AC-99' resolves to no id in spec-green.yaml" in out, out
noncon = rgreen.replace('status: open', 'status: covered')
rc, out = run('review', noncon, 'cv2.yaml')
assert rc == 1 and "not in ['open', 'fixed', 'waived', 'unverified']" in out and 'covered rows belong in coverage[]' not in out, out

shutil.rmtree(t)
print('PASS: check-artifact existential [*], root escape rejected, ledger id boundary, date type, refs resolution (AC-4), locator rule (AC-48), quiz kind refs/result rule, metrics duplicate/sha (AC-20), coverage-row resolution + non-conformance covered stays a plain enum rejection (AC-14)')
PY3
expect_out "check-artifact usage error" "usage:" bash "$ca" bogus "$ax/spec-green.yaml"
# the eight schema files exist and every top-level field carries a reader tag
python3 - "$scripts_dir/../skills/_shared/schemas" <<'PY2' || { echo "FAIL: schema reader tags"; fail=1; }
import sys, os, yaml
d = sys.argv[1]
assert sorted(os.listdir(d)) == ['assay.schema.yaml', 'deviation.schema.yaml', 'epic.schema.yaml', 'explore.schema.yaml', 'metrics.schema.yaml', 'quiz.schema.yaml', 'review.schema.yaml', 'spec.schema.yaml'], os.listdir(d)
for f in os.listdir(d):
    s = yaml.safe_load(open(os.path.join(d, f)))
    for k, v in s['properties'].items():
        assert v.get('reader') in ('human', 'agent'), f'{f}: {k} has no reader tag'
print('PASS: eight schemas, every top-level field reader-tagged')
PY2

# AC-10 / INV-4: every field in the three new schemas names its consumer file in the
# schema header comment (no field lacks one)
python3 - "$scripts_dir/../skills/_shared/schemas" "$scripts_dir/dossier-render.sh" "$scripts_dir/check-artifact.sh" <<'PY4' || { echo "FAIL: new-schema field consumers"; fail=1; }
import sys, os, yaml
# No field exists without a consumer — asserted against the consumer CODE
# (renderer + checker), never a header comment (comments carry no consumer
# maps under the three-class policy).
d = sys.argv[1]
consumers = open(sys.argv[2], encoding='utf-8').read() + open(sys.argv[3], encoding='utf-8').read()
for f in ('quiz.schema.yaml', 'assay.schema.yaml', 'explore.schema.yaml'):
    s = yaml.safe_load(open(os.path.join(d, f), encoding='utf-8').read())
    for k in s['properties']:
        assert k in consumers, f'{f}: field {k} appears in no consumer source (renderer/checker)'
print('PASS: quiz/assay/explore schemas — every top-level field has a code consumer (AC-10 / INV-4)')
PY4

# AC-26: the resolves declaration is live, not decorative — flip spec.schema.yaml's
# `resolves: self` to `resolves: target` in a scratch copy of the schema tree (mktemp);
# validating the same spec-green.yaml instance under the flipped copy stops resolving
# facts_source.consensus against the file itself (there is no `target` field on a spec
# document) — the ledger warn that was absent before now appears.
python3 - "$ca" "$ax" <<'PY5' || { echo "FAIL: check-artifact AC-26 resolves declaration liveness"; fail=1; }
import sys, os, subprocess, tempfile, shutil
ca, ax = sys.argv[1], sys.argv[2]
scratch = tempfile.mkdtemp()
os.makedirs(os.path.join(scratch, 'scripts'))
os.makedirs(os.path.join(scratch, 'skills', '_shared', 'schemas'))
scratch_ca = os.path.join(scratch, 'scripts', 'check-artifact.sh')
shutil.copy(ca, scratch_ca)
schema_src = os.path.join(os.path.dirname(ca), '..', 'skills', '_shared', 'schemas', 'spec.schema.yaml')
original = open(schema_src, encoding='utf-8').read()
flipped = original.replace('resolves: self', 'resolves: target', 1)
assert flipped != original, "resolves: self not found in spec.schema.yaml"
open(os.path.join(scratch, 'skills', '_shared', 'schemas', 'spec.schema.yaml'), 'w', encoding='utf-8').write(flipped)
before = subprocess.run(['bash', ca, 'spec', os.path.join(ax, 'spec-green.yaml'), '--root', ax], capture_output=True, text=True)
after = subprocess.run(['bash', scratch_ca, 'spec', os.path.join(ax, 'spec-green.yaml'), '--root', ax], capture_output=True, text=True)
assert 'ledger not found' not in before.stdout, before.stdout
assert 'ledger not found' in after.stdout, after.stdout
shutil.rmtree(scratch)
print('PASS: check-artifact.sh resolves declaration is live — flipping a scratch copy changes the resolution target (AC-26)')
PY5

# ---- design-review-precheck.sh: schema floor, draft skip, legacy md block, --attest
pc="$scripts_dir/design-review-precheck.sh"
expect_exit "design-review-precheck.sh green" zero bash "$pc" "$ax/spec-green.yaml"
expect_exit "design-review-precheck.sh red" nonzero bash "$pc" "$ax/spec-red.yaml"
expect_out "design-review-precheck.sh draft skipped" "PRE-CHECK skipped: draft" bash "$pc" "$ax/spec-red-nomap.yaml"
expect_exit "design-review-precheck.sh legacy md blocked" nonzero bash "$pc" "$ax/legacy-spec.md"
qd="$(mktemp -d)"; sed 's/^status: draft/status: "draft"/' "$ax/spec-red-nomap.yaml" > "$qd/q.yaml"
expect_out "design-review-precheck.sh quoted draft skipped" "PRE-CHECK skipped: draft" bash "$pc" "$qd/q.yaml"
rm -rf "$qd"
expect_exit "design-review-precheck.sh --attest green (round-1 review.yaml with challenger)" zero bash "$pc" "$ax/spec-green.yaml" --attest
at="$(mktemp -d)"; cp "$ax/spec-green.yaml" "$ax/ledger.md" "$at/"
expect_exit "design-review-precheck.sh --attest red (no attestation)" nonzero bash "$pc" "$at/spec-green.yaml" --attest
expect_out "design-review-precheck.sh --attest names the missing attestation" "challenge attestation is missing" bash "$pc" "$at/spec-green.yaml" --attest
rm -rf "$at"

# classify_command: source the hook (its source-guard skips main when sourced)
# and probe the function directly on a real commit vs a non-git command.
# shellcheck source=/dev/null
source "$hooks_dir/run-project-checks.sh"

cc_out="$(classify_command 'git commit -m "msg"')"
if [ "$cc_out" = "pre-commit" ]; then
  echo "PASS: run-project-checks.sh classify_command(commit)"
else
  echo "FAIL: run-project-checks.sh classify_command(commit) -> '$cc_out'"; fail=1
fi

cc_out="$(classify_command 'ls -la')"
if [ "$cc_out" = "none" ]; then
  echo "PASS: run-project-checks.sh classify_command(non-git)"
else
  echo "FAIL: run-project-checks.sh classify_command(non-git) -> '$cc_out'"; fail=1
fi

# ---- dossier-render.sh: the fixture epic is copied under a synthetic project
# root (own .touchstone/gate-miss.md + docs/adr) so root discovery, archived
# placement, ADR resolution, and determinism are all exercised offline.
tmp_root="$(mktemp -d)"
mkdir -p "$tmp_root/.touchstone/epics" "$tmp_root/.touchstone/archive/epics" "$tmp_root/docs/adr"
cp -R "$here/fixtures/dossier-epic" "$tmp_root/.touchstone/epics/2026-01-01-fixture"
rm -f "$tmp_root/.touchstone/epics/2026-01-01-fixture/dossier.html"
printf '# gate-miss\n\n- 2026-01-02 | fixture | a miss | assay | human | L\n' > "$tmp_root/.touchstone/gate-miss.md"
printf -- '---\nstatus: Accepted\n---\n\n# ADR-0038 fixture decision\n\nBody.\n' > "$tmp_root/docs/adr/0038-fixture.md"
ed="$tmp_root/.touchstone/epics/2026-01-01-fixture"
dout="$ed/dossier.html"

expect_exit "dossier-render.sh green" zero bash "$scripts_dir/dossier-render.sh" --pr-body "$ed"
expect_exit "dossier-render.sh red (missing path)" nonzero bash "$scripts_dir/dossier-render.sh" "$tmp_root/nope"
expect_exit "dossier-render.sh red (path is a file)" nonzero bash "$scripts_dir/dossier-render.sh" "$dout"
mkdir -p "$tmp_root/noindex"
expect_exit "dossier-render.sh red (no index.md)" nonzero bash "$scripts_dir/dossier-render.sh" "$tmp_root/noindex"
bad="$tmp_root/.touchstone/epics/2026-01-09-badyaml"; mkdir -p "$bad"; cp "$fx/dossier-epic/index.md" "$bad/"; printf 'id: [unclosed\n' > "$bad/2026-01-09-bad.spec.yaml"
expect_out "dossier-render.sh red (malformed spec.yaml is fatal)" "not parseable YAML" bash "$scripts_dir/dossier-render.sh" "$bad"
[ -f "$bad/dossier.html" ] && { echo "FAIL: dossier written for malformed YAML"; fail=1; }
[ -f "$tmp_root/noindex/dossier.html" ] && { echo "FAIL: dossier written on red path"; fail=1; }

# expect_grep <label> <count-op> <n> <pattern>  — fixed-string count over the dossier
expect_grep() {
  label="$1"; op="$2"; n="$3"; pat="$4"
  c="$(grep -o -F -- "$pat" "$dout" | wc -l | tr -d ' ')"
  ok=0
  case "$op" in
    -eq) [ "$c" -eq "$n" ] && ok=1 ;;
    -ge) [ "$c" -ge "$n" ] && ok=1 ;;
  esac
  if [ "$ok" = 1 ]; then echo "PASS: dossier $label"; else echo "FAIL: dossier $label (count=$c, want $op $n): $pat"; fail=1; fi
}
if head -5 "$dout" | grep -q "GENERATED by scripts/dossier-render.sh" && head -5 "$dout" | grep -q "do not hand-edit"; then
  echo "PASS: dossier generated header in first 5 lines"
else
  echo "FAIL: dossier header not in first 5 lines"; fail=1
fi
expect_grep "four tabs in order" -eq 1 '>首頁</button><button data-tab="1" aria-selected="false">契約</button><button data-tab="2" aria-selected="false">結構變化</button><button data-tab="3" aria-selected="false">紀錄</button>'
expect_grep "three phase groups" -ge 3 '<h2>Phase '
expect_grep "front page: blocker list" -ge 1 '<h3>阻擋清單</h3>'
expect_grep "front page: gate strip" -ge 1 'class="strip"'
expect_grep "front page: sticky strip" -ge 1 '<div class="strip">'
expect_grep "explainer inlined (h1 text)" -ge 1 'Alpha buy-in explainer'
expect_grep "no iframe" -eq 0 '<iframe'
expect_grep "phase map rendered as panels" -ge 8 'class="panel"'
expect_grep "panel delta marker from deviation log" -ge 1 '實作≠計畫'
expect_grep "ADR one-liner links to file, not inlined" -ge 1 'href="../../../docs/adr/0038-fixture.md">ADR-0038</a>'
expect_grep "close: retrospective" -ge 1 '>回顧</span>'
expect_grep "close: evidence reckoning" -ge 1 '>證據清算</span>'
expect_grep "close: gate-miss line via ancestor root" -ge 1 'a miss'
expect_grep "AC-2 links to alpha anchor" -ge 1 'data-jump="2026-01-02-alpha-design--AC-2" tabindex="0">AC-2</a>'
expect_grep "REQ-1 links to alpha anchor" -ge 1 'data-jump="2026-01-02-alpha-design--REQ-1" tabindex="0">REQ-1</a>'
expect_grep "AC-2 anchor id exists" -eq 1 'id="2026-01-02-alpha-design--AC-2"'
expect_grep "REQ-1 anchor id exists" -eq 1 'id="2026-01-02-alpha-design--REQ-1"'
expect_grep "AC-99 undefined marker" -ge 1 'class="undef" title="no definition for AC-99'
expect_grep "AC-99 never linked" -eq 0 '>AC-99</a>'
expect_grep "AC-2a undefined (suffixed form)" -ge 1 'class="undef" title="no definition for AC-2a'
expect_grep "beta review resolves AC-1 in-phase" -ge 1 'data-jump="2026-01-03-beta-design--AC-1" tabindex="0">AC-1</a>'
expect_grep "inline code AC-2 untouched" -ge 1 '<code>AC-2</code>'
expect_grep "fenced AC-2 untouched" -ge 1 'fenced AC-2 must stay untouched'
expect_grep "defining heading not self-linked" -eq 0 'id="2026-01-02-alpha-design--AC-2"><a'
expect_grep "ADR-38 links" -ge 1 'data-jump="adr--38" tabindex="0">ADR-38</a>'
expect_grep "ADR-0038 links to same anchor" -ge 1 'data-jump="adr--38" tabindex="0">ADR-0038</a>'
expect_grep "ADR body rendered with anchor" -eq 1 'id="adr--38"'
expect_grep "dark palette present" -ge 1 'prefers-color-scheme: dark'
ext="$(grep -oiE "<(link|script|img|iframe|object|embed)[^>]*(src|href)[[:space:]]*=[[:space:]]*['\"]?https?://|@import[^;]*https?://|url\([^)]*https?://" "$dout" | wc -l | tr -d ' ')"
if [ "$ext" -eq 0 ]; then echo "PASS: dossier no external request targets"; else echo "FAIL: dossier external requests: $ext"; fail=1; fi
# hostile inlined explainer + hostile markdown links are neutralised
expect_grep "hostile: explainer body kept" -ge 1 'Beta explainer'
expect_grep "hostile: no iframe" -eq 0 '<iframe'
expect_grep "hostile: no script" -eq 0 '<script>alert'
expect_grep "hostile: no on* handlers" -eq 0 'onerror='
expect_grep "hostile: no onmouseover" -eq 0 'onmouseover='
expect_grep "hostile: no onclick" -eq 0 'onclick='
expect_grep "hostile: no javascript: href" -eq 0 'javascript:'
expect_grep "hostile: tab-split scheme neutralised" -eq 0 'java	script:'
expect_grep "hostile: nav link kept" -ge 1 'href="https://example.com/doc"'
expect_grep "hostile: markdown link attr-escaped" -eq 0 'href=""onmouseover'
expect_grep "hostile: AC-1 linked inside sanitized html" -ge 1 'data-jump="2026-01-03-beta-design--AC-1" tabindex="0">AC-1</a>'

# ---- yaml-born epic (ADR-0043 REQ-2, AC-6/AC-7): epic.yaml deterministic precedence —
# a dir with epic.yaml and NO index.md renders green, header denominator = len(phases[]),
# owner-readable surface shows only phases[].n (no index-table row count). AC-8 (legacy
# regression) is the dossier-epic block above staying green in this same suite run.
tmp_root2="$(mktemp -d)"
mkdir -p "$tmp_root2/.touchstone/epics"
cp -R "$here/fixtures/dossier-epic-yaml" "$tmp_root2/.touchstone/epics/2026-01-10-fixture-yaml"
eyd="$tmp_root2/.touchstone/epics/2026-01-10-fixture-yaml"
[ -f "$eyd/index.md" ] && { echo "FAIL: index.md present in yaml-born fixture (regression witness invalid)"; fail=1; }
expect_exit "dossier-render.sh yaml-born green (AC-6: epic.yaml, no index.md)" zero bash "$scripts_dir/dossier-render.sh" "$eyd"
eydout="$eyd/dossier.html"
[ -f "$eydout" ] || { echo "FAIL: yaml-born dossier.html not produced (AC-6)"; fail=1; }
distinct_hdr="$(grep -oE '第 [0-9]+/[0-9]+ 階段' "$eydout" | sort -u | tr '\n' ';')"
if [ "$distinct_hdr" = "第 3/6 階段;" ]; then
  echo "PASS: dossier yaml-born header denominator = phases[] count, no row-index leak (AC-7)"
else
  echo "FAIL: dossier yaml-born header mismatch (want 第 3/6 階段;, got '$distinct_hdr')"; fail=1
fi
if grep -q -F 'epic 歷史</span></span> <span class="num">6</span>' "$eydout"; then
  echo "PASS: dossier yaml-born epic-history table has 6 rows (phases[] count)"
else
  echo "FAIL: dossier yaml-born epic-history row count wrong"; fail=1
fi
if grep -q -F '>epic.yaml</span>' "$eydout"; then
  echo "FAIL: epic.yaml rendered as a stray file card (should be excluded from the file walk)"; fail=1
else
  echo "PASS: dossier yaml-born excludes epic.yaml itself from file cards"
fi
expect_grep_e() {
  label="$1"; op="$2"; n="$3"; pat="$4"
  c="$(grep -o -F -- "$pat" "$eydout" | wc -l | tr -d ' ')"
  ok=0
  case "$op" in
    -eq) [ "$c" -eq "$n" ] && ok=1 ;;
    -ge) [ "$c" -ge "$n" ] && ok=1 ;;
  esac
  if [ "$ok" = 1 ]; then echo "PASS: dossier yaml-born $label"; else echo "FAIL: dossier yaml-born $label (count=$c, want $op $n): $pat"; fail=1; fi
}
expect_grep_e "foundation.rulings rendered" -ge 1 'hand-written home; index.md is never authored again.'
expect_grep_e "deviation_log rendered" -ge 1 'which-stage-could-have-caught: assay'
expect_grep_e "reckoning rendered as table" -ge 1 '<th>AC</th><th>Covered by</th><th>live-bearing?</th>'
expect_grep_e "disposition none rendered minimally" -ge 1 '<p>none</p>'

# ---- YAML phase (gamma): projection, overlays, ledger anchors, Ship order, pr-body, INV-1
expect_grep "yaml: gamma phase group" -ge 1 'data-phase="2026-01-04-gamma.spec"'
expect_grep "yaml: four panels + D-1 overlay on the interface panel" -ge 1 '介面差異</abbr> <span class="pill warn"><abbr class="enum" title="built-ne-planned">實作≠計畫</abbr> · 1</span>'
expect_grep "yaml: D-1 entry anchored" -eq 1 'id="deviation--D-1"'
expect_grep "yaml: legacy deviation line under its own heading" -ge 1 '>舊版偏離行</span>'
expect_grep "yaml: review round summary row" -ge 1 '<th>門</th><th>輪</th><th>裁決</th>'
expect_grep "yaml: review finding F-1 anchored" -ge 1 'id="finding--F-1"'
expect_grep "yaml: basis Q-1 links to the ledger line" -ge 1 'data-jump="ledger--Q-1" tabindex="0">Q-1</a>'
expect_grep "yaml: ledger line anchored" -eq 1 'id="ledger--Q-1"'
expect_grep "yaml: ledger table row anchored" -eq 1 'id="ledger--A-1"'
expect_grep "yaml: AC-2 anchored in the requirements table" -eq 1 'id="2026-01-04-gamma.spec--AC-2"'
expect_grep "yaml: INV-1 anchored" -eq 1 'id="2026-01-04-gamma.spec--INV-1"'
expect_grep "yaml: front page lists waiting_on_human from the spec" -ge 1 'rule on the collision rename'
expect_grep "yaml: front page lists waiting_on_human from review.yaml" -ge 1 'accept F-1 as is'
expect_grep "yaml: front page lists waiting_on_human from deviation.yaml" -ge 1 'confirm the equals form stays'
expect_grep "yaml: quiz item rendered" -ge 1 'which panel changed during the build?'
expect_grep "yaml: quiz anchor rendered" -ge 1 '<code>phase_map.interface_delta</code>'
expect_grep "front page: decision line" -ge 1 '<dl class="dec">'
python3 - "$dout" "$ed/pr-body.md" "$ed" <<'PY' || { echo "FAIL: yaml projection checks"; fail=1; }
import re, sys, html as H, yaml, os
h = open(sys.argv[1], encoding='utf-8').read()
front = re.search(r'<section class="tab" id="tab-0">(.*?)<section class="tab" id="tab-1">', h, re.S).group(1)
heads = re.findall(r'<section class="fs"><h3>([^<]*)</h3>', front)
want = ['決策', '阻擋清單', '怎麼驗的', '檢查表']
assert heads == want, heads
pr = open(sys.argv[2], encoding='utf-8').read()
assert [x for x in re.findall(r'^## (.+)$', pr, re.M) if x != 'gate 條'] == want, 'pr-body sections differ from the page order'
assert 'D-1' in pr, 'pr-body lacks the D-1 overlay'
# no whole-file pre block in the YAML phase's sections (Map + Ship + 契約)
for tab_id in ('1', '2'):
    t = re.search(r'<section class="tab" id="tab-%s">(.*?)(?=<section class="tab" id="tab-|</main>)' % tab_id, h, re.S).group(1)
    g = re.search(r'<section class="phase" data-phase="2026-01-04-gamma.spec">(.*?)(?=<section class="phase"|$)', t, re.S)
    assert g and '<pre>' not in g.group(1), 'pre block in gamma tab ' + tab_id
assert '<pre>' not in front, 'pre block on the front page'
# INV-1: every text node in the gamma Map + Ship sections is a YAML field value, an id, a number, or a label
vals = set()
def walk(v):
    if isinstance(v, dict):
        for x in v.values(): walk(x)
    elif isinstance(v, list):
        for x in v: walk(x)
    elif v is not None:
        vals.add(str(v).strip())
ed = sys.argv[3]
for f in ('2026-01-04-gamma.spec.yaml', 'design-review-gamma/review.yaml', 'deviation.yaml', 'quiz.yaml'):
    walk(yaml.safe_load(open(os.path.join(ed, f), encoding='utf-8')))
legacy = [l[2:].strip() for l in open(os.path.join(ed, 'index.md'), encoding='utf-8').read().splitlines() if l.startswith('- phase ')]
checked = 0
for tab_id in ('0', '2'):
    t = re.search(r'<section class="tab" id="tab-%s">(.*?)(?=<section class="tab" id="tab-|</main>)' % tab_id, h, re.S).group(1)
    g = re.search(r'<article class="front">(.*?)</article>', t, re.S).group(1) if tab_id == '0' else re.search(r'<section class="phase" data-phase="2026-01-04-gamma.spec">(.*?)(?=<section class="phase"|$)', t, re.S).group(1)
    g = re.sub(r'<abbr class="enum"[^>]*>.*?</abbr>', '', g, flags=re.S)
    g = re.sub(r'<svg.*?</svg>', '', g, flags=re.S)
    g = re.sub(r'<(span|p|h\d|th)[^>]*class="(label|placeholder|pill [a-z]+|file|muted|footer)"[^>]*>.*?</\1>', '', g, flags=re.S)
    g = re.sub(r'<h2>.*?</h2>|<th>.*?</th>|<h3>[^<]*</h3>|<summary>.*?</summary>', '', g, flags=re.S)
    for node in re.findall(r'>([^<>]+)<', g):
      for n in re.split(r'\s·\s', H.unescape(node)):
        n = n.strip(' ·:—').strip()
        if not n or n in ('·', '—', '(', ')', ',', '·'): continue
        ok = n in vals or re.fullmatch(r'[A-Z]+-\d+|[\d.\s/項]+', n) or all(t in vals for t in n.split()) or n in ('Phases', 'title', '#', '結構變化', '階段') or any(n in v for v in vals) or any(n in l for l in legacy) \
             or n in ('dossier.html', 'pr-body.md', 'Waiting on human', 'Quiz', 'Phase map', 'Legacy deviation lines')
        assert ok, 'renderer-authored text node: %r' % n
        checked += 1
assert checked >= 10, checked
print('PASS: front-page order == pr-body order; no whole-file pre; %d text nodes trace to YAML fields (INV-1)' % checked)
PY

# ---- phase 5: quiz.yaml split (AC-1/AC-3/AC-4/AC-25/AC-27), assay/explore readers
# (AC-9/AC-12), walk exclusion (AC-16), and the four presentation fixes (AC-11/AC-17/
# AC-18/AC-19) — all asserted on the same migrated dossier-epic fixture rendered above.

# AC-25: the migrated fixture is checker-valid — both files exit 0 (warn-only refs unresolved
# across phases with no YAML spec are fine; only errors trip the exit code).
expect_exit "AC-25 check-artifact deviation.yaml (migrated fixture)" zero \
  bash "$scripts_dir/check-artifact.sh" deviation "$fx/dossier-epic/deviation.yaml" --root "$fx/dossier-epic"
expect_exit "AC-25 check-artifact quiz.yaml (migrated fixture)" zero \
  bash "$scripts_dir/check-artifact.sh" quiz "$fx/dossier-epic/quiz.yaml" --root "$fx/dossier-epic"

# AC-1/AC-3: quiz.yaml's per-phase item-id grouping is unchanged from the pre-migration
# deviation.yaml quiz block (QZ-1 phase 3, QZ-2 phase 1, QZ-3 phase 2).
python3 - "$fx/dossier-epic/quiz.yaml" <<'PY' || { echo "FAIL: AC-3 quiz migration regression"; fail=1; }
import yaml, sys
d = yaml.safe_load(open(sys.argv[1], encoding='utf-8'))
by_phase = {}
for it in d.get('items') or []:
    by_phase.setdefault(it['phase'], set()).add(it['id'])
want = {1: {'QZ-2'}, 2: {'QZ-3'}, 3: {'QZ-1'}}
assert by_phase == want, by_phase
print('PASS: AC-3 — quiz.yaml per-phase item-id sets match the pre-migration deviation.yaml grouping')
PY

# AC-4: a phase_summaries entry (phase 1, alpha) appears at both render sites inside its
# phase's 紀錄 card (top of the panel, and again at the top of the quiz section) — additive
# only: QZ-2 (phase 1)'s ref still resolves to a raw-material jump anchor (INV-5).
expect_grep "AC-4 phase_summaries: two render sites (phase panel + quiz section)" -eq 2 \
  'owner-frame: phase 1 shipped the dry-run flag with no acceptance-criteria impact.'
expect_grep "AC-4 additive: QZ-2's ref still resolves to a raw-material anchor" -ge 1 \
  '對回</span> <a class="code" data-jump="2026-01-02-alpha-design--AC-1" tabindex="0">AC-1</a>'

# AC-9: the structured assay-*.yaml record renders per-ledger-id anchors (T-1/A-2/Q-2)
# alongside the legacy assay-notes.md ones (A-1/Q-1); the 建置帳 fold groups its structured
# rulings by stage (build and deliverable-review both included).
expect_grep "AC-9: yaml assay record ledger anchors (T/A/Q)" -eq 1 'id="ledger--T-1"'
expect_grep "AC-9: yaml assay record ledger anchors (T/A/Q)" -eq 1 'id="ledger--A-2"'
expect_grep "AC-9: yaml assay record ledger anchors (T/A/Q)" -eq 1 'id="ledger--Q-2"'
expect_grep "AC-9: legacy md assay record ledger anchors unchanged" -eq 1 'id="ledger--A-1"'
expect_grep "AC-9: legacy md assay record ledger anchors unchanged" -eq 1 'id="ledger--Q-1"'
expect_grep "AC-9: 建置帳 fold carries the yaml record's build-stage ruling" -ge 1 'confirmed during build'
expect_grep "AC-9: 建置帳 fold carries the yaml record's deliverable-review-stage ruling" -ge 1 'yes, reuse confirmed'

# AC-12: an explore-*.yaml renders an exploration card in the 契約 group.
expect_grep "AC-12: exploration card renders in 契約" -ge 1 'confirm the writer module has no hidden readers'

# AC-16: a spec-shaped file nested under a build-*/ scratch dir creates no phase and
# appears in no tab (the walk excludes build-*/, discovery-*/, live/ at the source).
expect_grep "AC-16: nested build- subdir spec creates no phase" -eq 0 '第 99 階段'
expect_grep "AC-16: nested build- subdir spec content absent from every tab" -eq 0 'Should never render'

# AC-27: quiz.yaml routes by exact basename to the structured quiz reader (never a generic
# file card); a legacy file whose basename merely contains "quiz" keeps its Ship classification.
expect_grep "AC-27: quiz.yaml never rendered as a generic file card" -eq 0 'title="檔案 quiz.yaml"'
expect_grep "AC-27: legacy *quiz* file keeps its current (Ship) classification" -ge 1 'Legacy quiz notes'

# AC-17: an AC's given/當/則 segments render as separate list items, not one paragraph.
expect_grep "AC-17: given/when/then render as list items" -ge 1 '<ul class="gwt"><li><span class="label">給定</span>'

# AC-18: the gate pills sit on their own status row, structurally separate from the
# epic/phase decision row, below the title line.
expect_grep "AC-18: gate pills sit on their own row" -ge 1 '<div class="gates-row">'

# AC-19 (structural half): the middle content column no longer carries a fixed narrow max.
expect_grep "AC-19: no fixed 76ch column max" -eq 0 'max-width:76ch'
expect_grep "AC-19: middle column uses the available width" -ge 1 'max-width:min(1200px,94vw)'

# AC-11: a long raw record's fold summary carries a digest (line count), never its prose —
# the lead sentence still appears in the fold BODY (revealed on open), just never inside
# the <summary> the reader sees collapsed.
expect_grep "AC-11: digest fold summary carries a count, not file prose" -ge 1 \
  '<span class="lead"><span class="label">全文</span></span> <span class="num">'
python3 - "$dout" <<'PY' || { echo "FAIL: AC-11 digest fold summary leaks prose"; fail=1; }
import re, sys
h = open(sys.argv[1], encoding='utf-8').read()
for m in re.finditer(r'<summary>(.*?)</summary>', h, re.S):
    assert 'This sentence must never appear inside a fold summary line directly.' not in m.group(1), 'AC-11: long-file lead prose leaked into a <summary>'
print('PASS: AC-11 — long-file lead prose never appears inside a <summary> (fold-body only)')
PY

# zero-delta phase → visible quiz waiver
zd="$tmp_root/.touchstone/epics/2026-01-07-zerodelta"; mkdir -p "$zd"
printf -- '---\nslug: zerodelta\nstatus: active\n---\n\n# Zero delta\n\n**Aim:** x.\n\n## Phases\n\n| # | Title | Spec | Plan | Status | Landed |\n|---|---|---|---|---|---|\n| 1 | Delta | [spec](2026-01-07-delta.spec.yaml) | — | active | |\n' > "$zd/index.md"
sed -e 's/^title: .*/title: Delta — zero deviation/' -e 's/^  record: .*/  record: ledger.md/' "$fx/dossier-epic/2026-01-04-gamma.spec.yaml" > "$zd/2026-01-07-delta.spec.yaml"
cp "$fx/artifacts/ledger.md" "$zd/ledger.md"
printf 'entries: []\nwaiting_on_human: []\n' > "$zd/deviation.yaml"
printf 'waived: true\nitems: []\n' > "$zd/quiz.yaml"
dout="$zd/dossier.html"
expect_exit "dossier-render.sh zero-delta green" zero bash "$scripts_dir/dossier-render.sh" "$zd"
expect_grep "zero-delta: quiz waiver visible" -ge 1 '>理解測驗免作</span>'
expect_grep "zero-delta: every panel as planned" -eq 4 '如計畫</abbr></span>'
md="$tmp_root/.touchstone/epics/2026-01-08-mdonly"; mkdir -p "$md"; printf -- '---\nslug: mdonly\nstatus: active\n---\n\n# Md only\n\n**Aim:** x.\n' > "$md/index.md"
expect_out "dossier-render.sh --pr-body red (no YAML phase)" "needs a YAML phase" bash "$scripts_dir/dossier-render.sh" --pr-body "$md"
dout="$ed/dossier.html"

# not-writable epic dir → exit 1 naming the cause
ro="$tmp_root/.touchstone/epics/2026-01-04-readonly"; mkdir -p "$ro"; cp "$fx/dossier-epic/index.md" "$ro/"; chmod 500 "$ro"
ro_out="$(bash "$scripts_dir/dossier-render.sh" "$ro" 2>&1)"; ro_rc=$?
chmod 700 "$ro"
if [ "$ro_rc" -ne 0 ] && printf '%s' "$ro_out" | grep -q "not writable" && printf '%s' "$ro_out" | grep -q "$ro"; then
  echo "PASS: dossier-render.sh red (not writable)"
else
  echo "FAIL: dossier-render.sh red (not writable) rc=$ro_rc: $ro_out"; fail=1
fi

# classification branches, close sections, code links inside inlined html
python3 - "$dout" <<'PY' || { echo "FAIL: dossier classification / close / inlined-html checks"; fail=1; }
import re,sys
h=open(sys.argv[1],encoding='utf-8').read()
chunks=re.split(r'<section class="tab" id="tab-(\d)">',h)[1:]
t={chunks[i]:chunks[i+1] for i in range(0,len(chunks),2)}
def files_in(i): return set(re.findall(r'<span class="file"[^>]*>([^<]+)</span>',t[i]))
assert {'assay-notes.md','local-decision.md','stray.md','2026-01-02-alpha-design.md','2026-01-03-beta-design.md'} <= files_in('1'), files_in('1')
assert {'evidence.md','task-01.md','build-plan.md','anvil-review-2026-01-02/review.md'} <= files_in('3'), files_in('3')
assert 'flag instead of header' in t['3'], 'deviation-log.md bullet not merged into 紀錄'
epic_chunk=t['1'].split('data-phase="epic"')[1] if 'data-phase="epic"' in t['1'] else ''
assert 'stray.md' in epic_chunk, 'stray.md not in 契約 epic group'
allf=set().union(*[files_in(i) for i in t])
for f in ['assay-notes.md','local-decision.md','evidence.md','task-01.md','build-plan.md','stray.md','2026-01-02-alpha-buyin.html']:
    assert f in allf, f+' absent from page'
assert 'Body.' not in t['1'], 'ADR body inlined into 契約 (should be a one-liner)'
for s in ['回顧','證據清算','處置']:
    assert f'>{s}</span>' in t['3'], s+' missing from 紀錄'
    assert f'>{s}</span>' not in t['0'], s+' leaked into 首頁'
embs=re.findall(r'<div class="embedded">(.*?)</div>',t['3'],re.S)
assert any('data-jump="2026-01-02-alpha-design--AC-1" tabindex="0">AC-1</a>' in e for e in embs), 'AC-1 not linked inside inlined explainer'
print('PASS: dossier classification branches / close sections / inlined-html code links')
PY

# no project root → visible note, exit 0
noroot="$(mktemp -d)"
cp -R "$fx/dossier-epic" "$noroot/ep"; rm -f "$noroot/ep/dossier.html"
expect_exit "dossier-render.sh no-root green" zero bash "$scripts_dir/dossier-render.sh" "$noroot/ep"
if grep -q 'No project root' "$noroot/ep/dossier.html"; then echo "PASS: dossier no-root note visible"; else echo "FAIL: dossier no-root note missing"; fail=1; fi
rm -rf "$noroot"

# --root override wins over the ancestor walk
expect_exit "dossier-render.sh --root green" zero bash "$scripts_dir/dossier-render.sh" --root "$tmp_root" "$ed"
expect_exit "dossier-render.sh --root red (not a dir)" nonzero bash "$scripts_dir/dossier-render.sh" --root "$tmp_root/nope" "$ed"

# determinism
cp "$dout" "$tmp_root/first.html"
bash "$scripts_dir/dossier-render.sh" "$ed" >/dev/null
if cmp -s "$dout" "$tmp_root/first.html"; then echo "PASS: dossier deterministic"; else echo "FAIL: dossier output differs between runs"; fail=1; fi

# archived placement resolves the same root
mv "$ed" "$tmp_root/.touchstone/archive/epics/2026-01-01-fixture"
ed2="$tmp_root/.touchstone/archive/epics/2026-01-01-fixture"
bash "$scripts_dir/dossier-render.sh" "$ed2" >/dev/null
if grep -q 'a miss' "$ed2/dossier.html"; then echo "PASS: dossier archived epic resolves root"; else echo "FAIL: archived epic lost gate-miss"; fail=1; fi

# index-only epic
mkdir -p "$tmp_root/.touchstone/epics/2026-01-05-lone"
printf -- '---\nslug: lone\nstatus: proposed\n---\n\n# Lone\n\n**Aim:** nothing.\n' > "$tmp_root/.touchstone/epics/2026-01-05-lone/index.md"
dout="$tmp_root/.touchstone/epics/2026-01-05-lone/dossier.html"
expect_exit "dossier-render.sh index-only green" zero bash "$scripts_dir/dossier-render.sh" "$tmp_root/.touchstone/epics/2026-01-05-lone"
expect_grep "index-only: four tabs" -eq 4 'class="tab"'
expect_grep "index-only: map placeholder" -ge 1 'no phase map in this epic'

# spec without a phase map + same-date specs grouped by slug
sd="$tmp_root/.touchstone/epics/2026-01-06-samedate"
mkdir -p "$sd/anvil-review-gamma"
printf -- '---\nslug: samedate\nstatus: active\n---\n\n# Samedate\n\n**Aim:** x.\n\n## Phases\n\n| # | Title | Spec | Plan | Status | Landed |\n|---|---|---|---|---|---|\n| 1 | Beta | [spec](2026-01-03-beta-design.md) | — | active | |\n| 2 | Gamma | [spec](2026-01-03-gamma-design.md) | — | active | |\n' > "$sd/index.md"
printf -- '---\ntype: spec\n---\n\n# Beta\n\n## Acceptance Criteria\n\n#### AC-1 — b\n' > "$sd/2026-01-03-beta-design.md"
printf -- '---\ntype: spec\n---\n\n# Gamma\n\n## Acceptance Criteria\n\n#### AC-1 — g\n' > "$sd/2026-01-03-gamma-design.md"
printf '# Review gamma\n\nAC-1 holds.\n' > "$sd/anvil-review-gamma/review.md"
printf '# Notes\n\nundated-by-slug, dated only.\n' > "$sd/2026-01-03-notes.md"
dout="$sd/dossier.html"
expect_exit "dossier-render.sh same-date green" zero bash "$scripts_dir/dossier-render.sh" "$sd"
expect_grep "no-phase-map placeholder per spec" -ge 2 'no phase map in this spec'
expect_grep "gamma review resolves gamma AC-1" -ge 1 'data-jump="2026-01-03-gamma-design--AC-1" tabindex="0">AC-1</a>'
python3 - "$dout" <<'PY' || { echo "FAIL: same-date grouping"; fail=1; }
import re,sys
h=open(sys.argv[1],encoding='utf-8').read()
parts=re.split(r'<section class="phase" data-phase="([^"]+)">',h)[1:]
groups={}
for i in range(0,len(parts),2): groups.setdefault(parts[i],'');groups[parts[i]]+=parts[i+1]
assert 'anvil-review-gamma/review.md' in groups.get('2026-01-03-gamma-design',''), 'gamma review not in gamma group'
assert '2026-01-03-notes.md' in groups.get('epic',''), 'date-only file not in epic group'
print('PASS: dossier same-date grouping by slug; date-only file in epic group')
PY

rm -rf "$tmp_root"

# ---- render-on-write.sh (shipped hook):
# hooks/render-on-write.sh: the shipped PostToolUse re-render hook, against
# scratch project roots. Payload shapes fed (steering, anvil duty 2): a
# non-yaml write; a yaml write outside any epics dir; a yaml under an epic
# (A vs B isolation); a yaml nested under an epic sub/dir; a relative
# file_path resolved via payload cwd; empty stdin; stdin that is not JSON; a
# .yaml naming an epic dir that does not exist on disk; a traversal payload
# (`epics/../../x.yaml`) against a stub renderer + a control fire that proves
# the stub is reachable; a custom `workspace_root` in touchstone.yaml; the
# epic archive mirror (W/archive/epics/<epic>/); a malformed *.spec.yaml
# (AC-34); a PATH with no python3 (AC-49); and a 100-invocation timing loop
# on a non-epic path (AC-35). AC-32/AC-36 are asserted directly against the
# shipped hooks.json / waivers.yaml / plugin-map.sh output.
if command -v jq >/dev/null 2>&1; then
  ro_hook="$hooks_dir/render-on-write.sh"
  ro_repo_root="$(cd "$hooks_dir/.." && pwd)"

  # <label> <scratch-root> <written-file-path> [<cwd-override>]
  ro_fire() {
    local label="$1" root="$2" fp="$3" cwd out rc
    cwd="${4:-$root}"
    out="$(jq -nc --arg fp "$fp" --arg cwd "$cwd" '{tool_input:{file_path:$fp}, cwd:$cwd}' \
      | CLAUDE_PROJECT_DIR="$root" bash "$root/hooks/render-on-write.sh" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then echo "PASS: render-on-write $label (exit 0)"
    else echo "FAIL: render-on-write $label (rc=$rc): $out"; fail=1; fi
  }

  # ---- scratch A/B project: two epics, real renderer at the scratch's own
  # plugin root ($ro_root/scripts, $ro_root/hooks — decision 4: the renderer
  # resolves relative to the hook's OWN directory, never <root>/scripts/).
  ro_root="$(mktemp -d)"
  mkdir -p "$ro_root/.touchstone/epics" "$ro_root/scripts" "$ro_root/hooks"
  cp -R "$fx/dossier-epic" "$ro_root/.touchstone/epics/2026-02-01-alpha"
  cp -R "$fx/dossier-epic" "$ro_root/.touchstone/epics/2026-02-02-beta"
  rm -f "$ro_root/.touchstone/epics/2026-02-01-alpha/dossier.html" \
        "$ro_root/.touchstone/epics/2026-02-02-beta/dossier.html"
  cp "$scripts_dir/dossier-render.sh" "$ro_root/scripts/dossier-render.sh"
  cp "$ro_hook" "$ro_root/hooks/render-on-write.sh"
  ro_a="$ro_root/.touchstone/epics/2026-02-01-alpha/dossier.html"
  ro_b="$ro_root/.touchstone/epics/2026-02-02-beta/dossier.html"

  ro_fire "non-yaml write" "$ro_root" "$ro_root/.touchstone/epics/2026-02-01-alpha/index.md"
  if [ ! -f "$ro_a" ] && [ ! -f "$ro_b" ]; then
    echo "PASS: render-on-write non-yaml renders nothing"
  else echo "FAIL: render-on-write non-yaml rendered a dossier"; fail=1; fi

  ro_fire "yaml under epic A" "$ro_root" "$ro_root/.touchstone/epics/2026-02-01-alpha/2026-01-04-gamma.spec.yaml"
  if [ -f "$ro_a" ] && [ ! -f "$ro_b" ]; then
    echo "PASS: render-on-write renders A's dossier and leaves B untouched"
  else echo "FAIL: render-on-write A=$([ -f "$ro_a" ] && echo yes || echo no) B=$([ -f "$ro_b" ] && echo yes || echo no)"; fail=1; fi

  # nested subdir under epic A still resolves to A (epic = first path
  # component below "epics/", regardless of depth)
  mkdir -p "$ro_root/.touchstone/epics/2026-02-01-alpha/sub/dir"
  rm -f "$ro_a"
  ro_fire "yaml nested under epic A/sub/dir" "$ro_root" "$ro_root/.touchstone/epics/2026-02-01-alpha/sub/dir/x.yaml"
  if [ -f "$ro_a" ]; then echo "PASS: render-on-write nested path resolves epic A"
  else echo "FAIL: render-on-write nested path did not render A"; fail=1; fi

  # relative file_path, resolved via payload cwd (not the hook's own cwd)
  rm -f "$ro_a"
  ro_fire "relative file_path via cwd" "$ro_root" ".touchstone/epics/2026-02-01-alpha/2026-01-04-gamma.spec.yaml" "$ro_root"
  if [ -f "$ro_a" ]; then echo "PASS: render-on-write relative file_path resolves via cwd"
  else echo "FAIL: render-on-write relative file_path did not render"; fail=1; fi

  # yaml outside any epics dir -> silent no-op, no dossier
  rm -f "$ro_a"
  mkdir -p "$ro_root/outside"
  ro_out_noise="$(jq -nc --arg fp "$ro_root/outside/x.yaml" --arg cwd "$ro_root" '{tool_input:{file_path:$fp}, cwd:$cwd}' \
    | CLAUDE_PROJECT_DIR="$ro_root" bash "$ro_root/hooks/render-on-write.sh" 2>&1)"; ro_out_rc=$?
  if [ "$ro_out_rc" -eq 0 ] && [ -z "$ro_out_noise" ]; then
    echo "PASS: render-on-write yaml outside epics dir is a silent no-op"
  else echo "FAIL: render-on-write yaml outside epics dir rc=$ro_out_rc out=$ro_out_noise"; fail=1; fi

  # empty stdin -> silent no-op
  ro_empty_out="$(printf '' | CLAUDE_PROJECT_DIR="$ro_root" bash "$ro_root/hooks/render-on-write.sh" 2>&1)"; ro_empty_rc=$?
  if [ "$ro_empty_rc" -eq 0 ] && [ -z "$ro_empty_out" ]; then
    echo "PASS: render-on-write empty stdin is a silent no-op"
  else echo "FAIL: render-on-write empty stdin rc=$ro_empty_rc out=$ro_empty_out"; fail=1; fi

  # stdin that is not JSON -> silent no-op (jq's own failure is swallowed)
  ro_badjson_out="$(printf 'not json at all' | CLAUDE_PROJECT_DIR="$ro_root" bash "$ro_root/hooks/render-on-write.sh" 2>&1)"; ro_badjson_rc=$?
  if [ "$ro_badjson_rc" -eq 0 ] && [ -z "$ro_badjson_out" ]; then
    echo "PASS: render-on-write non-JSON stdin is a silent no-op"
  else echo "FAIL: render-on-write non-JSON stdin rc=$ro_badjson_rc out=$ro_badjson_out"; fail=1; fi

  # a .yaml naming an epic dir that does not exist on disk -> silent no-op
  ro_missing_out="$(jq -nc --arg fp "$ro_root/.touchstone/epics/2099-01-01-ghost/x.yaml" --arg cwd "$ro_root" '{tool_input:{file_path:$fp}, cwd:$cwd}' \
    | CLAUDE_PROJECT_DIR="$ro_root" bash "$ro_root/hooks/render-on-write.sh" 2>&1)"; ro_missing_rc=$?
  if [ "$ro_missing_rc" -eq 0 ] && [ -z "$ro_missing_out" ]; then
    echo "PASS: render-on-write missing epic dir is a silent no-op"
  else echo "FAIL: render-on-write missing epic dir rc=$ro_missing_rc out=$ro_missing_out"; fail=1; fi

  # Traversal: swap in a stub renderer at the scratch's own scripts/ dir that
  # leaves a marker when invoked — the real renderer also fails on
  # `epics/..` (no index.md), so "no dossier appeared" would pass with or
  # without the path guard. The guard is proven only by the renderer never
  # being called, and by the hook printing nothing.
  printf '#!/usr/bin/env bash\ntouch "%s/RENDERER-INVOKED"\nexit 0\n' "$ro_root" > "$ro_root/scripts/dossier-render.sh"
  ro_trav_out="$(jq -nc --arg fp "$ro_root/.touchstone/epics/../../x.yaml" --arg cwd "$ro_root" \
    '{tool_input:{file_path:$fp}, cwd:$cwd}' | CLAUDE_PROJECT_DIR="$ro_root" bash "$ro_root/hooks/render-on-write.sh" 2>&1)"; ro_trav_rc=$?
  if [ "$ro_trav_rc" -eq 0 ] && [ -z "$ro_trav_out" ] && [ ! -e "$ro_root/RENDERER-INVOKED" ]; then
    echo "PASS: render-on-write traversal payload never invokes the renderer (exit 0, silent)"
  else echo "FAIL: render-on-write traversal payload rc=$ro_trav_rc invoked=$([ -e "$ro_root/RENDERER-INVOKED" ] && echo yes || echo no) out=$ro_trav_out"; fail=1; fi
  # control: the stub IS invoked for a legitimate yaml write
  jq -nc --arg fp "$ro_root/.touchstone/epics/2026-02-02-beta/deviation.yaml" --arg cwd "$ro_root" \
    '{tool_input:{file_path:$fp}, cwd:$cwd}' | CLAUDE_PROJECT_DIR="$ro_root" bash "$ro_root/hooks/render-on-write.sh" >/dev/null 2>&1
  if [ -e "$ro_root/RENDERER-INVOKED" ]; then echo "PASS: render-on-write control: stub renderer invoked for a real epic yaml"
  else echo "FAIL: render-on-write control: stub renderer never invoked"; fail=1; fi

  rm -rf "$ro_root"

  # ---- custom workspace_root: touchstone.yaml sets workspace_root: ws
  ro_root2="$(mktemp -d)"
  mkdir -p "$ro_root2/ws/epics" "$ro_root2/scripts" "$ro_root2/.claude" "$ro_root2/hooks"
  cp -R "$fx/dossier-epic" "$ro_root2/ws/epics/2026-03-01-cust"
  rm -f "$ro_root2/ws/epics/2026-03-01-cust/dossier.html"
  cp "$scripts_dir/dossier-render.sh" "$ro_root2/scripts/dossier-render.sh"
  cp "$ro_hook" "$ro_root2/hooks/render-on-write.sh"
  printf 'workspace_root: ws\n' > "$ro_root2/.claude/touchstone.yaml"
  ro_c="$ro_root2/ws/epics/2026-03-01-cust/dossier.html"
  ro_fire "custom workspace_root" "$ro_root2" "$ro_root2/ws/epics/2026-03-01-cust/2026-01-04-gamma.spec.yaml"
  if [ -f "$ro_c" ]; then echo "PASS: render-on-write custom workspace_root renders under ws/epics"
  else echo "FAIL: render-on-write custom workspace_root did not render"; fail=1; fi
  rm -rf "$ro_root2"

  # ---- archive mirror: W/archive/epics/<epic>/ — the epic archive shared
  # with dossier-render.sh, NOT config-resolver's bundle.archive = W/archive/specs
  ro_root3="$(mktemp -d)"
  mkdir -p "$ro_root3/.touchstone/archive/epics" "$ro_root3/scripts" "$ro_root3/hooks"
  cp -R "$fx/dossier-epic" "$ro_root3/.touchstone/archive/epics/2026-01-01-old"
  rm -f "$ro_root3/.touchstone/archive/epics/2026-01-01-old/dossier.html"
  cp "$scripts_dir/dossier-render.sh" "$ro_root3/scripts/dossier-render.sh"
  cp "$ro_hook" "$ro_root3/hooks/render-on-write.sh"
  ro_d="$ro_root3/.touchstone/archive/epics/2026-01-01-old/dossier.html"
  ro_fire "archive epic path" "$ro_root3" "$ro_root3/.touchstone/archive/epics/2026-01-01-old/2026-01-04-gamma.spec.yaml"
  if [ -f "$ro_d" ]; then echo "PASS: render-on-write renders the archived epic and only it"
  else echo "FAIL: render-on-write archive epic path did not render"; fail=1; fi
  rm -rf "$ro_root3"

  # ---- AC-34: a malformed *.spec.yaml written beside an already-rendered
  # dossier -> exactly one 'dossier-render failed: ' line, exit 0, the
  # previous dossier.html byte-identical.
  ro_root4="$(mktemp -d)"
  mkdir -p "$ro_root4/.touchstone/epics" "$ro_root4/scripts" "$ro_root4/hooks"
  cp -R "$fx/dossier-epic" "$ro_root4/.touchstone/epics/2026-02-05-fail"
  cp "$scripts_dir/dossier-render.sh" "$ro_root4/scripts/dossier-render.sh"
  cp "$ro_hook" "$ro_root4/hooks/render-on-write.sh"
  ro_e="$ro_root4/.touchstone/epics/2026-02-05-fail/dossier.html"
  jq -nc --arg fp "$ro_root4/.touchstone/epics/2026-02-05-fail/2026-01-04-gamma.spec.yaml" --arg cwd "$ro_root4" \
    '{tool_input:{file_path:$fp}, cwd:$cwd}' | CLAUDE_PROJECT_DIR="$ro_root4" bash "$ro_root4/hooks/render-on-write.sh" >/dev/null 2>&1
  if [ -f "$ro_e" ]; then
    ro_e_before="$(cat "$ro_e")"
    printf 'id: [unclosed\n' > "$ro_root4/.touchstone/epics/2026-02-05-fail/2026-02-05-bad.spec.yaml"
    ro_ac34_out="$(jq -nc --arg fp "$ro_root4/.touchstone/epics/2026-02-05-fail/2026-02-05-bad.spec.yaml" --arg cwd "$ro_root4" \
      '{tool_input:{file_path:$fp}, cwd:$cwd}' | CLAUDE_PROJECT_DIR="$ro_root4" bash "$ro_root4/hooks/render-on-write.sh" 2>&1)"; ro_ac34_rc=$?
    ro_ac34_lines="$(printf '%s\n' "$ro_ac34_out" | wc -l | tr -d ' ')"
    ro_e_after="$(cat "$ro_e")"
    if [ "$ro_ac34_rc" -eq 0 ] && [ "$ro_ac34_lines" -eq 1 ] \
       && printf '%s' "$ro_ac34_out" | grep -qE '^\{"systemMessage":"dossier-render failed: ' \
       && [ "$ro_e_before" = "$ro_e_after" ]; then
      echo "PASS: render-on-write AC-34 malformed yaml: one line, exit 0, previous dossier byte-identical"
    else
      echo "FAIL: render-on-write AC-34 rc=$ro_ac34_rc lines=$ro_ac34_lines out=$ro_ac34_out changed=$([ "$ro_e_before" = "$ro_e_after" ] && echo no || echo yes)"; fail=1
    fi
  else
    echo "FAIL: render-on-write AC-34 setup: initial dossier never rendered"; fail=1
  fi
  rm -rf "$ro_root4"

  # ---- AC-49: PATH with no python3 -> exactly one skip line, exit 0, no dossier
  ro_root5="$(mktemp -d)"
  mkdir -p "$ro_root5/.touchstone/epics" "$ro_root5/scripts" "$ro_root5/hooks"
  cp -R "$fx/dossier-epic" "$ro_root5/.touchstone/epics/2026-02-06-nopy"
  rm -f "$ro_root5/.touchstone/epics/2026-02-06-nopy/dossier.html"
  cp "$scripts_dir/dossier-render.sh" "$ro_root5/scripts/dossier-render.sh"
  cp "$ro_hook" "$ro_root5/hooks/render-on-write.sh"
  ro_nopy_dir="$(mktemp -d)"
  for ro_tool in bash jq git dirname cat sed grep basename head printf mktemp env; do
    ro_tp="$(command -v "$ro_tool" 2>/dev/null || true)"
    [ -n "$ro_tp" ] && ln -sf "$ro_tp" "$ro_nopy_dir/$ro_tool"
  done
  ro_ac49_out="$(jq -nc --arg fp "$ro_root5/.touchstone/epics/2026-02-06-nopy/2026-01-04-gamma.spec.yaml" --arg cwd "$ro_root5" \
    '{tool_input:{file_path:$fp}, cwd:$cwd}' | CLAUDE_PROJECT_DIR="$ro_root5" PATH="$ro_nopy_dir" bash "$ro_root5/hooks/render-on-write.sh" 2>&1)"; ro_ac49_rc=$?
  if [ "$ro_ac49_rc" -eq 0 ] \
     && [ "$ro_ac49_out" = '{"systemMessage":"dossier-render skipped: python3 not found"}' ] \
     && [ ! -f "$ro_root5/.touchstone/epics/2026-02-06-nopy/dossier.html" ]; then
    echo "PASS: render-on-write AC-49 no python3: exactly one skip line, exit 0, no dossier"
  else
    echo "FAIL: render-on-write AC-49 rc=$ro_ac49_rc out=$ro_ac49_out"; fail=1
  fi
  rm -rf "$ro_root5" "$ro_nopy_dir"

  # ---- AC-35: 100 sequential invocations on a non-epic path; mean
  # wall-clock per invocation <= 50ms (proxy for median — a tight,
  # low-variance loop of cheap subprocess calls has no long tail to separate
  # from the median; stated here as the PASS/FAIL line documents).
  ro_root6="$(mktemp -d)"
  mkdir -p "$ro_root6/.touchstone/epics" "$ro_root6/scripts" "$ro_root6/hooks" "$ro_root6/outside"
  cp "$scripts_dir/dossier-render.sh" "$ro_root6/scripts/dossier-render.sh"
  cp "$ro_hook" "$ro_root6/hooks/render-on-write.sh"
  ro_payload="$(jq -nc --arg fp "$ro_root6/outside/x.yaml" --arg cwd "$ro_root6" '{tool_input:{file_path:$fp}, cwd:$cwd}')"
  if command -v python3 >/dev/null 2>&1; then
    ro_t0="$(python3 -c 'import time; print(time.time())')"
    ro_i=0
    ro_ac35_bad=0
    while [ "$ro_i" -lt 100 ]; do
      if ! printf '%s' "$ro_payload" | CLAUDE_PROJECT_DIR="$ro_root6" bash "$ro_root6/hooks/render-on-write.sh" >/dev/null 2>&1; then
        ro_ac35_bad=$((ro_ac35_bad+1))
      fi
      ro_i=$((ro_i+1))
    done
    ro_t1="$(python3 -c 'import time; print(time.time())')"
    ro_mean_ms="$(python3 -c "print('%.2f' % ((${ro_t1}-${ro_t0})*1000/100))")"
    ro_within="$(python3 -c "print(1 if (${ro_t1}-${ro_t0})*1000/100 <= 50.0 else 0)")"
    if [ "$ro_within" = "1" ] && [ "$ro_ac35_bad" -eq 0 ]; then
      echo "PASS: render-on-write AC-35 timing: mean ${ro_mean_ms}ms/invocation over 100 runs (median proxy), all exit 0"
    else
      echo "FAIL: render-on-write AC-35 timing: mean ${ro_mean_ms}ms/invocation (want <=50ms), nonzero-exit-count=$ro_ac35_bad"; fail=1
    fi
  else
    echo "FAIL: render-on-write AC-35 skipped — python3 not found for timing"; fail=1
  fi
  rm -rf "$ro_root6"

  # ---- AC-32: hooks.json contract + old standalone path gone + waiver removed
  if jq -e '.hooks.PostToolUse[] | select(.matcher=="Write|Edit") | .hooks[] | select(.command=="${CLAUDE_PLUGIN_ROOT}/hooks/render-on-write.sh")' \
      "$hooks_dir/hooks.json" >/dev/null 2>&1; then
    echo "PASS: render-on-write hooks.json carries the contract hook-entry"
  else echo "FAIL: render-on-write hooks.json missing the contract hook-entry"; fail=1; fi

  if [ ! -e "$ro_repo_root/.touchstone/checker/standalone/render-on-write.sh" ]; then
    echo "PASS: render-on-write old standalone path no longer exists"
  else echo "FAIL: render-on-write old standalone path still exists"; fail=1; fi

  ro_waiver_count="$(grep -c 'render-on-write.sh' "$ro_repo_root/.touchstone/checker/waivers.yaml" 2>/dev/null)"
  ro_waiver_count="${ro_waiver_count:-0}"
  if [ "$ro_waiver_count" -eq 0 ]; then
    echo "PASS: render-on-write waivers.yaml no longer names render-on-write.sh"
  else echo "FAIL: render-on-write waivers.yaml still names render-on-write.sh ($ro_waiver_count line(s))"; fail=1; fi

  # ---- AC-36: plugin-map.sh reachability — reached from hooks.json, not an
  # orphan, no waiver (stale or invalid) names it.
  ro_map_json="$(bash "$scripts_dir/plugin-map.sh" 2>&1)"; ro_map_rc=$?
  if [ "$ro_map_rc" -eq 0 ]; then
    ro_map_check="$(printf '%s' "$ro_map_json" | python3 -c '
import json, sys
d = json.load(sys.stdin)
node = "hooks/render-on-write.sh"
orphan = node in d.get("orphans", [])
waived = node in d.get("stale_waivers", []) or node in d.get("invalid_waivers", [])
reached = any(e["from"] == "hooks/hooks.json" and e["to"] == node for e in d.get("edges", []))
print("ok" if (reached and not orphan and not waived) else "bad:reached=%s,orphan=%s,waived=%s" % (reached, orphan, waived))
')"
    if [ "$ro_map_check" = "ok" ]; then
      echo "PASS: render-on-write reached from hooks.json, not an orphan, no waiver names it"
    else
      echo "FAIL: render-on-write plugin-map check: $ro_map_check"; fail=1
    fi
  else
    echo "FAIL: render-on-write plugin-map.sh exit $ro_map_rc: $ro_map_json"; fail=1
  fi
else
  echo "FAIL: render-on-write block skipped — jq not found"; fail=1
fi

# ---- generic checker rail loop (REQ-6/AC-26/AC-27): every
# .touchstone/checker/fixtures/<name>/ tree gets a green PASS (must not trip)
# and a red PASS (must trip); a single-file fixture (no green*/red* subdirs) runs the
# checker's own --self-test instead. "Trip" = nonzero exit, or — for a
# WARN-ONLY checker (header carries the literal WARN-ONLY, always exit 0) —
# stdout/stderr contains WARN. A fixture with no matching checker, or a
# layout the loop can't map, is a FAIL line, never a silent skip.
repo_root="$(cd "$scripts_dir/.." && pwd)"
fixtures_root="$repo_root/.touchstone/checker/fixtures"

# ---- plugin-map.sh's own self-test: it runs the map over the same fixture
# trees the rail owns and asserts the graph / entries / metrics contract.
expect_exit "plugin-map.sh --self-test" zero bash "$scripts_dir/plugin-map.sh" --self-test
# ---- phase-metrics.sh's own self-test (the phase-4 instrument: turns / gap-excluded hours /
# dispatches from a synthetic transcript; lens_h joined by the review's target-spec phase)
expect_exit "phase-metrics.sh --self-test" zero bash "$scripts_dir/phase-metrics.sh" --self-test
# ---- assemble-arm-task.sh's own self-test (the lens-file > inline > built-in
# role-prompt precedence assertion; the script lives outside the checker stage
# dirs so the rail loop never reaches it)
expect_exit "assemble-arm-task.sh --self-test" zero bash "$scripts_dir/assemble-arm-task.sh" --self-test
# a failing subject producer must exit non-zero and leave no files behind — the
# silent-empty-subject fail-open the phase-7 review caught live
asm_dir="$(mktemp -d)"
expect_exit "assembler: failing --subject-cmd exits non-zero (no silent empty subject)" nonzero bash "$scripts_dir/assemble-arm-task.sh" --arm t --round-dir "$asm_dir" --lens quality --subject-cmd "exit 7"
expect_exit "assembler: failing subject leaves no partial files" nonzero ls "$asm_dir/lens-t.md"
# the assembled quality lens must actually carry the reviewer-role content — a
# well-formed but semantically hollow lens is the recorded regression shape
expect_exit "assembler: quality lens assembles" zero bash "$scripts_dir/assemble-arm-task.sh" --arm t --round-dir "$asm_dir" --lens quality --subject-cmd "echo x"
expect_exit "assembler: quality lens carries the reviewer role (not hollow)" zero grep -q "independent code reviewer" "$asm_dir/lens-t.md"
rm -rf "$asm_dir"

find_checker() {  # <name> -> absolute path on stdout, or nothing
  local name="$1" d p
  for d in "$repo_root/.touchstone/checker/pre-commit" "$repo_root/.touchstone/checker/pre-push" "$repo_root/.touchstone/checker/standalone"; do
    p="$d/check-$name.sh"
    [ -f "$p" ] && { printf '%s\n' "$p"; return 0; }
  done
  p="$(find "$repo_root/skills" -name "check-$name.sh" 2>/dev/null | head -1)"
  [ -n "$p" ] && printf '%s\n' "$p"
}

# run_rail_checker <name> <root-dir> <checker-path> -- sets rail_out, rail_rc.
# Per-checker env mirrors that checker's own --self-test block (only
# prose-budget needs one today: PROSE_FILE_BUDGET/PROSE_TOTAL_BUDGET).
run_rail_checker() {
  case "$1" in
    prose-budget)
      rail_out="$(PROSE_FILE_BUDGET=5 PROSE_TOTAL_BUDGET=10 TOUCHSTONE_CHECK_ROOT="$2" bash "$3" 2>&1)"; rail_rc=$? ;;
    *)
      rail_out="$(TOUCHSTONE_CHECK_ROOT="$2" bash "$3" 2>&1)"; rail_rc=$? ;;
  esac
}

shopt -s nullglob
for fxd in "$fixtures_root"/*/; do
  name="$(basename "$fxd")"
  checker="$(find_checker "$name")"
  if [ -z "$checker" ]; then
    echo "FAIL: rail $name (no check-$name.sh under checker stage dirs or skills/**)"; fail=1
    continue
  fi
  warn_only=0; grep -q 'WARN-ONLY' "$checker" && warn_only=1

  subdirs=("$fxd"*/)
  if [ "${#subdirs[@]}" -eq 0 ]; then
    # single-file fixture (a fixtures/<name>/ dir with no green*/red* subdirs)
    if grep -q -- '--self-test' "$checker"; then
      rail_out="$(bash "$checker" --self-test 2>&1)"; rail_rc=$?
      if [ "$rail_rc" -eq 0 ]; then
        echo "PASS: rail $name self-test"
      else
        echo "FAIL: rail $name self-test (rc=$rail_rc)"; echo "$rail_out"; fail=1
      fi
    else
      echo "FAIL: rail $name (single-file fixture, but $checker has no --self-test)"; fail=1
    fi
    continue
  fi

  for sub in "${subdirs[@]}"; do
    subname="$(basename "$sub")"
    case "$subname" in
      green*) want=notrip ;;
      red*) want=trip ;;
      *) echo "FAIL: rail $name $subname (fixture dir name must start with green or red)"; fail=1; continue ;;
    esac
    run_rail_checker "$name" "$sub" "$checker"
    tripped=0
    if [ "$warn_only" -eq 1 ]; then
      printf '%s' "$rail_out" | grep -q 'WARN' && tripped=1
    else
      [ "$rail_rc" -ne 0 ] && tripped=1
    fi
    ok=0
    [ "$want" = trip ]   && [ "$tripped" -eq 1 ] && ok=1
    [ "$want" = notrip ] && [ "$tripped" -eq 0 ] && ok=1
    if [ "$ok" -eq 1 ]; then
      echo "PASS: rail $name $subname"
    else
      echo "FAIL: rail $name $subname (tripped=$tripped want=$want rc=$rail_rc)"; echo "$rail_out"; fail=1
    fi
  done
done
shopt -u nullglob

# ---- invoke --self-test on every script that defines one. The glob is `*.sh`,
# not `check-*.sh`: a standalone tool under the same stage dirs carries a
# self-test too, and a check-only glob left it uninvoked.
for d in "$repo_root/.touchstone/checker/pre-commit" "$repo_root/.touchstone/checker/pre-push" "$repo_root/.touchstone/checker/standalone"; do
  [ -d "$d" ] || continue
  while IFS= read -r f; do
    grep -q -- '--self-test' "$f" || continue
    expect_exit "self-test $(basename "$f" .sh)" zero bash "$f" --self-test
  done < <(find "$d" -maxdepth 1 -name '*.sh' | sort)
done
while IFS= read -r f; do
  grep -q -- '--self-test' "$f" || continue
  expect_exit "self-test $(basename "$f" .sh)" zero bash "$f" --self-test
done < <(find "$repo_root/skills" -name '*.sh' | sort)

# ---- dossier type-role self-check (regression ratchet for the 2026-08-30 owner reads):
# a label is a key beside a value — never a heading, never a table value.
ui_root="$(mktemp -d)"; mkdir -p "$ui_root/.touchstone/epics"
cp -R "$here/fixtures/dossier-epic" "$ui_root/.touchstone/epics/2026-01-01-fixture"
rm -f "$ui_root/.touchstone/epics/2026-01-01-fixture/dossier.html"
bash "$scripts_dir/dossier-render.sh" "$ui_root/.touchstone/epics/2026-01-01-fixture" >/dev/null 2>&1
ui_html="$ui_root/.touchstone/epics/2026-01-01-fixture/dossier.html"
python3 - "$ui_html" <<'PY' || { echo "FAIL: dossier type-role self-check"; fail=1; }
import re, sys
h = open(sys.argv[1], encoding='utf-8').read()
bad = {
  'fold heading that is only a label': re.findall(r'<summary><span class="label">[^<]*</span></summary>', h),
  'heading (h2-h4) whose text is only a label': re.findall(r'<h[234][^>]*><span class="label">[^<]*</span>\s*</h[234]>', h),
  'table value cell styled as a label': re.findall(r'<td[^>]*><span class="label">[^<]*</span></td>', h),
  'label with nothing beside it in a paragraph': re.findall(r'<p[^>]*><span class="label">[^<]*</span></p>', h),
}
for k, v in bad.items():
    assert not v, '%s: %d hit(s), e.g. %s' % (k, len(v), v[0][:80])
# every font-size in the style block is a role token, never a literal
css = re.search(r'<style>(.*?)</style>', h, re.S).group(1)
lit = re.findall(r'font-size:\s*[0-9.]+(?:rem|px)', css.split('@media')[0].replace('html{font-size:16px}', ''))
assert not lit, 'literal font sizes in the style block: %s' % lit[:5]
print('PASS: dossier type roles — no label used as a heading or a value; every size is a role token')
PY

# ---- dossier width probe: no horizontal overflow at phone / tablet / desktop widths.
# Needs a headless Chrome; absent → a visible SKIP line (never a silent pass).
ui_chrome=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome chromium chromium-browser; do
  if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then ui_chrome="$c"; break; fi
done
# Capability check before any width measurement: a Chrome that launches but cannot
# --dump-dom a trivial page (sandbox, broken install) is reported as an environment
# SKIP with its first stderr line — never as a layout FAIL with an empty title.
if [ -n "$ui_chrome" ]; then
  ui_cap_err="$(mktemp)"
  ui_cap="$("$ui_chrome" --headless=new --disable-gpu --virtual-time-budget=500 \
             --dump-dom 'data:text/html,<title>capok</title>' 2>"$ui_cap_err" | grep -c '<title>capok</title>')"
  if [ "${ui_cap:-0}" -lt 1 ]; then
    echo "SKIP: dossier width probes — Chrome at $ui_chrome cannot --dump-dom ($(head -1 "$ui_cap_err" | cut -c1-120))"
    ui_chrome=""
  fi
  rm -f "$ui_cap_err"
fi
if [ -n "$ui_chrome" ]; then
  ui_probe="$ui_root/probe.html"
  # every tab visible, every fold open, and the measured widths written into <title>
  sed -e 's/\.tab{display:none}/.tab{display:block}/' -e 's/<details class="fold">/<details class="fold" open>/g' \
      -e 's|</body>|<script>document.title="W="+document.documentElement.scrollWidth+"/"+document.documentElement.clientWidth</script></body>|' \
      "$ui_html" > "$ui_probe"
  for w in 390 768 1280; do
    t="$("$ui_chrome" --headless=new --disable-gpu --hide-scrollbars --window-size="$w,900" --virtual-time-budget=2000 \
          --dump-dom "file://$ui_probe" 2>/dev/null | grep -o '<title>W=[0-9]*/[0-9]*</title>' | head -1)"
    sw="${t#*W=}"; sw="${sw%%/*}"; cw="${t#*/}"; cw="${cw%%<*}"
    if [ -n "$sw" ] && [ -n "$cw" ] && [ "$sw" -le "$cw" ]; then echo "PASS: dossier width probe ${w}px (scroll $sw ≤ client $cw)"
    else echo "FAIL: dossier width probe ${w}px (title=$t)"; fail=1; fi
  done
else
  echo "SKIP: dossier width probe — no headless Chrome on this host"
fi
rm -rf "$ui_root"

# ---- dossier-render fields-only + structure panel:
# T2 additions — dossier-render.sh reads fields only (REQ-4 / AC-13, AC-14, AC-15, AC-17,
# AC-18). Self-contained: uses only run-smoke's existing helpers ($here, $fx, $scripts_dir,
# $repo_root, expect_exit, expect_out, fail) and the $ui_chrome path already probed by the
# width-probe block above.

# ---- AC-13 / AC-14 / AC-15: render the migrated dossier-epic fixture once, assert all three
sm_root="$(mktemp -d)"
mkdir -p "$sm_root/.touchstone/epics"
cp -R "$fx/dossier-epic" "$sm_root/.touchstone/epics/2026-01-01-fixture"
rm -f "$sm_root/.touchstone/epics/2026-01-01-fixture/dossier.html"
sm_ed="$sm_root/.touchstone/epics/2026-01-01-fixture"
expect_exit "dossier AC-13/14/15 fixture renders" zero bash "$scripts_dir/dossier-render.sh" "$sm_ed"
sm_out="$sm_ed/dossier.html"
python3 - "$sm_out" <<'PY' || { echo "FAIL: dossier AC-13/14/15 structural checks"; fail=1; }
import re, sys
h = open(sys.argv[1], encoding='utf-8').read()
chunks = re.split(r'<section class="tab" id="tab-(\d)">', h)[1:]
t = {chunks[i]: chunks[i + 1] for i in range(0, len(chunks), 2)}

# AC-13: F-2's refs=[AC-3] link/count it under AC-3 only; AC-4 (prose-only mention in F-2's
# summary) is auto-linked for display but contributes to no count or list.
m3 = re.search(r'id="2026-01-04-gamma\.spec--AC-3" class="ac">.*?</tr>', h, re.S)
m4 = re.search(r'id="2026-01-04-gamma\.spec--AC-4" class="ac">.*?</tr>', h, re.S)
assert m3 and 'data-jump="finding--F-2"' in m3.group(0), 'AC-3 row missing the F-2 finding link/count'
assert m4 and 'data-jump="finding--F-2"' not in m4.group(0), 'AC-4 row wrongly counts/links F-2 (must count refs only)'
assert 'data-jump="2026-01-04-gamma.spec--AC-4" tabindex="0">AC-4</a>' in h, 'AC-4 not auto-linked for display in F-2 prose'
print('PASS: dossier AC-13 — finding linked/counted under refs only; a prose-only id is auto-linked for display and contributes to no count')

# AC-14: exactly 3 waiting rows (2 from design-review-gamma/review.yaml, 1 from
# deviation.yaml; the spec's own waiting_on_human is migrated to []), each carrying
# title/owner/kind plus its source record and gate; a legacy prose AC-n token (index.md
# Open Questions: "Does REQ-1 of phase 2 subsume AC-2?") produces no row.
front = t['0']
wrows = re.findall(r'<li><label><input type="checkbox"[^>]*>.*?來源</span></a></label></li>', front, re.S)
assert len(wrows) == 3, 'want exactly 3 waiting rows, got %d' % len(wrows)
for title in ('rule on the collision rename', 'accept F-1 as is', 'confirm the equals form stays'):
    assert any(title in r for r in wrows), 'missing waiting row for %r' % title
assert all('負責' in r for r in wrows), 'a waiting row is missing its owner'
assert sum('設計審查' in r for r in wrows) == 2, 'want 2 rows sourced from design-review-gamma/review.yaml (gate=design-review)'
assert sum('>門</span> build' in r for r in wrows) == 1, 'want 1 row sourced from deviation.yaml (gate=build)'
assert 'of phase 2 subsume' in h, 'sanity: the legacy prose sentence with an AC-n token must still be on the page (its AC-2 token is auto-linked, splitting the literal sentence around it)'
print('PASS: dossier AC-14 — exactly 3 waiting rows from fields only, each carrying title/owner/kind/source+gate; a legacy prose AC-n token produced no row')

# AC-15: deviation entries + quiz items appear under per-phase headings (1, 2, 3); the
# quiz's single item shape is result-only (design decision 1, AC-18) — an unanswered
# item (QZ-2) renders its computed "unanswered" state, an answered item carrying a
# recorded result (QZ-1, QZ-3) renders that result; the retired ref-set "miss" grading
# never resurfaces.
rec = t['3']
for ph in ('Phase 1', 'Phase 2', 'Phase 3'):
    assert f'<h3 class="file-title">{ph}</h3>' in rec, 'missing per-phase heading %r' % ph
for qid in ('QZ-1', 'QZ-3'):
    i = rec.find(qid)
    assert i != -1 and 'title="pass">通過</abbr>' in rec[i:i + 200], f'{qid} does not show its recorded pass result'
i2 = rec.find('QZ-2')
assert i2 != -1 and 'title="unanswered">未答</abbr>' in rec[i2:i2 + 200], 'QZ-2 (no answer) does not show unanswered'
assert 'title="miss">未過</abbr>' not in rec, 'a miss pill appeared — the retired ref-set grading must not resurface'
print('PASS: dossier AC-15 — deviation entries and quiz items grouped by phase; an unanswered item shows unanswered, an answered item shows its recorded result; no ref-set miss grading remains')
PY
# ---- panel overlay is phase-scoped: the fixture's gamma spec is phase 3; D-1 (phase 3, interface) belongs on
# its panels, D-2 / D-3 (phase 1 / 2, panel none) do not (regression ratchet for the owner's 2026-08-30 dossier read)
python3 - "$sm_out" <<'PY' || { echo "FAIL: dossier panel overlay leaks other phases' D-n entries"; fail=1; }
import re, sys
h = open(sys.argv[1], encoding='utf-8').read()
sec = re.search(r'<section class="tab" id="tab-2".*?(?=<section class="tab" id="tab-3")', h, re.S).group(0)
m = re.search(r'<h2[^>]*>[^<]*Gamma.*?(?=<h2|\Z)', sec, re.S)
assert m, 'gamma phase block not found in 結構變化'
g = m.group(0)
assert 'deviation--D-1' in g, 'gamma panels lost their own phase-3 entry D-1'
assert 'deviation--D-2' not in g and 'deviation--D-3' not in g, 'gamma (phase 3) panels carry phase-1/2 entries'
print('PASS: dossier panel overlay is phase-scoped (gamma shows D-1 only, never the phase-1/2 entries)')
PY
rm -rf "$sm_root"

# ---- AC-17 negative: no .claude-plugin/plugin.json → no structure panel, no metrics
# section, and plugin-map.sh is never invoked — proved literally with a logging stub at
# the exact path dossier-render.sh would run (<root>/scripts/plugin-map.sh).
ac17_neg="$(mktemp -d)"
mkdir -p "$ac17_neg/.touchstone/epics/2026-03-01-scratch" "$ac17_neg/scripts"
printf -- '---\nslug: scratch\nstatus: active\n---\n\n# Scratch\n\n**Aim:** x.\n' > "$ac17_neg/.touchstone/epics/2026-03-01-scratch/index.md"
ac17_neg_log="$ac17_neg/pm-log.txt"
printf '#!/usr/bin/env bash\necho "invoked $*" >> %q\necho "{}"\n' "$ac17_neg_log" > "$ac17_neg/scripts/plugin-map.sh"
chmod +x "$ac17_neg/scripts/plugin-map.sh"
ac17_neg_ed="$ac17_neg/.touchstone/epics/2026-03-01-scratch"
expect_exit "dossier AC-17 negative renders" zero bash "$scripts_dir/dossier-render.sh" --root "$ac17_neg" "$ac17_neg_ed"
if [ -s "$ac17_neg_log" ]; then
  echo "FAIL: dossier AC-17 negative — plugin-map.sh invoked without plugin.json ($(cat "$ac17_neg_log"))"; fail=1
else
  echo "PASS: dossier AC-17 negative — plugin-map.sh never invoked without plugin.json"
fi
if grep -q 'id="structure-map"' "$ac17_neg_ed/dossier.html" || grep -q 'phase 量測' "$ac17_neg_ed/dossier.html"; then
  echo "FAIL: dossier AC-17 negative — structure panel or metrics section rendered without plugin.json"; fail=1
else
  echo "PASS: dossier AC-17 negative — no structure panel, no metrics section without plugin.json"
fi
rm -rf "$ac17_neg"

# ---- AC-17 positive control + AC-18 width probe: a scratch root WITH plugin.json, whose
# scripts/plugin-map.sh is a logging stub returning stage data with long load chains (the
# shape design decision 6 asks the width probe to stress) — panel present, invocation
# logged, and the width probe passes with the panel in the page.
ac17_pos="$(mktemp -d)"
mkdir -p "$ac17_pos/.claude-plugin" "$ac17_pos/.touchstone/checker/baselines" "$ac17_pos/.touchstone/epics/2026-03-02-scratch2" "$ac17_pos/scripts"
printf '{"name":"scratch","version":"0.0.0"}\n' > "$ac17_pos/.claude-plugin/plugin.json"
printf 'max_stage_load_tokens 1234\nuntested_reachable_shell_lines 5\n' > "$ac17_pos/.touchstone/checker/baselines/plugin-ratchets.txt"
printf -- '---\nslug: scratch2\nstatus: active\n---\n\n# Scratch2\n\n**Aim:** x.\n' > "$ac17_pos/.touchstone/epics/2026-03-02-scratch2/index.md"
ac17_pos_log="$ac17_pos/pm-log.txt"
ac17_pos_json="$ac17_pos/stages.json"
python3 - "$ac17_pos_json" <<'PY'
import json, sys
stages = [{'stage': i, 'entry': 'skills/fake-stress-skill-%d/SKILL.md' % i,
           'load_set': ['skills/fake-stress-skill-%d/references/some-fairly-long-fragment-name-%02d.md' % (i, j) for j in range(25)],
           'lines': 100 + i, 'unique_lines': 90 + i} for i in range(3)]
data = {'nodes': [], 'edges': [], 'entries': [], 'stages': stages, 'false_edges': [], 'orphans': [],
        'test_only': [], 'skills': [], 'metrics': {}, 'stale_waivers': [], 'invalid_waivers': [], 'notes': []}
open(sys.argv[1], 'w', encoding='utf-8').write(json.dumps(data))
PY
printf '#!/usr/bin/env bash\necho "invoked $*" >> %q\ncat %q\n' "$ac17_pos_log" "$ac17_pos_json" > "$ac17_pos/scripts/plugin-map.sh"
chmod +x "$ac17_pos/scripts/plugin-map.sh"
ac17_pos_ed="$ac17_pos/.touchstone/epics/2026-03-02-scratch2"
expect_exit "dossier AC-17 positive renders" zero bash "$scripts_dir/dossier-render.sh" --root "$ac17_pos" "$ac17_pos_ed"
ac17_pos_out="$ac17_pos_ed/dossier.html"
if [ -s "$ac17_pos_log" ] && grep -q 'id="structure-map"' "$ac17_pos_out"; then
  echo "PASS: dossier AC-17 positive — plugin-map.sh invoked (logged), structure panel present"
else
  inv="no"; [ -s "$ac17_pos_log" ] && inv="yes"
  pan="no"; grep -q 'id="structure-map"' "$ac17_pos_out" && pan="yes"
  echo "FAIL: dossier AC-17 positive — invoked=$inv panel=$pan"; fail=1
fi
expect_out "dossier AC-17 positive — ratchet values rendered" 'max_stage_load_tokens' cat "$ac17_pos_out"

# ---- AC-18 half: the width probe passes with the structure panel (long load chains)
# present, at 390/768/1280 — reuses $ui_chrome as already probed above.
if [ -n "$ui_chrome" ]; then
  ac17_probe="$ac17_pos/probe.html"
  sed -e 's/\.tab{display:none}/.tab{display:block}/' -e 's/<details class="fold">/<details class="fold" open>/g' \
      -e 's|</body>|<script>document.title="W="+document.documentElement.scrollWidth+"/"+document.documentElement.clientWidth</script></body>|' \
      "$ac17_pos_out" > "$ac17_probe"
  for w in 390 768 1280; do
    t="$("$ui_chrome" --headless=new --disable-gpu --hide-scrollbars --window-size="$w,900" --virtual-time-budget=2000 \
          --dump-dom "file://$ac17_probe" 2>/dev/null | grep -o '<title>W=[0-9]*/[0-9]*</title>' | head -1)"
    sw="${t#*W=}"; sw="${sw%%/*}"; cw="${t#*/}"; cw="${cw%%<*}"
    if [ -n "$sw" ] && [ -n "$cw" ] && [ "$sw" -le "$cw" ]; then echo "PASS: dossier width probe with structure panel ${w}px (scroll $sw ≤ client $cw)"
    else echo "FAIL: dossier width probe with structure panel ${w}px (title=$t)"; fail=1; fi
  done
else
  echo "SKIP: dossier width probe with structure panel — no headless Chrome on this host"
fi
rm -rf "$ac17_pos"

# ---- shellcheck: scripts/dossier-render.sh's bash wrapper stays clean
if command -v shellcheck >/dev/null 2>&1; then
  expect_exit "shellcheck scripts/dossier-render.sh" zero shellcheck "$scripts_dir/dossier-render.sh"
else
  echo "SKIP: shellcheck scripts/dossier-render.sh — shellcheck not on this host"
fi

# ---- check-exec-bits-all.sh: the untracked-file branch (filesystem mode) — the
# committed red fixture is tracked, so it trips on the index rule; this scratch
# tree has no git index and a 644 script.
eb_root="$(mktemp -d)"; mkdir -p "$eb_root/hooks"; printf '#!/bin/sh\n' > "$eb_root/hooks/x.sh"; chmod 644 "$eb_root/hooks/x.sh"
expect_out "check-exec-bits-all untracked 644 script trips on filesystem mode" "filesystem mode 644, untracked" \
  env TOUCHSTONE_CHECK_ROOT="$eb_root" bash "$repo_root/.touchstone/checker/pre-commit/check-exec-bits-all.sh"
chmod 755 "$eb_root/hooks/x.sh"
expect_exit "check-exec-bits-all untracked 755 script passes" zero \
  env TOUCHSTONE_CHECK_ROOT="$eb_root" bash "$repo_root/.touchstone/checker/pre-commit/check-exec-bits-all.sh"
rm -rf "$eb_root"

# T2 additions — dossier-render.sh quiz/metrics/coverage render (REQ-6 AC-18, REQ-7 AC-22,
# REQ-5 coverage render / design decision 3). Self-contained: uses only run-smoke's existing
# helpers ($fx, $scripts_dir, expect_exit, fail) and $fx/dossier-epic's own phase specs
# (index.md, alpha/beta/gamma) which T1's migration does not touch — only deviation.yaml
# and review.yaml content is built here, deterministically, so these asserts do not depend
# on the exact prose T1 chooses when it migrates the shared fixture's deviation.yaml.

# ---- AC-18: quiz reads `result` only — pass / miss / unanswered, no kind branch ----
t2q_root="$(mktemp -d)"
mkdir -p "$t2q_root/epic"
cp -R "$fx/dossier-epic"/. "$t2q_root/epic/"
rm -f "$t2q_root/epic/dossier.html"
cat > "$t2q_root/epic/deviation.yaml" <<'YAML'
entries: []
waiting_on_human: []
YAML
cat > "$t2q_root/epic/quiz.yaml" <<'YAML'
waived: false
items:
  - id: QZ-1
    phase: 3
    question: does a passed item show pass?
    answer: "yes, via result: pass"
    refs: [AC-1]
    anchor: phase_map.interface_delta
    result: pass
  - id: QZ-2
    phase: 3
    question: does a missed item show miss?
    answer: "an answer the AI judged incomplete"
    refs: [AC-1]
    anchor: phase_map.interface_delta
    result: miss
  - id: QZ-3
    phase: 3
    question: does an item with no answer show unanswered?
    refs: [AC-1]
    anchor: phase_map.interface_delta
YAML
expect_exit "dossier T2 quiz fixture renders" zero bash "$scripts_dir/dossier-render.sh" "$t2q_root/epic"
t2q_out="$t2q_root/epic/dossier.html"
if grep -q 'QZ-1 <span class="pill ok"><abbr class="enum" title="pass">' "$t2q_out" \
   && grep -q 'QZ-2 <span class="pill muted"><abbr class="enum" title="miss">' "$t2q_out" \
   && grep -q 'QZ-3 <span class="pill muted"><abbr class="enum" title="unanswered">' "$t2q_out"; then
  echo "PASS: dossier AC-18 — quiz pass/miss/unanswered read from result only"
else
  echo "FAIL: dossier AC-18 — quiz pass/miss/unanswered not rendered from result alone"; fail=1
fi
if grep -qE 'expected_refs|answer_refs|ref-set' "$scripts_dir/dossier-render.sh"; then
  echo "FAIL: dossier AC-18 — dossier-render.sh still references the retired ref-set grading"; fail=1
else
  echo "PASS: dossier AC-18 — no expected_refs/answer_refs/ref-set left in dossier-render.sh"
fi
# a quiz item's refs render as jump links (the owner must be able to reach the fields the
# answer resolves to from the page — gate-miss 2026-08-31: inert anchor, refs unrendered)
if grep -qE '對回</span> <a class="code" data-jump="[^"]*AC-1"' "$t2q_out"; then
  echo "PASS: dossier quiz — refs render as data-jump links"
else
  echo "FAIL: dossier quiz — refs not rendered as data-jump links"; fail=1
fi
rm -rf "$t2q_root"

# ---- AC-22: metrics is a per-phase list — one row per phase, phases with no entry read
# "no metrics recorded", phases with an entry carry data. The metrics panel only renders
# under a plugin root (design decision 2 keeps AC-17's existing gating), so this root
# carries .claude-plugin/plugin.json and a logging-stub scripts/plugin-map.sh, same as the
# AC-17 positive fixture above. ----
t2m_root="$(mktemp -d)"
mkdir -p "$t2m_root/.claude-plugin" "$t2m_root/scripts" "$t2m_root/epic"
printf '{"name":"scratch","version":"0.0.0"}\n' > "$t2m_root/.claude-plugin/plugin.json"
printf '#!/usr/bin/env bash\necho "{}"\n' > "$t2m_root/scripts/plugin-map.sh"
chmod +x "$t2m_root/scripts/plugin-map.sh"
printf -- '---\nslug: metrics-demo\nstatus: active\nstarted: 2026-01-01\nlanded:\n---\n\n# Metrics demo\n\n**Aim:** exercise the per-phase metrics table.\n\n## Phases\n\n| # | Title | Spec | Plan | Status | Landed |\n|---|---|---|---|---|---|\n| 1 | One | [spec](2026-01-01-p1.spec.yaml) | — | active | |\n| 2 | Two | [spec](2026-01-02-p2.spec.yaml) | — | active | |\n| 3 | Three | [spec](2026-01-03-p3.spec.yaml) | — | active | |\n| 4 | Four | [spec](2026-01-04-p4.spec.yaml) | — | active | |\n' > "$t2m_root/epic/index.md"
for n in 1 2 3 4; do
  sed -e "s/^id: .*/id: SPEC-metrics-demo-p$n/" -e "s/^title: .*/title: Phase $n/" \
      -e "s/^phase: .*/phase: $n/" -e "s/^date: .*/date: 2026-01-0$n/" \
      "$fx/dossier-epic/2026-01-04-gamma.spec.yaml" > "$t2m_root/epic/2026-01-0$n-p$n.spec.yaml"
done
cat > "$t2m_root/epic/deviation.yaml" <<'YAML'
entries: []
metrics:
  - phase: 3
    wall_clock_h: 7.5
    human_turns: 82
    dispatches: 14
    lens_h: {challenger: 2, coverage: 1}
    stage_tokens: [{stage: 0, tokens: 100}, {stage: 1, tokens: 24701}]
    false_edges: 0
    instrument_churn: {shape_driven_lines: 20, other_lines: 0}
    measured_at: "ca2036d1234567890abcdef1234567890abcdef"
  - phase: 4
    wall_clock_h: 3.2
    human_turns: 12
    dispatches: 6
    lens_h: {verification-honesty: 1}
    stage_tokens: [{stage: 0, tokens: 90}, {stage: 1, tokens: 21000}]
    false_edges: 0
    instrument_churn: {shape_driven_lines: 5, other_lines: 0}
    measured_at: "af28d231234567890abcdef1234567890abcdef"
waiting_on_human: []
YAML
expect_exit "dossier T2 metrics fixture renders" zero bash "$scripts_dir/dossier-render.sh" --root "$t2m_root" "$t2m_root/epic"
t2m_out="$t2m_root/epic/dossier.html"
python3 - "$t2m_out" <<'PY' || { echo "FAIL: dossier AC-22 — metrics table structural checks"; fail=1; }
import re, sys
h = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r'phase 量測.*?<table>(.*?)</table>', h, re.S)
assert m, 'metrics table not found on the page'
rows = re.findall(r'<tr>(.*?)</tr>', m.group(1), re.S)[1:]  # drop header row
assert len(rows) == 4, 'want 4 rows (phase set 1-4), got %d' % len(rows)
assert 'no metrics recorded' in rows[0] and 'no metrics recorded' in rows[1], 'phases 1-2 must read "no metrics recorded"'
assert '82' in rows[2] and '7.5' in rows[2], 'phase 3 row must carry its recorded data'
assert '12' in rows[3] and '3.2' in rows[3], 'phase 4 row must carry its recorded data'
print('PASS: dossier AC-22 — one row per phase; phases 1-2 "no metrics recorded"; phases 3-4 carry data')
PY
rm -rf "$t2m_root"

# ---- coverage (AC-15 render side, design decision 3): a review round carrying coverage[]
# shows a compact covered count beside its C/H/M/L counts; a round with no coverage key
# renders as today ----
t2c_root="$(mktemp -d)"
mkdir -p "$t2c_root/epic"
cp -R "$fx/dossier-epic"/. "$t2c_root/epic/"
rm -f "$t2c_root/epic/dossier.html"
python3 - "$t2c_root/epic/design-review-gamma/review.yaml" <<'PY'
import sys
p = sys.argv[1]
text = open(p, encoding='utf-8').read()
if 'coverage:' not in text:
    text = text.replace(
        'findings:',
        'coverage:\n  - {ref: AC-1, status: covered, evidence: "held"}\n  - {ref: AC-2, status: covered, evidence: "held"}\nfindings:',
        1,
    )
    open(p, 'w', encoding='utf-8').write(text)
PY
mkdir -p "$t2c_root/epic/deliverable-review-gamma"
cat > "$t2c_root/epic/deliverable-review-gamma/review.yaml" <<'YAML'
gate: deliverable-review
target: 2026-01-04-gamma.spec.yaml
sha: fixture
round: 1
providers: [{lens: conformance, arms: [cc]}]
challenger: cc
degraded: false
verdict: approve
counts: {C: 0, H: 0, M: 0, L: 0}
findings: []
waiting_on_human: []
YAML
expect_exit "dossier T2 coverage fixture renders" zero bash "$scripts_dir/dossier-render.sh" "$t2c_root/epic"
t2c_out="$t2c_root/epic/dossier.html"
n_covered="$(grep -o 'class="label">covered</span> <span class="num">[0-9]*</span>' "$t2c_out" | wc -l | tr -d ' ')"
if [ "$n_covered" = "1" ] && grep -q 'covered</span> <span class="num">2</span>' "$t2c_out"; then
  echo "PASS: dossier coverage — covered count renders for the round carrying coverage[], absent for the round without"
else
  echo "FAIL: dossier coverage — covered count did not render exactly once (got $n_covered occurrences)"; fail=1
fi
rm -rf "$t2c_root"

# ---- phase-5 fix pass regressions ----
# the de-named path strings must stay out of design-spec's stage-loaded files
if grep -rn "schemas/spec.schema.yaml\|severity-tiered-stopping-rule\|live-bearing-predicate" "$scripts_dir/../skills/design-spec/" >/dev/null 2>&1; then
  echo "FAIL: de-named path string re-appeared under skills/design-spec/"; fail=1
else
  echo "PASS: design-spec names no spec-schema / stopping-rule / live-bearing path"
fi

# no stage context loads the three new schemas or the spec schema
if bash "$scripts_dir/plugin-map.sh" --root "$scripts_dir/.." 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
bad = [f for st in d.get("stages", []) for c in st.get("contexts", []) for f in c.get("files", [])
       if f.endswith(("quiz.schema.yaml", "assay.schema.yaml", "explore.schema.yaml", "spec.schema.yaml"))]
sys.exit(1 if bad else 0)
'; then
  echo "PASS: no stage context loads quiz/assay/explore/spec schema files"
else
  echo "FAIL: a schema file appeared in a stage context list"; fail=1
fi

# a readiness-false assay record renders its card but never a waiting/blocker row;
# the assay card renders consensus/flip_triggers/deferred; the front-page quiz ratio is phase-scoped
t5a_root="$(mktemp -d)"
mkdir -p "$t5a_root/epic"
cp -R "$fx/dossier-epic"/. "$t5a_root/epic/"
rm -f "$t5a_root/epic/dossier.html"
cat > "$t5a_root/epic/assay-2026-01-07-zeta.yaml" <<'YAML'
subject: zeta probe
date: 2026-01-07
epics: [demo]
term_sheet: []
alignment: []
extraction: []
consensus:
  scope: [{text: zeta scope row, trace: [T-1]}]
  invariants: []
  contract_facts: []
  out_of_scope: []
flip_triggers: [{signal: zeta flip signal, revisit: ship}]
deferred: [zeta deferred item]
readiness: {yes: false, date: 2026-01-07, round: R-1}
YAML
expect_exit "assay zeta fixture checker-valid" zero bash "$scripts_dir/check-artifact.sh" assay "$t5a_root/epic/assay-2026-01-07-zeta.yaml"
expect_exit "dossier renders with readiness-false assay" zero bash "$scripts_dir/dossier-render.sh" "$t5a_root/epic"
if python3 - "$t5a_root/epic/dossier.html" <<'PY'
import re, sys
h = open(sys.argv[1], encoding='utf-8').read()
assert 'zeta probe' in h, 'zeta assay card missing'
todo = ' '.join(re.findall(r'<ul class="todo check">.*?</ul>', h, re.S))
assert 'zeta' not in todo, 'readiness-false assay leaked into a blocker/waiting row'
assert '共識' in h and 'zeta scope row' in h, 'assay card consensus not rendered'
assert '翻轉觸發' in h and 'zeta flip signal' in h, 'assay card flip_triggers not rendered'
assert '擱置' in h and 'zeta deferred item' in h, 'assay card deferred not rendered'
assert re.search(r'理解測驗.{0,300}?<span class="num">1/1</span>', h, re.S), 'front-page quiz ratio not phase-scoped (want 1/1)'
assert re.search(r'--quiz"><ul class="summary"><li>[^<]*phase 3 landed the equals flag form', h), 'front-page quiz section must open with its phase summary, one point per list item (owner reads it there, not only in the records tab)'
PY
then
  echo "PASS: readiness-false no-blocker + assay card consensus/flip/deferred + phase-scoped quiz ratio"
else
  echo "FAIL: phase-5 fix-pass render assertions"; fail=1
fi
rm -rf "$t5a_root"

# ---- foundation:inherit resolves against epic.yaml (yaml-born epic): the fixture pair
# carries both ends — the spec declares inherit, the epic.yaml carries the foundation block.
if grep -q '^foundation: inherit' "$here/fixtures/dossier-epic-yaml/2026-01-04-gamma.spec.yaml" \
   && grep -q '^foundation:' "$here/fixtures/dossier-epic-yaml/epic.yaml" \
   && grep -q 'intention:' "$here/fixtures/dossier-epic-yaml/epic.yaml"; then
  echo "PASS: foundation:inherit two-end pair present on the yaml-born fixture"
else
  echo "FAIL: foundation:inherit pair broken on the yaml-born fixture"; fail=1
fi

# ---- assay fork-case split: the fork chain (ADR authoring / rubric / critique lens)
# loads only on the fork trigger — the pointer file exists, SKILL.md points at it,
# and the non-fork SKILL body no longer names the chain files.
if [ -f "$scripts_dir/../skills/assay/references/fork-case.md" ] \
   && grep -q 'references/fork-case.md' "$scripts_dir/../skills/assay/SKILL.md" \
   && ! grep -qE 'adr-authoring\.md|arch-rubric\.md|critique-lens\.md' "$scripts_dir/../skills/assay/SKILL.md"; then
  echo "PASS: assay fork chain split behind references/fork-case.md (trigger-only load)"
else
  echo "FAIL: assay fork-case split (missing file, dangling pointer, or chain still named in SKILL.md)"; fail=1
fi

# ---- resolve-config.sh: six-field bundle green + malformed red (direct invocation;
# the checker-rail pair exercises it again through check-resolve-config.sh)
expect_exit "resolve-config: green fixture prints the bundle" zero \
  bash "$scripts_dir/resolve-config.sh" --root "$here/../../.touchstone/checker/fixtures/resolve-config/green"
expect_out "resolve-config: six key=value lines" "research=" \
  bash "$scripts_dir/resolve-config.sh" --root "$here/../../.touchstone/checker/fixtures/resolve-config/green"
expect_exit "resolve-config: malformed yaml is fatal" nonzero \
  bash "$scripts_dir/resolve-config.sh" --root "$here/../../.touchstone/checker/fixtures/resolve-config/red"

# ---- init-checker-scaffold.sh: help exits 0; a scratch missing-state run writes the yaml
icd="$(mktemp -d)"
expect_exit "init-checker-scaffold: --help exits 0" zero bash "$scripts_dir/init-checker-scaffold.sh" --help
expect_exit "init-checker-scaffold: missing state writes yaml (exit 0)" zero \
  bash "$scripts_dir/init-checker-scaffold.sh" --project-root "$icd" --workspace-root .touchstone
expect_exit "init-checker-scaffold: yaml written" zero test -f "$icd/.claude/touchstone.yaml"
rm -rf "$icd"

# ---- the redesigned codex dispatch shape (agents/codex-reviewer.md): the task rides a
# FILE streamed to codex by the shell; both liveness artifacts (raw_codex.jsonl +
# last-message.txt) must be produced by that exact form. Honest SKIP when codex is absent.
if command -v codex >/dev/null 2>&1; then
  dsd="$(mktemp -d)"
  printf 'probe material line\n' > "$dsd/task.md"
  timeout 120 codex exec --json --skip-git-repo-check -o "$dsd/last-message.txt" \
    "Reply with exactly one line: OK" < "$dsd/task.md" > "$dsd/raw_codex.jsonl" 2>&1
  if [ -s "$dsd/last-message.txt" ] && [ -s "$dsd/raw_codex.jsonl" ]; then
    echo "PASS: task_file-streamed codex dispatch produces both liveness artifacts"
  else
    echo "FAIL: task_file-streamed codex dispatch (missing/empty liveness artifact)"; fail=1
  fi
  rm -rf "$dsd"
else
  echo "SKIP: codex CLI not installed — task_file dispatch shape not exercised (not fake-green)"
fi

# ---- codex-probe.sh: envelope-shape smoke — SKIPs cleanly (exit 0) when codex
# CLI is absent, never fake-green; PASS-asserts the envelope (record line
# written, outcome field present) when codex is present.
cpd="$(mktemp -d)"
expect_exit "codex-probe smoke: exits 0 (PASS when codex present, SKIP when absent)" zero \
  bash "$scripts_dir/codex-probe.sh" --smoke --out "$cpd/probe-smoke.jsonl"
rm -rf "$cpd"

# ---- roadmap-render.sh (REQ-3 / AC-10, AC-25): fixture epics set (active yaml +
# completed yaml + active legacy index.md) renders both tables, the generated
# header (source + hash), and writes atomically (no leftover temp file).
rr_root="$(mktemp -d)"
mkdir -p "$rr_root/.touchstone"
cp -R "$here/fixtures/roadmap-epics" "$rr_root/.touchstone/epics"
expect_exit "roadmap-render.sh renders the fixture epics set" zero \
  bash "$scripts_dir/roadmap-render.sh" --root "$rr_root"
rr_out="$rr_root/ROADMAP.md"
if [ -f "$rr_out" ] \
   && grep -q 'GENERATED by scripts/roadmap-render.sh' "$rr_out" \
   && grep -q 'source: .touchstone/epics' "$rr_out" \
   && grep -q 'sha256:' "$rr_out" \
   && grep -qE '^\| alpha \|.*\| active \| 1/2 \|' "$rr_out" \
   && grep -qE '^\| gamma \|.*\| active \| 1/2 \|' "$rr_out" \
   && grep -qE '^\| beta \| 2026-01-15 \|' "$rr_out" \
   && ! find "$rr_root" -maxdepth 1 -name '.roadmap-render.tmp-*' | grep -q .; then
  echo "PASS: roadmap-render.sh output has Active/Completed tables + generated header (source+hash), no leftover temp file"
else
  echo "FAIL: roadmap-render.sh output shape"; cat "$rr_out" 2>&1; fail=1
fi
if grep -q 'mkstemp' "$scripts_dir/roadmap-render.sh" && grep -q 'os.replace' "$scripts_dir/roadmap-render.sh"; then
  echo "PASS: roadmap-render.sh writes via temp-file + rename (atomic write)"
else
  echo "FAIL: roadmap-render.sh has no temp-file+rename atomic-write mechanism"; fail=1
fi
rm -rf "$rr_root"

# ---- roadmap-render.sh --audit (AC-25 script half): a stale active epic (dir
# untouched >30 days, no git history so the checker falls back to file mtime)
# prints a staleness finding and exits non-zero; a clean (fresh) set prints
# nothing and exits 0.
rr_audit_root="$(mktemp -d)"
mkdir -p "$rr_audit_root/.touchstone/epics/2026-01-01-stale"
cat > "$rr_audit_root/.touchstone/epics/2026-01-01-stale/epic.yaml" <<'YAML'
slug: stale-epic
status: active
started: 2020-01-01
aim: audit staleness fixture.
foundation: {intention: audit fixture, out_of_scope: []}
phases:
  - {n: 1, title: One, status: proposed}
YAML
find "$rr_audit_root/.touchstone/epics/2026-01-01-stale" -exec touch -t 202001010000 {} \;
expect_exit "roadmap-render.sh --audit on a stale set exits non-zero" nonzero \
  bash "$scripts_dir/roadmap-render.sh" --root "$rr_audit_root" --audit
expect_out "roadmap-render.sh --audit reports the staleness finding" "STALE: stale-epic" \
  bash "$scripts_dir/roadmap-render.sh" --root "$rr_audit_root" --audit
rm -rf "$rr_audit_root"

rr_clean_root="$(mktemp -d)"
mkdir -p "$rr_clean_root/.touchstone/epics/2026-01-01-fresh"
cat > "$rr_clean_root/.touchstone/epics/2026-01-01-fresh/epic.yaml" <<'YAML'
slug: fresh-epic
status: active
started: 2026-01-01
aim: audit clean fixture.
foundation: {intention: audit fixture, out_of_scope: []}
phases:
  - {n: 1, title: One, status: proposed}
YAML
rr_clean_out="$(bash "$scripts_dir/roadmap-render.sh" --root "$rr_clean_root" --audit 2>&1)"; rr_clean_rc=$?
if [ "$rr_clean_rc" -eq 0 ] && [ -z "$rr_clean_out" ]; then
  echo "PASS: roadmap-render.sh --audit on a clean set prints nothing and exits 0"
else
  echo "FAIL: roadmap-render.sh --audit clean set (rc=$rr_clean_rc): $rr_clean_out"; fail=1
fi
rm -rf "$rr_clean_root"

# ---- check-roadmap-fresh.sh (AC-11): direct assertion beyond the generic
# checker-rail loop (which also auto-discovers .touchstone/checker/fixtures/roadmap-fresh/{green,red}/)
# -- the red fixture (a generated-but-hand-edited ROADMAP.md) trips non-zero naming stale.
rf_checker="$scripts_dir/../.touchstone/checker/pre-commit/check-roadmap-fresh.sh"
rf_red="$scripts_dir/../.touchstone/checker/fixtures/roadmap-fresh/red"
rf_out="$(TOUCHSTONE_CHECK_ROOT="$rf_red" bash "$rf_checker" 2>&1)"; rf_rc=$?
if [ "$rf_rc" -ne 0 ] && printf '%s' "$rf_out" | grep -q 'stale'; then
  echo "PASS: check-roadmap-fresh.sh red fixture exits non-zero naming stale"
else
  echo "FAIL: check-roadmap-fresh.sh red fixture (rc=$rf_rc): $rf_out"; fail=1
fi

exit "$fail"
