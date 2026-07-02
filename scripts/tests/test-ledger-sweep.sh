#!/usr/bin/env bash
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
#
# test-ledger-sweep.sh — end-to-end tests for sweep-run.sh's five-phase
# orchestration (collect -> classify -> validate-candidates -> stage ->
# finalize -> report), using the judgment-agnostic stub-l1.sh/stub-l2.sh
# fixtures in place of the real haiku/sonnet dispatches (Task 8's job).
# See .touchstone/specs/2026-07-02-catch-attribution-ledger-design.md
# (REQ-6, REQ-7) and .superpowers/sdd/task-7-brief.md.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SWEEP="$REPO_ROOT/scripts/ledger/sweep-run.sh"
W="$REPO_ROOT/scripts/ledger/ledger-append.sh"
L1="$REPO_ROOT/scripts/tests/fixtures/ledger/stub-l1.sh"
L1_PARTIAL="$REPO_ROOT/scripts/tests/fixtures/ledger/stub-l1-partial.sh"
L2="$REPO_ROOT/scripts/tests/fixtures/ledger/stub-l2.sh"
FIXTURE="$REPO_ROOT/scripts/tests/fixtures/ledger/fixture-transcript.jsonl"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# mkl <name> — a bare ledger dir (no src/repo/epic) for tests that seed
# sweep state files directly. Echoes the ledger dir path.
mkl() {
  local d="$TMP/$1/ledger"
  mkdir -p "$d"
  echo "$d"
}

# mkscene <name> — $TMP/<name>/{ledger,src,repo,epic}. Echoes
# "ldir src repo epic" (space-separated) for the caller to read into four
# variables.
mkscene() {
  local d="$TMP/$1"
  mkdir -p "$d/ledger" "$d/src" "$d/repo" "$d/epic"
  echo "$d/ledger $d/src $d/repo $d/epic"
}

# mk_git_repo <repo_dir> <fix_subject> — a 2-commit chain: a non-fix anchor
# then a same-day fix commit carrying <fix_subject> (expected to embed a
# TESTHINT:<key> token for the stub-l1 correlation convention).
mk_git_repo() {
  local r="$1" subj="$2"
  git -C "$r" init -q
  git -C "$r" config user.email t@t.com
  git -C "$r" config user.name t
  echo l1 > "$r/f.sh"
  git -C "$r" add f.sh
  GIT_AUTHOR_DATE="@1700000000 +0000" GIT_COMMITTER_DATE="@1700000000 +0000" \
    git -C "$r" commit -q -m "feat: add f"
  echo l2 >> "$r/f.sh"
  git -C "$r" add f.sh
  GIT_AUTHOR_DATE="@1700086400 +0000" GIT_COMMITTER_DATE="@1700086400 +0000" \
    git -C "$r" commit -q -m "$subj"
}

# mk_epic <epic_dir> <unverified_cell_text> — an epic index.md with one
# Evidence Reckoning [unverified] row whose cell carries <unverified_cell_text>
# (expected to embed a TESTHINT:<key> token, followed by a space so the
# stub's `[^ ]+` key regex doesn't swallow the row's closing "]").
mk_epic() {
  local e="$1" cell="$2"
  mkdir -p "$e"
  cat > "$e/index.md" <<EOF
---
slug: demo
---

## Evidence Reckoning

| AC | Covered by | [unverified] | live-bearing? | waiver | Issue |
|----|----|----|----|----|----|
| AC-7 | none | [unverified: $cell] | no | - | - |
EOF
}

# label_json <what> <ref> — a --label payload with a transcript evidence
# ref, human/design-review/missing-AC locus (arbitrary but valid).
label_json() {
  local what="$1" ref="$2"
  jq -nc --arg w "$what" --arg r "$ref" \
    '{what:$w, caught_by:"human", should_have:"design-review", gap_class:"missing-AC",
      evidence:[{kind:"transcript", ref:$r}]}'
}

# sw <ldir> <phase> [transcripts_dir] [git_repo] [epic_dir] — runs one
# sweep-run.sh phase with the env seams it consumes; unused source dirs
# passed as "" are treated as not-configured (that source is skipped, not
# failed) by collect()'s own [-n] guards.
sw() {
  local ldir="$1"
  local phase="$2"
  local tdir="${3:-}"
  local grepo="${4:-}"
  local edir="${5:-}"
  TOUCHSTONE_LEDGER_DIR="$ldir" \
    LEDGER_TRANSCRIPTS_DIR="$tdir" \
    LEDGER_GIT_REPO="$grepo" \
    LEDGER_EPIC_DIR="$edir" \
    LEDGER_L1_CMD="$L1" \
    LEDGER_L2_CMD="$L2" \
    bash "$SWEEP" "$phase"
}

full_sweep() { # <ldir> <transcripts_dir> <git_repo> <epic_dir>
  local ldir="$1" tdir="$2" grepo="$3" edir="$4"
  sw "$ldir" collect "$tdir" "$grepo" "$edir" >/dev/null
  sw "$ldir" classify >/dev/null
  sw "$ldir" validate-candidates >/dev/null
  sw "$ldir" stage >/dev/null
  sw "$ldir" finalize >/dev/null
}

lc() { # <file> — line count, 0 if absent/empty
  local n
  n="$(grep -c . "$1" 2>/dev/null || true)"
  [ -n "$n" ] || n=0
  echo "$n"
}

# ============================================================
# AC-13 — fixture sweep end-to-end, miss-only negative control
# ============================================================

read -r LDIR SRC REPO EPIC <<<"$(mkscene ac13)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
mk_git_repo "$REPO" "fix: patch f TESTHINT:K2 chain"
mk_epic "$EPIC" "root cause TESTHINT:K3 missing"

full_sweep "$LDIR" "$SRC" "$REPO" "$EPIC"

LC13="$(lc "$LDIR/entries.jsonl")"
if [ "$LC13" = 3 ]; then
  ok "AC-13 sweep produces exactly 3 entries for (a) transcript, (b) git, (c) reckoning"
else
  fail "AC-13 entry count (lc=$LC13)"
fi

SRC_A="$(jq -r 'select(.evidence[0].kind=="transcript") | .source' "$LDIR/entries.jsonl")"
SRC_B="$(jq -r 'select(.evidence[0].kind=="git") | .source' "$LDIR/entries.jsonl")"
SRC_C="$(jq -r 'select(.evidence[0].kind=="reckoning") | .source' "$LDIR/entries.jsonl")"
if [ "$SRC_A" = "sweep:transcript" ] && [ "$SRC_B" = "sweep:git" ] && [ "$SRC_C" = "sweep:reckoning" ]; then
  ok "AC-13 correct source attribution per entry (sweep:transcript / sweep:git / sweep:reckoning)"
else
  fail "AC-13 source attribution (a=$SRC_A b=$SRC_B c=$SRC_C)"
fi

LOCUS_OK="$(jq -s '[ .[] | (.caught_by=="live-probe" and .should_have=="design-review" and .gap_class=="missing-AC") ] | all' "$LDIR/entries.jsonl")"
if [ "$LOCUS_OK" = "true" ]; then
  ok "AC-13 correct locus (caught_by/should_have) + gap_class on all entries"
else
  fail "AC-13 locus/gap_class ($LOCUS_OK)"
fi

# (d): the own-gate-caught message (TESTHINT:notmiss) must be extracted as
# a candidate (present in both .digest.jsonl and .candidates-log.jsonl,
# is_miss:false) but never reach the ledger.
D_REF="$(jq -r 'select(.payload.text? and (.payload.text | contains("TESTHINT:notmiss"))) | .ref' "$LDIR/.digest.jsonl")"
D_CAND_ISMISS="$(jq -r --arg r "$D_REF" 'select(.ref==$r) | .is_miss' "$LDIR/.candidates-log.jsonl")"
D_LEDGER_HITS="$(jq --arg r "$D_REF" '[.evidence[]? | select(.ref==$r)] | length' "$LDIR/entries.jsonl" | awk '{s+=$1} END{print s+0}')"
if [ -n "$D_REF" ] && [ "$D_CAND_ISMISS" = "false" ] && [ "$D_LEDGER_HITS" = 0 ]; then
  ok "AC-13 (d) own-gate candidate: present in digest+candidates as is_miss:false, no ledger entry"
else
  fail "AC-13 (d) negative control (ref='$D_REF' cand_ismiss=$D_CAND_ISMISS ledger_hits=$D_LEDGER_HITS)"
fi

REPORT13="$(sw "$LDIR" report)"
case "$REPORT13" in
  *"entries: 3 ("*"bytes)"*) ok "AC-13 report prints entry count + entries.jsonl byte size" ;;
  *) fail "AC-13 report entries line (got: $REPORT13)" ;;
esac

# ============================================================
# AC-14 — sweep re-run idempotent (same corpus, no new source data)
# ============================================================

full_sweep "$LDIR" "$SRC" "$REPO" "$EPIC"
LC14="$(lc "$LDIR/entries.jsonl")"
if [ "$LC14" = 3 ]; then
  ok "AC-14 rerun with no new source data appends zero new entries"
else
  fail "AC-14 rerun idempotent (lc=$LC14, want 3)"
fi

# ============================================================
# AC-21 — cross-source incident merge (L2)
# ============================================================

read -r LDIR SRC REPO EPIC <<<"$(mkscene ac21)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
mk_git_repo "$REPO" "fix: correct the K1 defect TESTHINT:K1 chain"
mk_epic "$EPIC" "root cause TESTHINT:K1 missing"

full_sweep "$LDIR" "$SRC" "$REPO" "$EPIC"

LC21="$(lc "$LDIR/entries.jsonl")"
KINDS21="$(jq -c '[.evidence[].kind] | sort' "$LDIR/entries.jsonl" 2>/dev/null)"
if [ "$LC21" = 1 ] && [ "$KINDS21" = '["git","reckoning","transcript"]' ]; then
  ok "AC-21 three sources sharing TESTHINT:K1 merge into ONE entry with 3-kind evidence[]"
else
  fail "AC-21 merge (lc=$LC21 kinds=$KINDS21)"
fi

GIT_REF21="$(jq -r '.evidence[] | select(.kind=="git") | .ref' "$LDIR/entries.jsonl")"
# label_json always builds a transcript-kind evidence entry; this re-offer
# needs a git-kind one (the SAME ref/kind pairing the merged entry already
# carries), so it's built directly rather than via that helper.
RELABEL="$(jq -nc --arg r "$GIT_REF21" '{what:"re-offer", caught_by:"human", should_have:"design-review", gap_class:"missing-AC", evidence:[{kind:"git", ref:$r}]}')"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$W" --label "$RELABEL" >/dev/null 2>&1
LC21B="$(lc "$LDIR/entries.jsonl")"
if [ "$LC21B" = 1 ]; then
  ok "AC-21 re-offer of one merged ref is a writer no-op"
else
  fail "AC-21 re-offer no-op (lc=$LC21B)"
fi

# ============================================================
# AC-16a — L0 stage failure: skip-and-report, other sources proceed,
# scan-state untouched for the failed source
# ============================================================

read -r LDIR SRC REPO EPIC <<<"$(mkscene ac16a)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
mk_epic "$EPIC" "root cause TESTHINT:K9 missing"
BOGUS="$TMP/ac16a-notarepo"; mkdir -p "$BOGUS"

mkdir -p "$LDIR"
SEED_STATE='{"git":{"/somewhere":{"last_swept":"deadbeef"}}}'
printf '%s\n' "$SEED_STATE" > "$LDIR/scan-state.json"
BEFORE_STATE="$(cat "$LDIR/scan-state.json")"

sw "$LDIR" collect "$SRC" "$BOGUS" "$EPIC" >/dev/null
AFTER_STATE="$(cat "$LDIR/scan-state.json")"

if [ "$BEFORE_STATE" = "$AFTER_STATE" ]; then
  ok "AC-16a scan-state.json untouched by a failed git source"
else
  fail "AC-16a scan-state mutated (before=$BEFORE_STATE after=$AFTER_STATE)"
fi

REPORT16A="$(sw "$LDIR" report)"
case "$REPORT16A" in
  *"sweep incomplete: git"*) ok "AC-16a report carries 'sweep incomplete: git'" ;;
  *) fail "AC-16a report missing incomplete line (got: $REPORT16A)" ;;
esac

if grep -qx transcript "$LDIR/.sweep-consumed" && grep -qx reckoning "$LDIR/.sweep-consumed" && grep -qx firelog "$LDIR/.sweep-consumed"; then
  ok "AC-16a other sources (transcript/reckoning/firelog) still proceed"
else
  fail "AC-16a other sources not consumed ($(cat "$LDIR/.sweep-consumed" 2>/dev/null | tr '\n' ' '))"
fi
if grep -qx git "$LDIR/.sweep-consumed" 2>/dev/null; then
  fail "AC-16a git incorrectly marked consumed"
else
  ok "AC-16a git NOT marked consumed"
fi

# ============================================================
# AC-16b-l1 — invalid candidate (is_miss:true missing gap_class) is an L1
# stage failure: non-zero exit, no staging, no ledger write, scan-state
# unchanged, "sweep incomplete: l1"
# ============================================================

LDIR="$(mkl ac16bl1)"
cat > "$LDIR/.candidates-log.jsonl" <<'EOF'
{"schema":"candidate/v1","ref":"transcript:/x#1-2","is_miss":true,"caught_by":"live-probe","should_have":"design-review"}
EOF
SEED_STATE_L1='{"transcripts":{"/x":{"cursor":9}}}'
printf '%s\n' "$SEED_STATE_L1" > "$LDIR/scan-state.json"
BEFORE_L1="$(cat "$LDIR/scan-state.json")"

TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" validate-candidates >/dev/null 2>&1
RC_L1=$?
AFTER_L1="$(cat "$LDIR/scan-state.json")"

if [ "$RC_L1" -ne 0 ] && [ ! -e "$LDIR/.staging.jsonl" ]; then
  ok "AC-16b-l1 invalid candidate (missing gap_class) -> validate-candidates fails, no staging"
else
  fail "AC-16b-l1 validate-candidates (rc=$RC_L1 staging_exists=$([ -e "$LDIR/.staging.jsonl" ] && echo yes || echo no))"
fi
if [ ! -e "$LDIR/entries.jsonl" ] || [ ! -s "$LDIR/entries.jsonl" ]; then
  ok "AC-16b-l1 ledger unchanged (no write)"
else
  fail "AC-16b-l1 ledger written unexpectedly"
fi
if [ "$BEFORE_L1" = "$AFTER_L1" ]; then
  ok "AC-16b-l1 scan-state unchanged"
else
  fail "AC-16b-l1 scan-state mutated"
fi
REPORT_L1="$(TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" report)"
case "$REPORT_L1" in
  *"sweep incomplete: l1"*) ok "AC-16b-l1 report carries 'sweep incomplete: l1'" ;;
  *) fail "AC-16b-l1 report missing l1 line (got: $REPORT_L1)" ;;
esac

# ============================================================
# AC-16b-l2 — LEDGER_L2_CMD failure: staging discarded, ledger unchanged,
# scan-state untouched, "sweep incomplete: l2"
# ============================================================

LDIR="$(mkl ac16bl2)"
cat > "$LDIR/.candidates-log.jsonl" <<'EOF'
{"schema":"candidate/v1","ref":"transcript:/x#1-2","is_miss":true,"caught_by":"live-probe","should_have":"design-review","gap_class":"missing-AC"}
EOF
cat > "$LDIR/.digest.jsonl" <<'EOF'
{"schema":"digest/v1","source":"transcript","ref":"transcript:/x#1-2","ts":"t","payload":{"text":"TESTHINT:K9 whatever","interrupt_pair":false}}
EOF
SEED_STATE_L2='{"transcripts":{"/x":{"cursor":9}}}'
printf '%s\n' "$SEED_STATE_L2" > "$LDIR/scan-state.json"
BEFORE_L2="$(cat "$LDIR/scan-state.json")"

TOUCHSTONE_LEDGER_DIR="$LDIR" LEDGER_L2_CMD=false bash "$SWEEP" stage >/dev/null 2>&1
RC_L2=$?
AFTER_L2="$(cat "$LDIR/scan-state.json")"

if [ "$RC_L2" -ne 0 ] && [ ! -e "$LDIR/.staging.jsonl" ]; then
  ok "AC-16b-l2 LEDGER_L2_CMD=false -> stage fails, staging gone"
else
  fail "AC-16b-l2 stage (rc=$RC_L2 staging_exists=$([ -e "$LDIR/.staging.jsonl" ] && echo yes || echo no))"
fi
if [ ! -e "$LDIR/entries.jsonl" ] || [ ! -s "$LDIR/entries.jsonl" ]; then
  ok "AC-16b-l2 ledger unchanged"
else
  fail "AC-16b-l2 ledger written unexpectedly"
fi
if [ "$BEFORE_L2" = "$AFTER_L2" ]; then
  ok "AC-16b-l2 scan-state unchanged"
else
  fail "AC-16b-l2 scan-state mutated"
fi
REPORT_L2="$(TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" report)"
case "$REPORT_L2" in
  *"sweep incomplete: l2"*) ok "AC-16b-l2 report carries 'sweep incomplete: l2'" ;;
  *) fail "AC-16b-l2 report missing l2 line (got: $REPORT_L2)" ;;
esac

# ============================================================
# F1 — classify() checks LEDGER_L1_CMD's exit status per chunk: a failing
# command over a non-empty digest fails classify (rc!=0), records
# "sweep incomplete: l1", the subsequent finalize refuses (phase-sequencing
# guard), and scan-state.json stays byte-identical throughout.
# ============================================================

LDIR="$(mkl l1cmdfail)"
cat > "$LDIR/.digest.jsonl" <<'EOF'
{"schema":"digest/v1","source":"transcript","ref":"transcript:/x#1-2","ts":"t","payload":{"text":"whatever"}}
EOF
SEED_STATE_L1CMD='{"transcripts":{"/x":{"cursor":9}}}'
printf '%s\n' "$SEED_STATE_L1CMD" > "$LDIR/scan-state.json"
BEFORE_L1CMD="$(cat "$LDIR/scan-state.json")"

TOUCHSTONE_LEDGER_DIR="$LDIR" LEDGER_L1_CMD=false bash "$SWEEP" classify >/dev/null 2>&1
RC_L1CMD=$?

if [ "$RC_L1CMD" -ne 0 ]; then
  ok "F1 classify: LEDGER_L1_CMD failure over a non-empty digest returns non-zero"
else
  fail "F1 classify: LEDGER_L1_CMD failure did not fail (rc=$RC_L1CMD)"
fi
if grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete" 2>/dev/null; then
  ok "F1 classify: LEDGER_L1_CMD failure records 'sweep incomplete: l1'"
else
  fail "F1 classify: incomplete file missing the l1 line"
fi

TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" finalize >/dev/null 2>&1
RC_L1CMD_FIN=$?
AFTER_L1CMD="$(cat "$LDIR/scan-state.json")"
if [ "$RC_L1CMD_FIN" -ne 0 ]; then
  ok "F1 classify: subsequent finalize refuses after the recorded l1 failure"
else
  fail "F1 classify: finalize did not refuse (rc=$RC_L1CMD_FIN)"
fi
if [ "$BEFORE_L1CMD" = "$AFTER_L1CMD" ]; then
  ok "F1 classify: scan-state byte-identical after the LEDGER_L1_CMD failure"
else
  fail "F1 classify: scan-state mutated after the LEDGER_L1_CMD failure"
fi

# ============================================================
# F2a — classify() checks output-line-count against input-line-count per
# chunk, not just exit status: LEDGER_L1_CMD=true (a valid command, exit 0,
# ZERO output) over a non-empty digest is an L1 shortfall failure (rc!=0),
# records "sweep incomplete: l1", the subsequent finalize refuses, and
# scan-state.json stays byte-identical throughout.
# ============================================================

LDIR="$(mkl l1zerooutput)"
cat > "$LDIR/.digest.jsonl" <<'EOF'
{"schema":"digest/v1","source":"transcript","ref":"transcript:/z#1-2","ts":"t","payload":{"text":"whatever"}}
EOF
SEED_STATE_F2A='{"transcripts":{"/z":{"cursor":9}}}'
printf '%s\n' "$SEED_STATE_F2A" > "$LDIR/scan-state.json"
BEFORE_F2A="$(cat "$LDIR/scan-state.json")"

TOUCHSTONE_LEDGER_DIR="$LDIR" LEDGER_L1_CMD=true bash "$SWEEP" classify >/dev/null 2>&1
RC_F2A=$?

if [ "$RC_F2A" -ne 0 ]; then
  ok "F2a classify: LEDGER_L1_CMD=true (exit-0, zero output) over a non-empty digest returns non-zero"
else
  fail "F2a classify: exit-0 zero-output did not fail (rc=$RC_F2A)"
fi
if grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete" 2>/dev/null; then
  ok "F2a classify: exit-0 zero-output records 'sweep incomplete: l1'"
else
  fail "F2a classify: incomplete file missing the l1 line"
fi

TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" finalize >/dev/null 2>&1
RC_F2A_FIN=$?
AFTER_F2A="$(cat "$LDIR/scan-state.json")"
if [ "$RC_F2A_FIN" -ne 0 ]; then
  ok "F2a classify: subsequent finalize refuses after the recorded l1 failure"
else
  fail "F2a classify: finalize did not refuse (rc=$RC_F2A_FIN)"
fi
if [ "$BEFORE_F2A" = "$AFTER_F2A" ]; then
  ok "F2a classify: scan-state byte-identical after the exit-0 zero-output failure"
else
  fail "F2a classify: scan-state mutated after the exit-0 zero-output failure"
fi

# ============================================================
# F2b — same output-shortfall check catches a PARTIAL-output command (emits
# fewer candidate lines than input records, not just zero): classify rc!=0,
# "sweep incomplete: l1" recorded.
# ============================================================

LDIR="$(mkl l1partialoutput)"
cat > "$LDIR/.digest.jsonl" <<'EOF'
{"schema":"digest/v1","source":"transcript","ref":"transcript:/p#1-2","ts":"t","payload":{"text":"line one"}}
{"schema":"digest/v1","source":"transcript","ref":"transcript:/p#3-4","ts":"t","payload":{"text":"line two"}}
EOF

TOUCHSTONE_LEDGER_DIR="$LDIR" LEDGER_L1_CMD="$L1_PARTIAL" bash "$SWEEP" classify >/dev/null 2>&1
RC_F2B=$?

if [ "$RC_F2B" -ne 0 ]; then
  ok "F2b classify: partial-output stub (1 line for a 2-line chunk) returns non-zero"
else
  fail "F2b classify: partial-output shortfall did not fail (rc=$RC_F2B)"
fi
if grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete" 2>/dev/null; then
  ok "F2b classify: partial-output shortfall records 'sweep incomplete: l1'"
else
  fail "F2b classify: incomplete file missing the l1 line"
fi
CANDLC_F2B="$(lc "$LDIR/.candidates-log.jsonl")"
if [ "$CANDLC_F2B" = 1 ]; then
  ok "F2b classify: the one candidate line the stub DID emit is still retained (inspectable artifact)"
else
  fail "F2b classify: candidates-log line count unexpected (lc=$CANDLC_F2B)"
fi

# ============================================================
# AC-17 — label/sweep converge in either order, first writer wins
# ============================================================

# (a) label first (ranged ref), sweep second -> dedupes, source stays label
read -r LDIR SRC _ _ <<<"$(mkscene ac17a)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
ABS_SRC_A="$(cd "$SRC" && pwd)/sess1.jsonl"

TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$W" --label "$(label_json "human caught the K1 defect" "transcript:$ABS_SRC_A#0-999999")" >/dev/null
full_sweep "$LDIR" "$SRC" "" ""

LC17A="$(lc "$LDIR/entries.jsonl")"
SRC17A="$(jq -r 'select(.evidence[].ref | test("^transcript:")) | .source' "$LDIR/entries.jsonl" | head -1)"
if [ "$LC17A" = 1 ] && [ "$SRC17A" = "label" ]; then
  ok "AC-17(a) label-first: sweep dedupes against the label, source stays label"
else
  fail "AC-17(a) (lc=$LC17A src=$SRC17A)"
fi

# (b) sweep first, later overlapping-ranged label -> no-op, source stays sweep
read -r LDIR SRC _ _ <<<"$(mkscene ac17b)"
cp "$FIXTURE" "$SRC/sess1.jsonl"
ABS_SRC_B="$(cd "$SRC" && pwd)/sess1.jsonl"

full_sweep "$LDIR" "$SRC" "" ""
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$W" --label "$(label_json "late label" "transcript:$ABS_SRC_B#0-999999")" >/dev/null

LC17B="$(lc "$LDIR/entries.jsonl")"
SRC17B="$(jq -r 'select(.evidence[].ref | test("^transcript:")) | .source' "$LDIR/entries.jsonl" | head -1)"
if [ "$LC17B" = 1 ] && [ "$SRC17B" = "sweep:transcript" ]; then
  ok "AC-17(b) sweep-first: later overlapping label is a no-op, source stays sweep"
else
  fail "AC-17(b) (lc=$LC17B src=$SRC17B)"
fi

# ============================================================
# Visible-skip semantics — collect() records unconfigured sources (not
# just silently omitting them), and report() names them
# ============================================================

LDIR="$(mkl skipvis)"
sw "$LDIR" collect >/dev/null
REPORT_SKIP="$(sw "$LDIR" report)"
case "$REPORT_SKIP" in
  *"sources skipped (unconfigured): transcript git reckoning"*)
    ok "visible-skip: report names transcript/git/reckoning as unconfigured-skipped when only firelog is configured" ;;
  *) fail "visible-skip report missing skipped line (got: $REPORT_SKIP)" ;;
esac

# ============================================================
# Phase-sequencing guard — stage refuses to run when this run's
# .sweep-incomplete already carries an l1 (validate-candidates) failure
# ============================================================

LDIR="$(mkl seqguard)"
cat > "$LDIR/.candidates-log.jsonl" <<'EOF'
{"schema":"candidate/v1","ref":"transcript:/x#1-2","is_miss":true,"caught_by":"live-probe","should_have":"design-review"}
EOF
SEED_STATE_SEQ='{"transcripts":{"/x":{"cursor":9}}}'
printf '%s\n' "$SEED_STATE_SEQ" > "$LDIR/scan-state.json"
BEFORE_SEQ="$(cat "$LDIR/scan-state.json")"

TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" validate-candidates >/dev/null 2>&1
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" stage >/dev/null 2>&1
RC_SEQ=$?
AFTER_SEQ="$(cat "$LDIR/scan-state.json")"

if [ "$RC_SEQ" -ne 0 ] && [ ! -e "$LDIR/.staging.jsonl" ]; then
  ok "phase-sequencing: stage refuses to run after a recorded l1 failure"
else
  fail "phase-sequencing stage refusal (rc=$RC_SEQ staging_exists=$([ -e "$LDIR/.staging.jsonl" ] && echo yes || echo no))"
fi
if [ ! -e "$LDIR/entries.jsonl" ] || [ ! -s "$LDIR/entries.jsonl" ]; then
  ok "phase-sequencing: ledger untouched after refused stage"
else
  fail "phase-sequencing: ledger written unexpectedly after refused stage"
fi
if [ "$BEFORE_SEQ" = "$AFTER_SEQ" ]; then
  ok "phase-sequencing: scan-state untouched after refused stage"
else
  fail "phase-sequencing: scan-state mutated after refused stage"
fi

# ============================================================
# merge_cursor_proposals POSITIVE coverage — one successful full sweep
# (real firelog extraction) plus seeded propose files for two more sources
# merges all of them into scan-state.json, leaving a pre-existing sibling
# section untouched
# ============================================================

LDIR="$(mkl mergepos)"
cat > "$LDIR/fire-log.jsonl" <<'EOF'
{"schema":"fire-event/v1","check":"c1","ts":"2026-07-01T00:00:00Z"}
EOF
PRE_MERGE_STATE='{"unrelated":{"marker":"stays"}}'
printf '%s\n' "$PRE_MERGE_STATE" > "$LDIR/scan-state.json"

sw "$LDIR" collect >/dev/null
sw "$LDIR" classify >/dev/null
sw "$LDIR" validate-candidates >/dev/null
sw "$LDIR" stage >/dev/null

# synthetic propose files for transcript+git — these two sources weren't
# actually configured for this sweep (no TESTHINT in the firelog fixture
# either, so nothing is is_miss:true), but merge_cursor_proposals commits
# by FILE PRESENCE, not by which sources ran this sweep; seeding them here
# exercises the >=2-source merge path without a real transcript/git corpus.
echo '{"/synthetic/transcript/path":{"cursor":123}}' > "$LDIR/.propose-transcript.json"
echo '{"/synthetic/git/repo":{"cursor":456}}' > "$LDIR/.propose-git.json"

sw "$LDIR" finalize >/dev/null
RC_MERGE=$?

TRANSCRIPTS_SECTION="$(jq -c '.transcripts // {}' "$LDIR/scan-state.json")"
GIT_SECTION="$(jq -c '.git // {}' "$LDIR/scan-state.json")"
FIRELOG_NONEMPTY="$(jq -r '(.firelog // {}) | length > 0' "$LDIR/scan-state.json")"
UNRELATED_SECTION="$(jq -c '.unrelated // {}' "$LDIR/scan-state.json")"

if [ "$RC_MERGE" -eq 0 ] \
  && [ "$TRANSCRIPTS_SECTION" = '{"/synthetic/transcript/path":{"cursor":123}}' ] \
  && [ "$GIT_SECTION" = '{"/synthetic/git/repo":{"cursor":456}}' ] \
  && [ "$FIRELOG_NONEMPTY" = "true" ]; then
  ok "merge-proposals: finalize merges transcript+git+firelog proposals into scan-state.json"
else
  fail "merge-proposals: sections wrong (rc=$RC_MERGE transcripts=$TRANSCRIPTS_SECTION git=$GIT_SECTION firelog_nonempty=$FIRELOG_NONEMPTY)"
fi
if [ "$UNRELATED_SECTION" = '{"marker":"stays"}' ]; then
  ok "merge-proposals: pre-existing sibling section untouched by the merge"
else
  fail "merge-proposals: sibling section disturbed (got: $UNRELATED_SECTION)"
fi

# ============================================================
# MIXED-batch writer test (Task-2 carried item) — staging with one valid +
# one invalid line: finalize fails the WHOLE batch at the real caller
# (ledger-append.sh's two-pass validation), ledger unchanged. Also seeds
# propose files + a pre-existing scan-state (merge_cursor_proposals
# NEGATIVE coverage) so the byte-identical assertion actually exercises
# that a rejected batch never reaches the cursor-commit step.
# ============================================================

LDIR="$(mkl mixedbatch)"
{
  jq -nc '{schema:"catch-miss/v1", caught_by:"human", should_have:"design-review", gap_class:"missing-AC",
           what:"valid one", evidence:[{kind:"git", ref:"git:mixed1"}], source:"sweep:git"}'
  jq -nc '{schema:"catch-miss/v1", caught_by:"human", should_have:"design-review", gap_class:"not-a-real-enum-value",
           what:"invalid one", evidence:[{kind:"git", ref:"git:mixed2"}], source:"sweep:git"}'
} > "$LDIR/.staging.jsonl"
echo '{"/mixed/transcript/path":{"cursor":111}}' > "$LDIR/.propose-transcript.json"
echo '{"/mixed/git/repo":{"cursor":222}}' > "$LDIR/.propose-git.json"
PRE_MIXED_STATE='{"unrelated":{"marker":"stays"}}'
printf '%s\n' "$PRE_MIXED_STATE" > "$LDIR/scan-state.json"
BEFORE_MIXED="$(cat "$LDIR/scan-state.json")"

TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" finalize >/dev/null 2>&1
RC_MIXED=$?
AFTER_MIXED="$(cat "$LDIR/scan-state.json")"
if [ "$RC_MIXED" -ne 0 ] && [ ! -e "$LDIR/.staging.jsonl" ] && { [ ! -e "$LDIR/entries.jsonl" ] || [ ! -s "$LDIR/entries.jsonl" ]; } && [ "$BEFORE_MIXED" = "$AFTER_MIXED" ]; then
  ok "MIXED-batch: finalize fails the whole batch (writer's real whole-batch semantics), ledger + scan-state (incl. seeded propose files) unchanged"
else
  fail "MIXED-batch (rc=$RC_MIXED staging_exists=$([ -e "$LDIR/.staging.jsonl" ] && echo yes || echo no) scan_state_changed=$([ "$BEFORE_MIXED" = "$AFTER_MIXED" ] && echo no || echo yes))"
fi

echo "== $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
