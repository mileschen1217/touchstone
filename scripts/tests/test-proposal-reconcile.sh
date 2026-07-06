#!/usr/bin/env bash
# reconcile.sh suite: read-only joins, raw-since-first-install fire counts,
# recurrence flagging. Spec joins: AC-17, AC-18.
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RC="$REPO_ROOT/scripts/proposal/reconcile.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[ -x "$RC" ] && ok "exec bit: reconcile.sh" || fail "exec bit"
L="$TMP/ledger"; mkdir -p "$L/runs/r1"
echo data > "$L/runs/r1/staging.jsonl"

ent() { jq -nc --arg id "$1" --arg ts "$2" --arg sh "$3" --arg gc "$4" \
  '{schema:"catch-miss/v1", id:$id, ts:$ts, caught_by:"human", should_have:$sh,
    gap_class:$gc, what:$id, evidence:[{kind:"x",ref:("t:"+$id)}], source:"label"}' >> "$L/entries.jsonl"; }
prop() { jq -nc --arg id "$1" --arg ut "$2" --argjson w "$3" \
  '{schema:"proposal/v1", id:$id, ts:"2026-07-01T00:00:00Z", scope:"local", unit_type:$ut,
    title:("T-"+$id), class_desc:"c", benefit_witness:$w,
    cost_witness:{kind:"declared",note:"n"}, auto_install_eligible:false,
    body_ref:"b"}' >> "$L/proposals.jsonl"; }
res() { printf '%s\n' "$1" >> "$L/resolutions.jsonl"; }
fire() { jq -nc --arg ts "$1" --arg c "$2" \
  '{schema:"fire-event/v1", ts:$ts, check:$c, repo:"/r", stage:"pre-commit"}' >> "$L/fire-log.jsonl"; }

ent e1 2026-07-01T00:00:00Z design-review missing-AC
ent e2 2026-07-01T00:00:01Z code-review:batch false-green
# AC-17 fixtures:
prop pa checker '["e1"]'                       # accepted checker, never installed (+1 failed attempt)
res '{"schema":"resolution/v1","id":"ra1","ts":"2026-07-01T01:00:00Z","proposal_id":"pa","entry_ids":["e1"],"kind":"accepted"}'
res '{"schema":"resolution/v1","id":"ra2","ts":"2026-07-01T02:00:00Z","proposal_id":"pa","entry_ids":["e1"],"kind":"install-failed","triage":"infra","note":"n"}'
prop pb memory '["e2"]'                        # accepted non-checker, completed → closed
res '{"schema":"resolution/v1","id":"rb1","ts":"2026-07-01T01:00:00Z","proposal_id":"pb","entry_ids":["e2"],"kind":"accepted"}'
res '{"schema":"resolution/v1","id":"rb2","ts":"2026-07-01T02:00:00Z","proposal_id":"pb","entry_ids":["e2"],"kind":"completed","note":"done by hand"}'
prop pc checker '["e1"]'                       # rejected
res '{"schema":"resolution/v1","id":"rc1","ts":"2026-07-01T01:00:00Z","proposal_id":"pc","entry_ids":[],"kind":"rejected"}'
prop pd checker '["e2"]'                       # installed at T; 3 fires after, 1 phantom before
res '{"schema":"resolution/v1","id":"rd1","ts":"2026-07-02T00:00:00Z","proposal_id":"pd","entry_ids":["e2"],"kind":"accepted"}'
res '{"schema":"resolution/v1","id":"rd2","ts":"2026-07-02T01:00:00Z","proposal_id":"pd","entry_ids":["e2"],"kind":"installed","proof":{"fire_exit":2,"pass_exit":0,"checked_at":"2026-07-02T01:00:00Z","installed_path":".touchstone/checker/pre-commit/check-pd.sh"}}'
fire 2026-07-02T00:30:00Z check-pd.sh          # phantom: predates installed ts
fire 2026-07-02T02:00:00Z check-pd.sh
fire 2026-07-02T03:00:00Z check-pd.sh
fire 2026-07-02T04:00:00Z check-pd.sh

before="$(find "$L" -type f -exec md5 -q {} \; 2>/dev/null | sort | md5 -q)"
OUT="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$RC")"
rc=$?
after="$(find "$L" -type f -exec md5 -q {} \; 2>/dev/null | sort | md5 -q)"
[ "$rc" -eq 0 ] && ok "AC-17 reconcile exits 0" || fail "AC-17 rc=$rc"
[ "$before" = "$after" ] && ok "AC-17 ledger dir byte-identical" || fail "AC-17 mutated"
echo "$OUT" | grep -q 'pa — T-pa' && ok "AC-17 accepted-never-installed listed by id+title" || fail "AC-17 pa: $OUT"
echo "$OUT" | grep -q 'triage=infra' && ok "AC-17 failed attempt with triage shown" || fail "AC-17 triage"
echo "$OUT" | grep 'pb' | grep -qv completed && fail "AC-17 completed non-checker flagged" || ok "AC-17 completed not flagged"
echo "$OUT" | grep -q 'rejected: 1' && ok "AC-17 rejected count" || fail "AC-17 rejected"
echo "$OUT" | grep -q 'check-pd.sh (pd): fires=3' && ok "AC-17 fire count 3 (pre-install phantom excluded)" || fail "AC-17 fires: $OUT"
echo "$OUT" | grep -q 'total size:' && ok "AC-17 runs/ size line" || fail "AC-17 runs size"

# --- AC-18: post-resolution recurrence flagged, never auto-marked ---
ent e9 2026-07-03T00:00:00Z design-review missing-AC   # same class as e1 (covered by ra1 at T)
OUT="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$RC")"
echo "$OUT" | grep -q 'possible recurrence' && ok "AC-18 recurrence section present" || fail "AC-18 section"
echo "$OUT" | grep 'possible recurrence' -A 20 | grep -q 'e9' && ok "AC-18 new entry id listed" || fail "AC-18 e9"
echo "$OUT" | grep 'e9' | grep -q 'ra1' && ok "AC-18 resolution id paired" || fail "AC-18 pair"
grep -q 'recurrence-fact' "$L/resolutions.jsonl" 2>/dev/null && fail "AC-18 auto-marked" || ok "AC-18 not auto-adjudicated"
# pa has TWO resolution facts over e1 (ra1 accepted, ra2 install-failed) covering
# the same class as e9 — must collapse to exactly one line, keeping the earliest.
n_e9="$(echo "$OUT" | grep -c 'new entry e9')"
[ "$n_e9" -eq 1 ] && ok "AC-18 dedupe: exactly one line for e9" || fail "AC-18 dedupe: n=$n_e9"
echo "$OUT" | grep 'new entry e9' | grep -q 'ra1' && ok "AC-18 dedupe: keeps earliest resolution ra1" || fail "AC-18 dedupe: earliest"
echo "$OUT" | grep 'new entry e9' | grep -qv 'ra2' && ok "AC-18 dedupe: drops later resolution ra2" || fail "AC-18 dedupe: ra2 leaked"

# --- regression: two proposals sharing a basename collapse into ONE grouped
# line (raw counts are keyed by basename — never double-attributed); the
# pre-existing single-proposal fixture line (check-pd.sh) must stay unchanged.
prop pe checker '["e1"]'
res '{"schema":"resolution/v1","id":"re1","ts":"2026-07-02T05:00:00Z","proposal_id":"pe","entry_ids":["e1"],"kind":"accepted"}'
res '{"schema":"resolution/v1","id":"re2","ts":"2026-07-02T05:30:00Z","proposal_id":"pe","entry_ids":["e1"],"kind":"installed","proof":{"fire_exit":2,"pass_exit":0,"checked_at":"2026-07-02T05:30:00Z","installed_path":".touchstone/checker/pre-commit/check-shared.sh"}}'
prop pf checker '["e2"]'
res '{"schema":"resolution/v1","id":"rf1","ts":"2026-07-02T06:00:00Z","proposal_id":"pf","entry_ids":["e2"],"kind":"accepted"}'
res '{"schema":"resolution/v1","id":"rf2","ts":"2026-07-02T06:30:00Z","proposal_id":"pf","entry_ids":["e2"],"kind":"installed","proof":{"fire_exit":2,"pass_exit":0,"checked_at":"2026-07-02T06:30:00Z","installed_path":".touchstone/checker/pre-push/check-shared.sh"}}'
OUT2="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$RC")"
n_shared="$(echo "$OUT2" | grep -c 'check-shared.sh')"
[ "$n_shared" -eq 1 ] && ok "shared basename: one grouped line" || fail "shared basename: n=$n_shared: $OUT2"
echo "$OUT2" | grep 'check-shared.sh' | grep -q '(pe, pf)' \
  && ok "shared basename: both proposals named" || fail "shared basename: proposals: $OUT2"
echo "$OUT2" | grep 'check-shared.sh' | grep -q 'since 2026-07-02T05:30:00Z' \
  && ok "shared basename: earliest install ts kept" || fail "shared basename: ts: $OUT2"
echo "$OUT2" | grep -q 'check-pd.sh (pd): fires=3' \
  && ok "shared basename: pre-existing check-pd.sh line unchanged" \
  || fail "shared basename: check-pd.sh line changed: $OUT2"

# --- regression (the phantom-filtering defect): a real fire AFTER a stale
# revoked fact still counts — raw attribution has no revoke upper bound.
# (Live case: check-version-bump revoked in the ledger 14:38:31Z while the
# file stayed live and fired 15:10:46Z; the windowed join reported fires=0.)
prop pg checker '["e1"]'
res '{"schema":"resolution/v1","id":"rg1","ts":"2026-07-02T07:00:00Z","proposal_id":"pg","entry_ids":["e1"],"kind":"accepted"}'
res '{"schema":"resolution/v1","id":"rg2","ts":"2026-07-02T07:30:00Z","proposal_id":"pg","entry_ids":["e1"],"kind":"installed","proof":{"fire_exit":2,"pass_exit":0,"checked_at":"2026-07-02T07:30:00Z","installed_path":".touchstone/checker/pre-commit/check-pg.sh"}}'
res '{"schema":"resolution/v1","id":"rg3","ts":"2026-07-02T08:00:00Z","proposal_id":"pg","entry_ids":["e1"],"kind":"revoked","note":"n"}'
fire 2026-07-02T09:00:00Z check-pg.sh          # fires AFTER the revoked fact
OUT3="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$RC")"
echo "$OUT3" | grep -q 'check-pg.sh (pg): fires=1' \
  && ok "post-revoke fire counted (raw, no window zeroing)" || fail "post-revoke fire: $OUT3"

# --- fire events with no installed fact are reported, never hidden ---
fire 2026-07-02T10:00:00Z check-orphan.sh
OUT4="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$RC")"
echo "$OUT4" | grep -A 3 'no installed fact' | grep -q 'check-orphan.sh: fires=1' \
  && ok "orphan fire event surfaced in its own section" || fail "orphan fire: $OUT4"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
