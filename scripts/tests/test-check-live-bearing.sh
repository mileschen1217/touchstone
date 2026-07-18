#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CHK="$REPO_ROOT/scripts/check-live-bearing.sh"
PRE="$REPO_ROOT/scripts/design-review-precheck.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

vs() { # write a spec with a given VS live-bearing value + optional live-signal AC
  # SC2016: \n in single-quoted printf format is intentional (printf escape, not shell expansion).
  # shellcheck disable=SC2016
  printf '## Acceptance Criteria\n#### AC-1 — x\n```\nGiven %s\n```\n\n## Verification Strategy\n- **Live-bearing AC IDs:** %s\n' "$2" "$3" > "$1"
}

# AC-25: well-formed, listed AC exists → exit 0, no finding
s="$TMP/ok.md"; vs "$s" "a normal precondition" "AC-1"
bash "$CHK" "$s" >/dev/null 2>&1 && ok "AC-25 clean → 0" || fail "AC-25 nonzero on clean"

# AC-23: orphan VS entry (AC-9 not in spec) → nonzero
s="$TMP/orphan.md"; vs "$s" "x" "AC-9"
bash "$CHK" "$s" >/dev/null 2>&1 && fail "AC-23 orphan should be nonzero" || ok "AC-23 orphan flagged"

# AC-26 / AC-21: neither form declares Live-bearing → [unverified: no declaration], nonzero
s="$TMP/novs.md"; printf '## Acceptance Criteria\n#### AC-1 — x\n' > "$s"
out="$(bash "$CHK" "$s" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "no live-bearing declaration"; } \
  && ok "AC-21 neither-form unverified" || fail "AC-21 out=$out rc=$rc"

# --- P2 REQ-8/AC-21: new form (Live-bearing in the AC-section intro) + both-forms ---
newform() { # <path> <ac-body-given> <ac-intro-live-bearing-value>
  # shellcheck disable=SC2016
  printf '## Acceptance Criteria\n- **Live-bearing AC IDs:** %s\n\n#### AC-1 — x\n```\nGiven %s\n```\n' "$3" "$2" > "$1"
}
bothform() { # <path> <new-value> <legacy-value>
  # shellcheck disable=SC2016
  printf '## Acceptance Criteria\n- **Live-bearing AC IDs:** %s\n\n#### AC-1 — x\n```\nGiven z\n```\n\n## Verification Strategy\n- **Live-bearing AC IDs:** %s\n' "$2" "$3" > "$1"
}
# new-form clean → 0
s="$TMP/new-ok.md"; newform "$s" "a precondition" "AC-1"
bash "$CHK" "$s" >/dev/null 2>&1 && ok "AC-21 new-form clean → 0" || fail "AC-21 new-form nonzero on clean"
# new-form orphan → nonzero
s="$TMP/new-orphan.md"; newform "$s" "x" "AC-9"
bash "$CHK" "$s" >/dev/null 2>&1 && fail "AC-21 new-form orphan should be nonzero" || ok "AC-21 new-form orphan flagged"
# both forms, same set → 0 (new authoritative, no disagreement)
s="$TMP/both-agree.md"; bothform "$s" "AC-1" "AC-1"
bash "$CHK" "$s" >/dev/null 2>&1 && ok "AC-21 both-forms agree → 0" || fail "AC-21 both-agree nonzero"
# both forms, different sets → nonzero (disagreement)
s="$TMP/both-disagree.md"; printf '## Acceptance Criteria\n- **Live-bearing AC IDs:** AC-1\n\n#### AC-1 — x\n#### AC-2 — y\n\n## Verification Strategy\n- **Live-bearing AC IDs:** AC-2\n' > "$s"
out="$(bash "$CHK" "$s" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "disagreement"; } && ok "AC-21 both-forms disagree flagged" || fail "AC-21 disagree rc=$rc out=$out"

# --- P2 REQ-8/AC-20: the Index Live-bearing column is a second new-form source ---
# intro line + Index column AGREE → pass
s="$TMP/idx-agree.md"; printf '## Acceptance Criteria\n- **Live-bearing AC IDs:** AC-1\n\n| Req | AC | Name | Live-bearing |\n|---|---|---|---|\n| REQ-1 | AC-1 | a | yes |\n| REQ-1 | AC-2 | b | |\n\n#### AC-1 — x\n#### AC-2 — y\n' > "$s"
bash "$CHK" "$s" >/dev/null 2>&1 && ok "AC-20 intro + Index agree → 0" || fail "AC-20 idx-agree nonzero"
# intro line + Index column DISAGREE → nonzero
s="$TMP/idx-disagree.md"; printf '## Acceptance Criteria\n- **Live-bearing AC IDs:** AC-1\n\n| Req | AC | Name | Live-bearing |\n|---|---|---|---|\n| REQ-1 | AC-1 | a | |\n| REQ-1 | AC-2 | b | yes |\n\n#### AC-1 — x\n#### AC-2 — y\n' > "$s"
out="$(bash "$CHK" "$s" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "different AC sets"; } && ok "AC-20 intro vs Index disagree flagged" || fail "AC-20 idx-disagree rc=$rc out=$out"
# Index column ONLY (no intro line) → Index is the declaration; orphan still caught
s="$TMP/idx-only.md"; printf '## Acceptance Criteria\n\n| Req | AC | Name | Live-bearing |\n|---|---|---|---|\n| REQ-1 | AC-1 | a | yes |\n\n#### AC-1 — x\n' > "$s"
bash "$CHK" "$s" >/dev/null 2>&1 && ok "AC-20 Index-only declaration → 0" || fail "AC-20 idx-only nonzero"

# AC-27: `none` is valid syntax → not reported missing/malformed; candidate sweep still runs
s="$TMP/none.md"; vs "$s" "the deployed hook fires on a real session" "none"
out="$(bash "$CHK" "$s" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && ! printf '%s' "$out" | grep -qi "malformed"; } && ok "AC-27 none valid" || fail "AC-27 rc=$rc out=$out"
printf '%s' "$out" | grep -qi "candidate" && ok "AC-27 candidate sweep runs under none" || fail "AC-27 no candidate emitted"

# AC-24: live-signal AC absent from list → advisory candidate on stdout, still exit 0
s="$TMP/cand.md"; vs "$s" "a real deployed session blocks the commit" "none"
out="$(bash "$CHK" "$s" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi "candidate"; } && ok "AC-24 advisory candidate" || fail "AC-24 rc=$rc out=$out"

# AC-41: malformed value (TBD) → format error nonzero, no crash
s="$TMP/bad.md"; vs "$s" "x" "TBD"
bash "$CHK" "$s" >/dev/null 2>&1 && fail "AC-41 malformed should be nonzero" || ok "AC-41 malformed format error"

# AC-40 / AC-43 are INTEGRATION ACs — a source-grep for "check-live-bearing.sh" is a
# false-green (a commented-out / mis-pathed / output-swallowed wiring passes it — the exact
# dead-hook class REQ-4 exists to prevent). Instead run the REAL design-review-precheck.sh
# and assert the finding reaches its aggregate output. The precheck gates on floor + challenge
# for a requirement-bearing spec, so the helper emits a floor-valid spec + a matching
# challenge.json (empty findings, digest computed live).
SX="$REPO_ROOT/scripts/spec-extract.sh"
floorspec() { # <path> <vs-live-bearing-value> <extra-ac-body-or-empty>
  local s="$1" vs="$2" extra="$3"
  cat > "$s" <<SPEC
---
type: spec
status: accepted-candidate
---
## User Stories
- US-1 — As a dev, I want x.

## Acceptance Criteria

| Req | AC | Name |
|---|---|---|
| REQ-1 | AC-1 | base |
$( [ -n "$extra" ] && printf '| REQ-1 | AC-2 | extra |' )

### Requirement: REQ-1 — the thing

traces-to: US-1

#### AC-1 — base
\`\`\`
Given a normal precondition
When something
Then a result
\`\`\`
$extra

## Verification Strategy

- **Live-bearing AC IDs:** $vs
SPEC
  # matching challenge.json (requirement-bearing → precheck requires it)
  local dig; dig="$(bash "$SX" digest "$s" 2>/dev/null)"
  jq -nc --arg d "$dig" '{schema_version:3,normalizer_version:1,author_id:"t",challenger_id:"c",input_digest:$d,findings:[]}' > "${s%.md}.challenge.json"
}

# AC-40: a REAL orphan VS entry (AC-9 not in spec) surfaces through design-review-precheck's output
s="$TMP/int-orphan.md"; floorspec "$s" "AC-9" ""
out="$(bash "$PRE" "$s" 2>&1)"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -qi "orphan"; } \
  && ok "AC-40 orphan finding reaches precheck aggregate" || fail "AC-40 rc=$rc out=$out"

# AC-43: an advisory candidate (live-signal AC-2, no structural finding) surfaces through
# precheck AND precheck still exits 0 (capture-ALWAYS echo; capture-on-failure would swallow it)
# SC2016: \n in single-quoted printf format is intentional (printf escape, not shell expansion).
# shellcheck disable=SC2016
extra="$(printf '#### AC-2 — wiring\n```\nGiven a real deployed session blocks the commit\nWhen fired\nThen blocked\n```')"
s="$TMP/int-cand.md"; floorspec "$s" "AC-1" "$extra"
out="$(bash "$PRE" "$s" 2>&1)"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qi "candidate"; } \
  && ok "AC-43 advisory candidate surfaces at precheck exit 0" || fail "AC-43 rc=$rc out=$out"

echo "== test-check-live-bearing: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
