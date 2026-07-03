#!/usr/bin/env bash
# Facts-writer suite: proposal/v1 + resolution/v1 validation, whole-batch
# rejection, referential witness checks, derived-field recompute, lock +
# nested-gitignore self-heal. Spec joins: AC-1, AC-2, AC-3, AC-4, AC-7, AC-12.
# SC2015: `[ ] && ok || fail` idiom intentional (ok never fails).
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
W="$REPO_ROOT/scripts/proposal/facts-append.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# mkrepo <name> — a scratch git repo with a ledger dir; echoes the LEDGER dir
mkrepo() {
  local r="$TMP/$1"; mkdir -p "$r"
  git -C "$r" init -q
  mkdir -p "$r/.touchstone/ledger"
  echo "$r/.touchstone/ledger"
}

# mkentry <ledger-dir> <id> <ts> [git-sha]
mkentry() {
  local d="$1" id="$2" ts="$3" sha="${4:-}"
  local ref="transcript:/t.jsonl#0-10"
  [ -n "$sha" ] && ref="git:$sha"
  jq -nc --arg id "$id" --arg ts "$ts" --arg ref "$ref" \
    '{schema:"catch-miss/v1", id:$id, ts:$ts, caught_by:"human",
      should_have:"design-review", gap_class:"missing-AC", what:("w-"+$id),
      evidence:[{kind:"x", ref:$ref}], source:"label"}' >> "$d/entries.jsonl"
}

# prop <id> <witness-csv> [jq-override] — a well-formed proposal line
prop() {
  local id="$1" w="$2" ov="${3:-.}"
  jq -nc --arg id "$id" --argjson w "$(printf '%s' "$w" | jq -R 'split(",")')" \
    '{schema:"proposal/v1", id:$id, ts:"2026-07-03T01:00:00Z", scope:"local",
      unit_type:"checker", title:("t-"+$id), class_desc:("c-"+$id),
      benefit_witness:$w,
      cost_witness:{kind:"replay", corpus:"r1..r2, 2 commits", fires:2, hits:2},
      auto_install_eligible:false, body_ref:("proposals/"+$id+"/proposal.md")}' \
  | jq -c "$ov"
}

# res <pid> <kind> [jq-override]
res() {
  local pid="$1" kind="$2" ov="${3:-.}"
  jq -nc --arg pid "$pid" --arg k "$kind" \
    '{schema:"resolution/v1", ts:"2026-07-03T02:00:00Z", proposal_id:$pid,
      entry_ids:[], kind:$k}
     | if $k=="installed" then .proof={fire_exit:2,pass_exit:0,
         checked_at:"2026-07-03T02:00:00Z",
         installed_path:".touchstone/checker/pre-commit/check-x.sh"} else . end
     | if $k=="install-failed" then .triage="infra" | .note="n" else . end' \
  | jq -c "$ov"
}

assert_rejected() { # <label> <mode> <ledger-dir> <json...>
  local label="$1" mode="$2" d="$3"; shift 3
  local tgt="$d/${mode}s.jsonl" before after err rc
  before="$([ -f "$tgt" ] && wc -c < "$tgt" || echo 0)"
  err="$(printf '%s\n' "$@" | TOUCHSTONE_LEDGER_DIR="$d" bash "$W" "$mode" 2>&1 1>/dev/null)"; rc=$?
  after="$([ -f "$tgt" ] && wc -c < "$tgt" || echo 0)"
  [ "$rc" -ne 0 ] && [ "$before" = "$after" ] && [ -n "$err" ] \
    && ok "$label" || fail "$label (rc=$rc err='$err')"
}
assert_accepted() { # <label> <mode> <ledger-dir> <json...>
  local label="$1" mode="$2" d="$3"; shift 3
  printf '%s\n' "$@" | TOUCHSTONE_LEDGER_DIR="$d" bash "$W" "$mode" >/dev/null 2>&1 \
    && ok "$label" || fail "$label"
}

# --- exec bits (carried invariant: SKILL-invoked scripts committed 100755) ---
for s in proposal-lib.sh facts-append.sh; do
  [ -x "$REPO_ROOT/scripts/proposal/$s" ] && ok "exec bit: $s" || fail "exec bit: $s"
done

# --- AC-1: valid proposal appended, derived fields recomputed ---
L="$(mkrepo ac1)"
mkentry "$L" e1 2026-07-01T00:00:00Z
mkentry "$L" e2 2026-07-02T00:00:00Z
assert_accepted "AC-1 valid proposal appends" proposal "$L" \
  "$(prop p1 "e1,e2" '.recurrence=99 | .latest_entry_ts="1999-01-01T00:00:00Z" | .auto_install_eligible=false')"
GOT="$(tail -1 "$L/proposals.jsonl")"
[ "$(echo "$GOT" | jq -r .recurrence)" = 2 ] && ok "AC-1 recurrence recomputed" || fail "AC-1 recurrence"
[ "$(echo "$GOT" | jq -r .latest_entry_ts)" = "2026-07-02T00:00:00Z" ] && ok "AC-1 latest_entry_ts recomputed" || fail "AC-1 latest_entry_ts"
[ "$(echo "$GOT" | jq -r .auto_install_eligible)" = true ] && ok "AC-1 eligibility recomputed" || fail "AC-1 eligibility"

# --- AC-12: eligibility conjunction (writer-recomputed) ---
E="$(mkrepo ac12)"
for i in 1 2 3 4 5 6 7 8 9; do mkentry "$E" "e$i" "2026-07-01T00:00:0${i}Z"; done
elig() { tail -1 "$E/proposals.jsonl" | jq -r .auto_install_eligible; }
assert_accepted "AC-12a append" proposal "$E" "$(prop a e1 '.cost_witness.fires=2 | .cost_witness.hits=2')"
[ "$(elig)" = true ]  && ok "AC-12a checker/local 2==2 eligible" || fail "AC-12a"
assert_accepted "AC-12b append" proposal "$E" "$(prop b e2 '.cost_witness.fires=3 | .cost_witness.hits=2 | .cost_witness.samples=["deadbee"]')"
[ "$(elig)" = false ] && ok "AC-12b extra fire not eligible" || fail "AC-12b"
assert_accepted "AC-12c append" proposal "$E" "$(prop c e3 '.cost_witness.fires=0 | .cost_witness.hits=0')"
[ "$(elig)" = false ] && ok "AC-12c vacuous 0==0 not eligible" || fail "AC-12c"
assert_accepted "AC-12d append" proposal "$E" "$(prop d e4 '.scope="upstream"')"
[ "$(elig)" = false ] && ok "AC-12d upstream never eligible" || fail "AC-12d"
assert_accepted "AC-12e append" proposal "$E" "$(prop e e5 '.unit_type="claude-md-rule"')"
[ "$(elig)" = false ] && ok "AC-12e non-checker not eligible" || fail "AC-12e"
# AC-11 writer side: declared cost witness accepted, never eligible
assert_accepted "AC-11 declared append" proposal "$E" "$(prop f e6 '.cost_witness={kind:"declared", note:"live-session-only behavior"}')"
[ "$(elig)" = false ] && ok "AC-11 declared not eligible" || fail "AC-11"

# --- AC-3: ten whole-batch rejections ---
B="$(mkrepo ac3)"
mkentry "$B" e1 2026-07-01T00:00:00Z
mkentry "$B" e2 2026-07-01T00:00:01Z
mkentry "$B" e3 2026-07-01T00:00:02Z
assert_accepted "AC-3 setup: base proposal" proposal "$B" "$(prop pb e1)"
assert_accepted "AC-3 setup: non-checker proposal" proposal "$B" "$(prop pn e3 '.unit_type="memory" | .cost_witness={kind:"declared",note:"n"}')"
# resolution-mode invalids (i)-(vii)
# (i) also pins the error contract: the message names the offending LINE and field
before="$(wc -c < "$B/resolutions.jsonl" 2>/dev/null || echo 0)"
# shellcheck disable=SC1010  # "done" here is a string arg to res(), not the loop keyword
ERR="$(printf '%s\n' "$(res pb accepted)" "$(res pb done)" "$(res pb accepted)" \
  | TOUCHSTONE_LEDGER_DIR="$B" bash "$W" resolution 2>&1 1>/dev/null)"; rc=$?
after="$(wc -c < "$B/resolutions.jsonl" 2>/dev/null || echo 0)"
[ "$rc" -ne 0 ] && [ "$before" = "$after" ] && ok "AC-3(i) kind=done in 3-line batch rejected whole" || fail "AC-3(i) rc=$rc"
echo "$ERR" | grep -q 'line 2' && ok "AC-3(i) error names the offending line" || fail "AC-3(i) line: '$ERR'"
echo "$ERR" | grep -q 'kind' && ok "AC-3(i) error names the field" || fail "AC-3(i) field: '$ERR'"
assert_rejected "AC-3(ii) installed without proof" resolution "$B" "$(res pb installed 'del(.proof)')"
assert_rejected "AC-3(iii) accepted carrying triage" resolution "$B" "$(res pb accepted '.triage="infra"')"
assert_rejected "AC-3(iv) install-failed without triage" resolution "$B" "$(res pb install-failed 'del(.triage)')"
assert_rejected "AC-3(v) entry_ids outside witness" resolution "$B" "$(res pb accepted '.entry_ids=["e2"]')"
assert_rejected "AC-3(vi) completed on checker" resolution "$B" "$(res pb completed)"
assert_rejected "AC-3(vii) installed on non-checker" resolution "$B" "$(res pn installed)"
# proposal-mode invalids (viii)-(x)
assert_rejected "AC-3(viii) unit_type=hook" proposal "$B" "$(prop px e2 '.unit_type="hook"')"
assert_rejected "AC-3(ix) cost_witness kind=guessed" proposal "$B" "$(prop py e2 '.cost_witness={kind:"guessed",note:"n"}')"
assert_rejected "AC-3(x) empty class_desc" proposal "$B" "$(prop pz e2 '.class_desc=""')"

# --- AC-2: valid resolutions of every kind ---
assert_accepted "AC-2 accepted" resolution "$B" "$(res pb accepted '.entry_ids=["e1"]')"
assert_accepted "AC-2 installed+proof" resolution "$B" "$(res pb installed)"
assert_accepted "AC-2 revoked" resolution "$B" "$(res pb revoked)"
assert_accepted "AC-2 completed on non-checker" resolution "$B" "$(res pn completed)"
assert_rejected "AC-2 unknown proposal_id" resolution "$B" "$(res nope accepted)"

# --- AC-7: witness must exist, be open, and be unclaimed ---
S="$(mkrepo ac7)"
mkentry "$S" e1 2026-07-01T00:00:00Z
mkentry "$S" e2 2026-07-01T00:00:01Z
mkentry "$S" e3 2026-07-01T00:00:02Z
assert_rejected "AC-7 empty witness" proposal "$S" "$(prop q1 e1 '.benefit_witness=[]')"
assert_rejected "AC-7 nonexistent entry id" proposal "$S" "$(prop q2 ghost)"
assert_accepted "AC-7 setup: p-cover claims e1" proposal "$S" "$(prop pcov e1)"
assert_accepted "AC-7 setup: accept+install closes e1" resolution "$S" \
  "$(res pcov accepted '.entry_ids=["e1"]')" "$(res pcov installed '.entry_ids=["e1"]')"
assert_rejected "AC-7 closed entry (installed)" proposal "$S" "$(prop q3 e1)"
assert_accepted "AC-7 setup: pending p-pend claims e2" proposal "$S" "$(prop ppend e2)"
assert_rejected "AC-7 pending-claimed entry" proposal "$S" "$(prop q4 e2)"
assert_accepted "AC-7 open entry e3 fine" proposal "$S" "$(prop q5 e3)"

# --- id-uniqueness (reviewer finding on Task 1): a caller-supplied .id must
# not silently collide with an id already in the target file, nor with
# another line of the SAME batch — a collision would let validate_resolution's
# `select(.id==$id) | tail -1` proposal lookup join against the wrong record.
U="$(mkrepo idu)"
mkentry "$U" e1 2026-07-01T00:00:00Z
mkentry "$U" e2 2026-07-01T00:00:01Z
mkentry "$U" e3 2026-07-01T00:00:02Z
assert_accepted "id-uniqueness setup: pu1 committed" proposal "$U" "$(prop pu1 e1)"
# (a) id already present in proposals.jsonl
ERR="$(printf '%s\n' "$(prop pu1 e2)" | TOUCHSTONE_LEDGER_DIR="$U" bash "$W" proposal 2>&1 1>/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && ok "id reuse: existing proposal id rejected" || fail "id reuse: existing proposal id rc=$rc"
echo "$ERR" | grep -q 'field: id' && ok "id reuse: existing proposal id names field id" || fail "id reuse: existing proposal id field: '$ERR'"
[ "$(wc -l < "$U/proposals.jsonl")" -eq 1 ] && ok "id reuse: existing proposal id — nothing written" || fail "id reuse: existing proposal id wrote extra line"
# (b) two lines of ONE batch sharing an id
ERR="$(printf '%s\n' "$(prop pu2 e2)" "$(prop pu2 e3)" | TOUCHSTONE_LEDGER_DIR="$U" bash "$W" proposal 2>&1 1>/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && ok "id reuse: batch-internal duplicate id rejected" || fail "id reuse: batch dup rc=$rc"
echo "$ERR" | grep -q 'field: id' && ok "id reuse: batch-internal duplicate names field id" || fail "id reuse: batch dup field: '$ERR'"
[ "$(wc -l < "$U/proposals.jsonl")" -eq 1 ] && ok "id reuse: batch dup — nothing written" || fail "id reuse: batch dup wrote extra line"
# (c) resolution id already present in resolutions.jsonl
assert_accepted "id-uniqueness setup: ru1 committed" resolution "$U" "$(res pu1 accepted '.id="ru1" | .entry_ids=["e1"]')"
ERR="$(printf '%s\n' "$(res pu1 revoked '.id="ru1"')" | TOUCHSTONE_LEDGER_DIR="$U" bash "$W" resolution 2>&1 1>/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && ok "id reuse: existing resolution id rejected" || fail "id reuse: existing resolution id rc=$rc"
echo "$ERR" | grep -q 'field: id' && ok "id reuse: existing resolution id names field id" || fail "id reuse: existing resolution id field: '$ERR'"
[ "$(wc -l < "$U/resolutions.jsonl")" -eq 1 ] && ok "id reuse: existing resolution id — nothing written" || fail "id reuse: existing resolution id wrote extra line"

# --- AC-4: append-only + nested gitignore self-heal + lock ---
G="$(mkrepo ac4)"
mkentry "$G" e1 2026-07-01T00:00:00Z
mkentry "$G" e2 2026-07-01T00:00:01Z
assert_accepted "AC-4 setup r1" proposal "$G" "$(prop r1 e1)"
assert_accepted "AC-4 setup r2" proposal "$G" "$(prop r2 e2)"
rm -f "$G/.gitignore"
head -2 "$G/proposals.jsonl" > "$TMP/ac4-before"
# a third valid append heals the gitignore and never rewrites prior records
mkentry "$G" e3 2026-07-01T00:00:02Z
assert_accepted "AC-4 valid append" proposal "$G" "$(prop r3 e3)"
head -2 "$G/proposals.jsonl" > "$TMP/ac4-after"
cmp -s "$TMP/ac4-before" "$TMP/ac4-after" && ok "AC-4 prior records byte-identical" || fail "AC-4 byte-identical"
[ -f "$G/.gitignore" ] && ok "AC-4 nested gitignore restored" || fail "AC-4 gitignore"
R="$(cd "$G/../.." && pwd)"
TRACKABLE="$(git -C "$R" status --porcelain -- .touchstone/ledger/ 2>/dev/null | grep -c . || true)"
[ "${TRACKABLE:-0}" -eq 0 ] && ok "AC-4 ledger family not trackable" || fail "AC-4 trackable=$TRACKABLE"
# lock contention: alive-holder lock times out non-zero, no partial write
mkdir "$G/.lock"; echo $$ > "$G/.lock/pid"
before="$(wc -c < "$G/proposals.jsonl")"
mkentry "$G" e4 2026-07-01T00:00:03Z
printf '%s\n' "$(prop r4 e4)" | TOUCHSTONE_LEDGER_DIR="$G" TOUCHSTONE_LEDGER_LOCK_TIMEOUT=1 \
  bash "$W" proposal >/dev/null 2>&1
rc=$?
after="$(wc -c < "$G/proposals.jsonl")"
[ "$rc" -ne 0 ] && [ "$before" = "$after" ] && ok "AC-4 lock contention exits non-zero, no partial write" || fail "AC-4 lock (rc=$rc)"
rm -rf "$G/.lock"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
