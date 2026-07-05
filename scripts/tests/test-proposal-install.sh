#!/usr/bin/env bash
# install.sh suite: guards, copy + one installed fact, rollback on fact-append
# failure, revoke. Spec joins: AC-13, AC-16, AC-26, AC-27.
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

# mksidecar <repo> <pid> <stage> <check-body-file> — minimal sidecar
# (draft-check.sh + proposal.md; no fire fixture — the rail is copy + fact)
mksidecar() {
  local r="$1" pid="$2" stage="$3" body="$4"
  local s="$r/.touchstone/ledger/proposals/$pid"; mkdir -p "$s"
  printf -- '---\nstage: %s\ncheck_name: probe\n---\nmechanism prose\n' "$stage" > "$s/proposal.md"
  cp "$body" "$s/draft-check.sh"
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

# the standard check body (content irrelevant to the rail — never executed here)
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

# --- AC-13: happy path — write, chmod, one installed fact ---
R1="$(mkworld happy)"
mkprop "$R1" p1; accept "$R1" p1; mksidecar "$R1" p1 pre-commit "$GOOD"
run_install "$R1" p1 >/dev/null 2>&1 && ok "AC-13 install exits 0" || fail "AC-13 rc"
TGT="$R1/.touchstone/checker/pre-commit/check-probe.sh"
[ -f "$TGT" ] && ok "AC-13 check landed at stage path" || fail "AC-13 path"
[ -x "$TGT" ] && ok "AC-13 mode is executable" || fail "AC-13 mode"
F="$(lastres "$R1")"
[ "$(echo "$F" | jq -r .kind)" = installed ] && ok "AC-13 installed fact" || fail "AC-13 fact kind"
[ "$(echo "$F" | jq -r .proof.installed_path)" = ".touchstone/checker/pre-commit/check-probe.sh" ] \
  && ok "AC-13 fact names installed path" || fail "AC-13 fact path"
cmp -s "$GOOD" "$TGT" && ok "AC-13 installed content is the sidecar draft" || fail "AC-13 content"

# --- AC-26: refuse without accepted fact ---
R2="$(mkworld noaccept)"
mkprop "$R2" p2; mksidecar "$R2" p2 pre-commit "$GOOD"
ERR="$(run_install "$R2" p2 2>&1 >/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && echo "$ERR" | grep -q accepted && ok "AC-26 refuses, names missing accepted fact" || fail "AC-26 rc=$rc '$ERR'"
[ ! -e "$R2/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "AC-26 nothing written" || fail "AC-26 wrote"
grep -qE '"kind":"(installed|install-failed)"' "$R2/.touchstone/ledger/resolutions.jsonl" 2>/dev/null \
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

# --- guard: incomplete sidecar (missing draft-check.sh) refuses, writes nothing ---
R4="$(mkworld nosidecar)"
mkprop "$R4" p4; accept "$R4" p4
mkdir -p "$R4/.touchstone/ledger/proposals/p4"
printf -- '---\nstage: pre-commit\ncheck_name: probe\n---\np\n' > "$R4/.touchstone/ledger/proposals/p4/proposal.md"
ERR="$(run_install "$R4" p4 2>&1 >/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && echo "$ERR" | grep -q 'draft-check.sh' && ok "sidecar guard: missing draft-check.sh named" || fail "sidecar guard rc=$rc '$ERR'"
[ ! -e "$R4/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "sidecar guard: nothing written" || fail "sidecar guard wrote"

# --- regression: fact-append failure after the copy must roll the copy back
# and exit non-zero — never leave an installed file with no installed fact.
# Hold the writer lock so facts-append fails deterministically.
R8="$(mkworld lockfail)"
mkprop "$R8" p8; accept "$R8" p8; mksidecar "$R8" p8 pre-commit "$GOOD"
LOCKDIR="$R8/.touchstone/ledger/.lock"
mkdir "$LOCKDIR"; echo $$ > "$LOCKDIR/pid"
export TOUCHSTONE_LEDGER_LOCK_TIMEOUT=1
ERR="$(run_install "$R8" p8 2>&1 >/dev/null)"; rc=$?
unset TOUCHSTONE_LEDGER_LOCK_TIMEOUT
rm -rf "$LOCKDIR"
[ "$rc" -ne 0 ] && ok "regression: lock-held install exits non-zero" || fail "regression: rc=$rc"
[ ! -e "$R8/.touchstone/checker/pre-commit/check-probe.sh" ] && ok "regression: copied file rolled back" || fail "regression: file left behind"
grep -q '"kind":"installed"' "$R8/.touchstone/ledger/resolutions.jsonl" 2>/dev/null \
  && fail "regression: no installed fact must be recorded (lock held)" || ok "regression: no installed fact appended"
echo "$ERR" | grep -q 'rolled back' && ok "regression: stderr states the rollback" || fail "regression: stderr missing rollback ($ERR)"

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

# --- regression: existing check at the target path -> refuse, never overwrite ---
# (caught live: the first insight run silently overwrote a shipped, git-tracked
# check that a prior phase had installed at the same stage/name)
R10="$(mkworld existing)"
mkprop "$R10" p10; accept "$R10" p10; mksidecar "$R10" p10 pre-commit "$GOOD"
mkdir -p "$R10/.touchstone/checker/pre-commit"
printf '#!/usr/bin/env bash\nexit 0\n' > "$R10/.touchstone/checker/pre-commit/check-probe.sh"
chmod 755 "$R10/.touchstone/checker/pre-commit/check-probe.sh"
before_sum="$(cksum < "$R10/.touchstone/checker/pre-commit/check-probe.sh")"
ERR="$(run_install "$R10" p10 2>&1 >/dev/null)"; rc=$?
[ "$rc" -ne 0 ] && ok "regression: existing target refused" || fail "regression: existing target rc=$rc"
echo "$ERR" | grep -q 'already exists' && ok "regression: refusal names the conflict" || fail "regression: message: '$ERR'"
after_sum="$(cksum < "$R10/.touchstone/checker/pre-commit/check-probe.sh")"
[ "$before_sum" = "$after_sum" ] && ok "regression: existing check byte-unchanged" || fail "regression: existing check overwritten"
grep -qE '"kind":"(installed|install-failed)"' "$R10/.touchstone/ledger/resolutions.jsonl" 2>/dev/null \
  && fail "regression: no fact must be appended on existing-target refusal" || ok "regression: no fact appended on refusal"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
