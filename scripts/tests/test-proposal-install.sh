#!/usr/bin/env bash
# install.sh suite: guards, two-sided self-proof, rollback + triage, revoke.
# Spec joins: AC-13, AC-14, AC-15, AC-16, AC-25, AC-26, AC-27.
# The hook under proof is the REAL hooks/run-project-checks.sh.
# shellcheck disable=SC2015
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
I="$REPO_ROOT/scripts/proposal/install.sh"
W="$REPO_ROOT/scripts/proposal/facts-append.sh"
pass=0; fail=0
ok()   { pass=$((pass+1)); echo "ok   - $1"; }
fail() { fail=$((fail+1)); echo "FAIL - $1"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[ -x "$I" ] && ok "exec bit: install.sh" || fail "exec bit"

# mkworld <name> — scratch "real repo" + ledger + one open entry; echoes repo root
mkworld() {
  local r="$TMP/$1"; mkdir -p "$r"
  git -C "$r" init -q
  git -C "$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  mkdir -p "$r/.touchstone/ledger"
  jq -nc '{schema:"catch-miss/v1", id:"e1", ts:"2026-07-01T00:00:00Z", caught_by:"human",
    should_have:"design-review", gap_class:"missing-AC", what:"w",
    evidence:[{kind:"x", ref:"t:e1"}], source:"label"}' > "$r/.touchstone/ledger/entries.jsonl"
  echo "$r"
}

# mksidecar <repo> <pid> <stage> <check-body-file> — sidecar with the standard
# fire fixture (scratch repo carrying an OFFENDING marker file)
mksidecar() {
  local r="$1" pid="$2" stage="$3" body="$4"
  local s="$r/.touchstone/ledger/proposals/$pid"; mkdir -p "$s"
  printf -- '---\nstage: %s\ncheck_name: probe\n---\nmechanism prose\n' "$stage" > "$s/proposal.md"
  cp "$body" "$s/draft-check.sh"
  cat > "$s/fire-fixture.sh" <<'EOS'
#!/usr/bin/env bash
set -eu
T="$(mktemp -d)"
git -C "$T" init -q
git -C "$T" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
touch "$T/OFFENDING"
git -C "$T" rev-parse --show-toplevel
EOS
}

# mkprop <repo> <pid> [scope] [unit_type] — proposal fact + accepted fact
mkprop() {
  local r="$1" pid="$2" scope="${3:-local}" ut="${4:-checker}"
  jq -nc --arg id "$pid" --arg sc "$scope" --arg ut "$ut" \
    '{schema:"proposal/v1", id:$id, ts:"2026-07-02T00:00:00Z", scope:$sc, unit_type:$ut,
      title:"t", class_desc:"c", benefit_witness:["e1"],
      cost_witness:{kind:"replay", fires:1, hits:1}, auto_install_eligible:false,
      body_ref:("proposals/"+$id+"/proposal.md")}' \
    | TOUCHSTONE_LEDGER_DIR="$r/.touchstone/ledger" bash "$W" proposal
}
accept() { # <repo> <pid>
  jq -nc --arg pid "$2" '{schema:"resolution/v1", ts:"2026-07-02T01:00:00Z",
    proposal_id:$pid, entry_ids:["e1"], kind:"accepted"}' \
    | TOUCHSTONE_LEDGER_DIR="$1/.touchstone/ledger" bash "$W" resolution
}
run_install() { # <repo> <args...>
  local r="$1"; shift
  TOUCHSTONE_LEDGER_DIR="$r/.touchstone/ledger" bash "$I" "$@"
}
lastres() { tail -1 "$1/.touchstone/ledger/resolutions.jsonl"; }

# the standard well-behaved check: bites iff OFFENDING exists in the repo
GOOD="$TMP/good-check.sh"
cat > "$GOOD" <<'EOS'
#!/usr/bin/env bash
top="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
if [ -f "$top/OFFENDING" ]; then
  echo "offending marker present"
  exit 1
fi
exit 0
EOS

# --- AC-13: happy path — write, chmod, two-sided proof, fact ---
R1="$(mkworld happy)"
mkprop "$R1" p1; accept "$R1" p1; mksidecar "$R1" p1 pre-commit "$GOOD"
run_install "$R1" p1 >/dev/null 2>&1 && ok "AC-13 install exits 0" || fail "AC-13 rc"
TGT="$R1/.touchstone/checker/pre-commit/check-probe.sh"
[ -f "$TGT" ] && ok "AC-13 check landed at stage path" || fail "AC-13 path"
[ -x "$TGT" ] && ok "AC-13 mode is executable" || fail "AC-13 mode"
F="$(lastres "$R1")"
[ "$(echo "$F" | jq -r .kind)" = installed ] && ok "AC-13 installed fact" || fail "AC-13 fact kind"
[ "$(echo "$F" | jq -r .proof.fire_exit)" = 2 ] && [ "$(echo "$F" | jq -r .proof.pass_exit)" = 0 ] \
  && ok "AC-13 proof carries both exit codes" || fail "AC-13 proof exits"
[ "$(echo "$F" | jq -r .proof.installed_path)" = ".touchstone/checker/pre-commit/check-probe.sh" ] \
  && ok "AC-13 proof names installed path" || fail "AC-13 proof path"
echo "$F" | jq -e '.proof.checked_at' >/dev/null && ok "AC-13 proof timestamped" || fail "AC-13 ts"

# --- AC-26: refuse without accepted fact ---
R2="$(mkworld noaccept)"
mkprop "$R2" p2; mksidecar "$R2" p2 pre-commit "$GOOD"
ERR="$(run_install "$R2" p2 2>&1 >/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && echo "$ERR" | grep -q accepted && ok "AC-26 refuses, names missing accepted fact" || fail "AC-26 rc=$rc '$ERR'"
[ ! -e "$R2/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "AC-26 nothing written" || fail "AC-26 wrote"
grep -q install-failed "$R2/.touchstone/ledger/resolutions.jsonl" 2>/dev/null \
  && fail "AC-26 must append no fact" || ok "AC-26 no fact appended"

# --- AC-27: mechanical boundary guards ---
R3="$(mkworld guards)"
mkprop "$R3" pu upstream; accept "$R3" pu; mksidecar "$R3" pu pre-commit "$GOOD"
run_install "$R3" pu >/dev/null 2>&1 && fail "AC-27 upstream must refuse" || ok "AC-27 scope=upstream refused"
mkprop "$R3" pr local claude-md-rule; accept "$R3" pr
run_install "$R3" pr >/dev/null 2>&1 && fail "AC-27 non-checker must refuse" || ok "AC-27 unit_type refused"
run_install "$R3" --revoke pu >/dev/null 2>&1 && fail "AC-27 revoke-without-install must refuse" || ok "AC-27 revoke guard"
[ ! -d "$R3/.touchstone/checker" ] && ok "AC-27 nothing under checker/" || fail "AC-27 checker dir touched"
N="$(grep -cE '"kind":"(installed|install-failed|revoked)"' "$R3/.touchstone/ledger/resolutions.jsonl" 2>/dev/null || true)"
[ "${N:-0}" -eq 0 ] && ok "AC-27 no fact appended" || fail "AC-27 facts=$N"

# --- AC-15: fire-side failure (check never bites) — real repo untouched ---
R4="$(mkworld fireside)"
PASSIVE="$TMP/passive.sh"; printf '#!/usr/bin/env bash\nexit 0\n' > "$PASSIVE"
mkprop "$R4" p4; accept "$R4" p4; mksidecar "$R4" p4 pre-commit "$PASSIVE"
run_install "$R4" p4 >/dev/null 2>&1 && fail "AC-15 must fail" || ok "AC-15 fire-side failure non-zero"
[ ! -e "$R4/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "AC-15 real repo never written" || fail "AC-15 wrote"
F="$(lastres "$R4")"
[ "$(echo "$F" | jq -r .kind)" = install-failed ] && ok "AC-15 install-failed fact" || fail "AC-15 kind"
T="$(echo "$F" | jq -r .triage)"
{ [ "$T" = spec-violation-fixed ] || [ "$T" = class-definition-wrong ]; } \
  && ok "AC-15 grounded triage ($T)" || fail "AC-15 triage=$T"
[ -n "$(echo "$F" | jq -r '.note // empty')" ] && ok "AC-15 grounding note present" || fail "AC-15 note"

# --- regression: facts-append failure while recording install-failed must not
# claim a fact was recorded. Reuse the AC-15 fire-side-failure scenario but
# hold the writer lock first so facts-append fails deterministically.
R8="$(mkworld lockfail)"
mkprop "$R8" p8; accept "$R8" p8; mksidecar "$R8" p8 pre-commit "$PASSIVE"
LOCKDIR="$R8/.touchstone/ledger/.lock"
mkdir "$LOCKDIR"; echo $$ > "$LOCKDIR/pid"
export TOUCHSTONE_LEDGER_LOCK_TIMEOUT=1
ERR="$(run_install "$R8" p8 2>&1 >/dev/null)"; rc=$?
unset TOUCHSTONE_LEDGER_LOCK_TIMEOUT
rm -rf "$LOCKDIR"
[ "$rc" -ne 0 ] && ok "regression: lock-held install still exits non-zero" || fail "regression: rc=$rc"
[ ! -e "$R8/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "regression: real repo untouched" || fail "regression: wrote"
grep -q install-failed "$R8/.touchstone/ledger/resolutions.jsonl" 2>/dev/null \
  && fail "regression: install-failed fact must NOT be recorded (lock held)" || ok "regression: no install-failed fact appended"
echo "$ERR" | grep -q "fact recorded" && fail "regression: stderr falsely claims fact recorded ($ERR)" || ok "regression: stderr does not claim fact recorded"
echo "$ERR" | grep -q "WARNING" && ok "regression: stderr carries WARNING" || fail "regression: stderr missing WARNING ($ERR)"

# --- AC-25: pass-side genuine fire (check bites the clean repo) → rollback ---
R5="$(mkworld passfire)"
BITER="$TMP/biter.sh"; printf '#!/usr/bin/env bash\necho always-bites\nexit 1\n' > "$BITER"
mkprop "$R5" p5; accept "$R5" p5; mksidecar "$R5" p5 pre-commit "$BITER"
run_install "$R5" p5 >/dev/null 2>&1 && fail "AC-25 must fail" || ok "AC-25 pass-side failure non-zero"
[ ! -e "$R5/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "AC-25 rolled back" || fail "AC-25 file remains"
F="$(lastres "$R5")"
[ "$(echo "$F" | jq -r .triage)" = class-definition-wrong ] \
  && ok "AC-25 triage=class-definition-wrong (bit clean repo)" || fail "AC-25 triage"

# --- AC-14: exec bit removed from the INSTALLED TARGET between the write and
# the pass-side proof (the exec-bit death) → hook MISCONFIGURED → triage=infra.
# Uses install.sh's documented test-only tamper seam so the tampered file is
# the actual installed check, proving the pass side proves THE REAL install.
R6="$(mkworld miscfg)"
mkprop "$R6" p6; accept "$R6" p6; mksidecar "$R6" p6 pre-commit "$GOOD"
# shellcheck disable=SC2016  # single-quoted on purpose: $1 expands later, inside install.sh's bash -c
TOUCHSTONE_INSTALL_TEST_TAMPER='chmod 644 "$1"' run_install "$R6" p6 >/dev/null 2>&1 \
  && fail "AC-14 must fail" || ok "AC-14 MISCONFIGURED pass side non-zero"
[ ! -e "$R6/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "AC-14 rolled back" || fail "AC-14 rollback"
F="$(lastres "$R6")"
[ "$(echo "$F" | jq -r .triage)" = infra ] && ok "AC-14 triage=infra (env/tamper, not class defect)" || fail "AC-14 triage=$(echo "$F" | jq -r .triage)"

# --- AC-16: revoke path ---
R7="$(mkworld revoke)"
mkprop "$R7" p7; accept "$R7" p7; mksidecar "$R7" p7 pre-commit "$GOOD"
run_install "$R7" p7 >/dev/null 2>&1 || fail "AC-16 setup install"
run_install "$R7" --revoke p7 >/dev/null 2>&1 && ok "AC-16 revoke exits 0" || fail "AC-16 rc"
[ ! -e "$R7/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "AC-16 file removed" || fail "AC-16 file"
F="$(lastres "$R7")"
[ "$(echo "$F" | jq -r .kind)" = revoked ] && ok "AC-16 revoked fact" || fail "AC-16 kind"
[ "$(echo "$F" | jq -r '.entry_ids | join(",")')" = "e1" ] && ok "AC-16 same entry_ids joined" || fail "AC-16 entry_ids"
run_install "$R7" --revoke p7 >/dev/null 2>&1 && fail "AC-16 second revoke must refuse" || ok "AC-16 already-revoked refused"

# --- regression: latest-DECISION gate, not any-historical-accepted-fact.
# accept -> reject (later ts) must refuse install even though an older
# accepted fact still exists; a fresh accept AFTER the reject (making
# accepted the latest decision again) must then succeed.
R9="$(mkworld latestdecision)"
mkprop "$R9" p9; accept "$R9" p9; mksidecar "$R9" p9 pre-commit "$GOOD"
jq -nc --arg pid p9 '{schema:"resolution/v1", ts:"2026-07-02T02:00:00Z",
  proposal_id:$pid, entry_ids:["e1"], kind:"rejected"}' \
  | TOUCHSTONE_LEDGER_DIR="$R9/.touchstone/ledger" bash "$W" resolution >/dev/null
ERR="$(run_install "$R9" p9 2>&1 >/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && ok "regression: accept-then-later-reject refuses install" || fail "regression: accept-then-reject rc=$rc"
[ ! -e "$R9/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "regression: nothing written under .touchstone/checker/ after reject" || fail "regression: wrote despite later reject"
grep -q '"kind":"installed"' "$R9/.touchstone/ledger/resolutions.jsonl" 2>/dev/null \
  && fail "regression: no installed fact must be appended after later reject" || ok "regression: no installed fact appended after later reject"
echo "$ERR" | grep -q rejected && ok "regression: refusal names the latest decision (rejected)" || fail "regression: message doesn't name latest decision: '$ERR'"

# a fresh accept AFTER the reject (latest decision = accepted again) → install succeeds
jq -nc --arg pid p9 '{schema:"resolution/v1", ts:"2026-07-02T03:00:00Z",
  proposal_id:$pid, entry_ids:["e1"], kind:"accepted"}' \
  | TOUCHSTONE_LEDGER_DIR="$R9/.touchstone/ledger" bash "$W" resolution >/dev/null
run_install "$R9" p9 >/dev/null 2>&1 \
  && ok "regression: re-accept after reject (latest=accepted) → install succeeds" \
  || fail "regression: re-accept after reject install still refused"
[ -f "$R9/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "regression: check landed after re-accept" || fail "regression: check missing after re-accept"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
