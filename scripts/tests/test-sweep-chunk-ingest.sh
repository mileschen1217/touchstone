#!/usr/bin/env bash
# test-sweep-chunk-ingest.sh — S2-1: the `chunk` / `ingest` subcommands match
# the manual close-procedure semantics: recall-preserving prefilter before
# chunking, line-safe 200KB split, per-chunk shortfall detection (including
# empty-out and missing-out), the EXACT `sweep incomplete: l1` literal, and
# the sequencing guard refusing stage after an ingest failure.
# SC2015: the `[ ] && ok || fail` idiom is intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SWEEP="$REPO_ROOT/scripts/ledger/sweep-run.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mk_ledger() { # fresh ledger dir with a digest of $1 signal records + noise
  local n="$1" ldir="$TMP/ledger-$RANDOM"
  mkdir -p "$ldir"
  {
    local i
    for i in $(seq 1 "$n"); do
      printf '{"schema":"digest/v1","ref":"t:%s","source":"transcript","ts":"2026-07-10T00:00:0%sZ","payload":{"text":"real correction %s"}}\n' "$i" "$((i%10))" "$i"
    done
    # structurally-empty records the prefilter must drop
    printf '{"schema":"digest/v1","ref":"t:blank","source":"transcript","ts":"2026-07-10T00:00:00Z","payload":{"text":"  "}}\n'
    printf '{"schema":"digest/v1","ref":"t:cmd","source":"transcript","ts":"2026-07-10T00:00:00Z","payload":{"text":"/compact"}}\n'
  } > "$ldir/.digest.jsonl"
  echo "$ldir"
}

# (a) chunk: prefilter runs, survivors chunked, paths printed, drops logged
LDIR="$(mk_ledger 3)"
out="$(TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk)"; rc=$?
n_paths="$(printf '%s\n' "$out" | grep -c .)"
{ [ "$rc" -eq 0 ] && [ "$n_paths" -eq 1 ] && [ -s "$(printf '%s\n' "$out" | head -1)" ]; } \
  && ok "(a) chunk prints 1 chunk path, exit 0" || fail "(a) rc=$rc paths=$n_paths out=$out"
surv="$(grep -c . "$LDIR/.digest-classify.jsonl")"
drop="$(grep -c . "$LDIR/.prefilter-dropped.jsonl")"
{ [ "$surv" -eq 3 ] && [ "$drop" -eq 2 ]; } \
  && ok "(a2) prefilter kept 3 / dropped 2 before chunking" || fail "(a2) surv=$surv drop=$drop"

# (a3) accounting line goes to stderr, chunk paths stay clean on stdout
err="$(TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk 2>&1 >/dev/null)"
printf '%s' "$err" | grep -q 'pre-filter: 3 classified, 2 dropped' \
  && ok "(a3) pre-filter accounting line on stderr" || fail "(a3) err=$err"

# (b) chunk splits >200KB survivor sets line-safely into >=2 chunks
LDIR2="$TMP/ledger-big"; mkdir -p "$LDIR2"
bigline="$(printf 'x%.0s' $(seq 1 60000))"
for i in 1 2 3 4 5; do
  printf '{"schema":"digest/v1","ref":"g:%s","source":"git","ts":"2026-07-10T00:00:00Z","payload":{"text":"%s"}}\n' "$i" "$bigline"
done > "$LDIR2/.digest.jsonl"
out="$(TOUCHSTONE_LEDGER_DIR="$LDIR2" bash "$SWEEP" chunk)"; rc=$?
n_paths="$(printf '%s\n' "$out" | grep -c .)"
whole="$(cat "$LDIR2"/.chunks/chunk-* | grep -c .)"
{ [ "$rc" -eq 0 ] && [ "$n_paths" -ge 2 ] && [ "$whole" -eq 5 ]; } \
  && ok "(b) big survivors split into $n_paths chunks, no line lost/split" || fail "(b) rc=$rc paths=$n_paths whole=$whole"

# (c) ingest happy path: out lines == in lines → exit 0, candidates appended, no incomplete
LDIR="$(mk_ledger 3)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null
for i in 1 2 3; do
  printf '{"schema":"candidate/v1","ref":"t:%s","is_miss":false}\n' "$i"
done > "$LDIR/.chunks/out-0.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1; rc=$?
cands="$(grep -c . "$LDIR/.candidates-log.jsonl")"
{ [ "$rc" -eq 0 ] && [ "$cands" -eq 3 ] && [ ! -s "$LDIR/.sweep-incomplete" ]; } \
  && ok "(c) ingest happy path → exit 0, 3 candidates, no incomplete" || fail "(c) rc=$rc cands=$cands"

# (d) shortfall (out < in) → exit nonzero + EXACT literal line
LDIR="$(mk_ledger 3)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null
printf '{"schema":"candidate/v1","ref":"t:1","is_miss":false}\n' > "$LDIR/.chunks/out-0.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete"; } \
  && ok "(d) shortfall → nonzero + exact 'sweep incomplete: l1'" || fail "(d) rc=$rc incomplete=$(cat "$LDIR/.sweep-incomplete" 2>/dev/null)"

# (e) exit-0-but-empty out file is the same failure class
LDIR="$(mk_ledger 2)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null
: > "$LDIR/.chunks/out-0.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete"; } \
  && ok "(e) empty out file → nonzero + l1 literal" || fail "(e) rc=$rc"

# (f) missing out file → same failure class
LDIR="$(mk_ledger 2)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete"; } \
  && ok "(f) missing out file → nonzero + l1 literal" || fail "(f) rc=$rc"

# (g) sequencing guard: after ingest failure, stage refuses
LDIR="$(mk_ledger 2)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1
TOUCHSTONE_LEDGER_DIR="$LDIR" LEDGER_L2_CMD="cat" bash "$SWEEP" stage >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && ok "(g) stage refuses after ingest l1 failure" || fail "(g) stage rc=$rc"

# (i) ingest with an EXPLICIT dir argument (the advertised `ingest [dir]` path)
LDIR="$(mk_ledger 2)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null 2>&1
alt="$TMP/alt-chunks"; cp -R "$LDIR/.chunks" "$alt"
for i in 1 2; do printf '{"schema":"candidate/v1","ref":"t:%s","is_miss":false}\n' "$i"; done > "$alt/out-0.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest "$alt" >/dev/null 2>&1; rc=$?
cands="$(grep -c . "$LDIR/.candidates-log.jsonl")"
{ [ "$rc" -eq 0 ] && [ "$cands" -eq 2 ]; } \
  && ok "(i) explicit-dir ingest → exit 0, 2 candidates" || fail "(i) rc=$rc cands=$cands"

# (n) RECOVERY PATH (the documented retry): shortfall → fix out file →
# re-run ingest → l1 cleared, no duplicate candidates → stage proceeds
LDIR="$(mk_ledger 3)"
echo "sweep incomplete: git" > "$LDIR/.sweep-incomplete"   # unrelated L0 line must survive
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null 2>&1
printf '{"schema":"candidate/v1","ref":"t:1","is_miss":false}\n' > "$LDIR/.chunks/out-0.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1   # fails, records l1
for i in 1 2 3; do printf '{"schema":"candidate/v1","ref":"t:%s","is_miss":false}\n' "$i"; done > "$LDIR/.chunks/out-0.jsonl"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1; rc=$?
cands="$(grep -c . "$LDIR/.candidates-log.jsonl")"
{ [ "$rc" -eq 0 ] && [ "$cands" -eq 3 ] \
  && ! grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete" \
  && grep -qxF "sweep incomplete: git" "$LDIR/.sweep-incomplete"; } \
  && ok "(n) re-ingest after fix → l1 cleared, no dupes, L0 line preserved" \
  || fail "(n) rc=$rc cands=$cands incomplete=[$(cat "$LDIR/.sweep-incomplete" 2>/dev/null)]"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" validate-candidates >/dev/null 2>&1 \
  && TOUCHSTONE_LEDGER_DIR="$LDIR" LEDGER_L2_CMD="cat" bash "$SWEEP" stage >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] && ok "(n2) validate+stage proceed after recovery" || fail "(n2) rc=$rc"

# (o) chunks dir empty while survivors exist → failure (stale/mismatched state)
LDIR="$(mk_ledger 2)"
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" chunk >/dev/null 2>&1
rm -f "$LDIR/.chunks/"chunk-*
TOUCHSTONE_LEDGER_DIR="$LDIR" bash "$SWEEP" ingest >/dev/null 2>&1; rc=$?
{ [ "$rc" -ne 0 ] && grep -qxF "sweep incomplete: l1" "$LDIR/.sweep-incomplete"; } \
  && ok "(o) empty chunk dir + nonempty survivors → l1 failure" || fail "(o) rc=$rc"

# (h) empty digest → chunk prints nothing, exit 0
LDIR3="$TMP/ledger-empty"; mkdir -p "$LDIR3"; : > "$LDIR3/.digest.jsonl"
out="$(TOUCHSTONE_LEDGER_DIR="$LDIR3" bash "$SWEEP" chunk)"; rc=$?
{ [ "$rc" -eq 0 ] && [ -z "$out" ]; } \
  && ok "(h) empty digest → no paths, exit 0" || fail "(h) rc=$rc out=$out"

echo "== test-sweep-chunk-ingest: $pass ok, $fail fail =="
[ "$fail" -eq 0 ]
