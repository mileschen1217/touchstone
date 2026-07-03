#!/usr/bin/env bash
# report.sh suite: open-entry latest-fact semantics, freshness banner,
# ranking + quota, digest fields. Spec joins: AC-5, AC-6, AC-8, AC-9, AC-11.
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
R="$REPO_ROOT/scripts/proposal/report.sh"
W="$REPO_ROOT/scripts/proposal/facts-append.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[ -x "$R" ] && ok "exec bit: report.sh" || fail "exec bit: report.sh"

mkl() { local d="$TMP/$1"; mkdir -p "$d"; git -C "$TMP" init -q 2>/dev/null || true; echo "$d"; }
ent() { # <dir> <id> <ts>
  jq -nc --arg id "$2" --arg ts "$3" '{schema:"catch-miss/v1", id:$id, ts:$ts,
    caught_by:"human", should_have:"design-review", gap_class:"missing-AC",
    what:$id, evidence:[{kind:"x", ref:("t:"+$id)}], source:"label"}' >> "$1/entries.jsonl"
}
rawres() { # <dir> <json> — resolutions written raw (fixture bypass is fine for reads)
  printf '%s\n' "$2" >> "$1/resolutions.jsonl"
}

# --- AC-5: open set, latest-fact rule ---
L="$(mkl ac5)"
for i in 1 2 3 4 5 6 7; do ent "$L" "e$i" "2026-07-01T00:00:0${i}Z"; done
# pending proposal claims e3 (raw write is fine: report only reads)
printf '%s\n' "$(jq -nc '{schema:"proposal/v1", id:"pp", ts:"2026-07-02T00:00:00Z",
  scope:"local", unit_type:"checker", title:"t", class_desc:"c",
  benefit_witness:["e3"], recurrence:1, latest_entry_ts:"", cost_witness:{kind:"declared",note:"n"},
  auto_install_eligible:false, body_ref:"b"}')" >> "$L/proposals.jsonl"
rawres "$L" '{"schema":"resolution/v1","id":"r1","ts":"2026-07-02T01:00:00Z","proposal_id":"px","entry_ids":["e1","e2"],"kind":"installed","proof":{"fire_exit":2,"pass_exit":0,"checked_at":"x","installed_path":"p"}}'
rawres "$L" '{"schema":"resolution/v1","id":"r2","ts":"2026-07-02T02:00:00Z","proposal_id":"px","entry_ids":["e2"],"kind":"revoked"}'
rawres "$L" '{"schema":"resolution/v1","id":"r3","ts":"2026-07-02T03:00:00Z","proposal_id":"py","entry_ids":["e7"],"kind":"rejected"}'
GOT="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$R" open-entries 2>/dev/null | jq -r '.id' | sort | tr '\n' ' ' | sed 's/ $//')"
[ "$GOT" = "e2 e4 e5 e6" ] && ok "AC-5 open set = e2,e4,e5,e6 (latest-fact; rejected stays closed)" || fail "AC-5 got '$GOT'"

# --- AC-6: freshness banner stderr + digest header; 'never' when absent ---
BAN="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$R" open-entries 2>&1 >/dev/null)"
echo "$BAN" | grep -q '^last sweep finalize: never$' && ok "AC-6 banner 'never' when stamp absent" || fail "AC-6 never: '$BAN'"
echo "2026-07-03T05:00:00Z" > "$L/.last-finalize"
BAN="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$R" open-entries 2>&1 >/dev/null)"
echo "$BAN" | grep -q '^last sweep finalize: 2026-07-03T05:00:00Z$' && ok "AC-6 banner names stamp T" || fail "AC-6 T: '$BAN'"
DIG="$(TOUCHSTONE_LEDGER_DIR="$L" bash "$R" digest)"
[ "$(echo "$DIG" | head -1)" = "last sweep finalize: 2026-07-03T05:00:00Z" ] \
  && ok "AC-6 digest header repeats banner" || fail "AC-6 digest header"

# --- AC-8: ranking + quota over 7 pending proposals (writer-composed) ---
K="$(mkl ac8)"
for i in 01 02 03 04 05 06 07 08 09 10 11; do ent "$K" "n$i" "2026-07-01T00:00:${i}Z"; done
mkp() { # <id> <witness-csv>
  jq -nc --arg id "$1" --argjson w "$(printf '%s' "$2" | jq -R 'split(",")')" \
    '{schema:"proposal/v1", id:$id, ts:"2026-07-02T00:00:00Z", scope:"local",
      unit_type:"checker", title:("T-"+$id), class_desc:("C-"+$id), benefit_witness:$w,
      cost_witness:{kind:"declared", note:"n"}, auto_install_eligible:false,
      body_ref:("proposals/"+$id+"/proposal.md")}' \
  | TOUCHSTONE_LEDGER_DIR="$K" bash "$W" proposal
}
mkp pa "n01,n02,n03"   # rec 3
mkp pb "n04,n05"       # rec 2, latest n05
mkp pc "n06,n07"       # rec 2, latest n07 (newer than pb) → pc before pb
mkp pd "n08"           # rec 1, ts .08
mkp pf "n09"           # rec 1, ts .09
mkp pe "n10"           # rec 1, ts .10
mkp pg "n11"           # rec 1, ts .11
# the FULL-TIE pair (same recurrence AND same latest_entry_ts, distinguishable
# only by proposal id): two entries sharing one ts, later than every n* entry —
# so pz1/pz2 rank directly after the rec-2 group and render in id order.
ent "$K" tie1 "2026-07-01T00:01:00Z"
ent "$K" tie2 "2026-07-01T00:01:00Z"
mkp pz2 tie2
mkp pz1 tie1
DIG="$(TOUCHSTONE_PROPOSAL_QUOTA=5 TOUCHSTONE_LEDGER_DIR="$K" bash "$R" digest)"
ORDER="$(echo "$DIG" | grep '^## ' | sed 's/^## T-\([a-z0-9]*\).*/\1/' | tr '\n' ' ' | sed 's/ $//')"
# expected: pa(3) pc(2,newer) pb(2) pz1/pz2 full-tie by id asc — pz1 < pz2
[ "$ORDER" = "pa pc pb pz1 pz2" ] && ok "AC-8 order recurrence>ts>id, quota 5" || fail "AC-8 order '$ORDER'"
echo "$DIG" | grep -q '^4 more recorded below quota$' && ok "AC-8 footer counts remainder" || fail "AC-8 footer"

# --- AC-9 / AC-11: digest block fields; no raw entry dump ---
BLOCK="$(echo "$DIG" | sed -n '/^## T-pa/,/^$/p')"
echo "$BLOCK" | grep -q 'class: C-pa' && ok "AC-9 class_desc" || fail "AC-9 class_desc"
echo "$BLOCK" | grep -q 'recurrence: 3 (n01, n02, n03)' && ok "AC-9 recurrence+ids" || fail "AC-9 recurrence"
echo "$BLOCK" | grep -q 'cost: declared: n' && ok "AC-9 cost summary" || fail "AC-9 cost"
echo "$BLOCK" | grep -q '\[needs-your-call\]' && ok "AC-11 declared renders needs-your-call" || fail "AC-11 tag"
echo "$BLOCK" | grep -q 'body: proposals/pa/proposal.md' && ok "AC-9 body_ref" || fail "AC-9 body_ref"
echo "$DIG" | jq -R 'fromjson? | select(.schema=="catch-miss/v1")' | grep -q . \
  && fail "AC-9 raw entry dumped into digest" || ok "AC-9 no catch-miss/v1 line in digest"

# digest empty states: absent ledger / all-closed corpus / open-but-unproposed
EM="$(mkl empty)"
OUT="$(TOUCHSTONE_LEDGER_DIR="$EM" bash "$R" digest)"
echo "$OUT" | grep -q 'no open entries — run the sweep first' && ok "absent ledger digest message" || fail "empty digest: $OUT"
AC="$(mkl allclosed)"
ent "$AC" c1 2026-07-01T00:00:00Z
rawres "$AC" '{"schema":"resolution/v1","id":"rz","ts":"2026-07-02T00:00:00Z","proposal_id":"pz","entry_ids":["c1"],"kind":"installed","proof":{"fire_exit":2,"pass_exit":0,"checked_at":"x","installed_path":"p"}}'
OUT="$(TOUCHSTONE_LEDGER_DIR="$AC" bash "$R" digest)"
echo "$OUT" | grep -q 'no open entries — run the sweep first' && ok "all-closed corpus digest message" || fail "all-closed digest: $OUT"
OP="$(mkl opennoprop)"
ent "$OP" o1 2026-07-01T00:00:00Z
OUT="$(TOUCHSTONE_LEDGER_DIR="$OP" bash "$R" digest)"
echo "$OUT" | grep -q 'no pending proposals' && ok "open-but-unproposed digest message" || fail "open-no-pending digest: $OUT"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
