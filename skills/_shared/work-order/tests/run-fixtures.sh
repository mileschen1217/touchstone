#!/usr/bin/env bash
# Fixture suite for the work-order format standard. Runs every offline check
# artifact; exit 0 only when every case matches. Spends zero model tokens
# (the one real-model case lives in tests/live-ac7.sh, run separately).
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL $1"; }
rc_is()   { [ "$3" -eq "$2" ] && ok "$1 (rc=$3)" || bad "$1 (want rc=$2 got rc=$3)"; }
has()     { printf '%s' "$2" | grep -qF -- "$3" && ok "$1" || bad "$1 (missing: $3)"; }
has_not() { printf '%s' "$2" | grep -qF -- "$3" && bad "$1 (unexpected: $3)" || ok "$1"; }

echo "== setup =="
# live-run evidence (hello/, ledger-real.jsonl) is paid for — never wiped here
for d in render badcap badidiom badcallee zeroref mock esc kill c1 c2 tamper editc hang overrun badreset scopefx both refuse; do rm -rf "tests/_work/$d"; done
rm -f tests/_work/gate-*.md tests/_work/freeze*.json tests/_work/ledger-{mock,esc,conc,kill,tamper,editc,hang,nofreeze,noiface,unacc,drift,overrun,badreset,both,refuse,noaux}.jsonl
mkdir -p tests/_work/{hello,render,badcap,badidiom,badcallee,zeroref,mock,esc,kill,c1,c2,tamper,editc,hang,overrun,badreset,scopefx,both,refuse}
python3 - <<'PY'
import glob, hashlib, json
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
recs = {p: sha(p) for p in sorted(glob.glob("tests/expansion/*.json"))}
iface = {"path": "tests/engine/interface.json", "sha256": sha("tests/engine/interface.json")}
aux = {p: sha(p) for p in ("tests/engine/units.json", "templates/task-contract.md", "idiom-registry.json")}
json.dump({"accepted": True, "records": recs, "interface": iface, "aux": aux}, open("tests/_work/freeze.json", "w"))
json.dump({"accepted": True, "records": {list(recs)[0]: "0" * 64}, "interface": iface, "aux": aux}, open("tests/_work/freeze-drift.json", "w"))
json.dump({"accepted": True, "records": recs, "aux": aux}, open("tests/_work/freeze-noiface.json", "w"))
json.dump({"accepted": True, "records": recs, "interface": iface}, open("tests/_work/freeze-noaux.json", "w"))
PY

echo "== expansion records (AC-3 / AC-4) =="
out=$(python3 scripts/check_expansion.py tests/expansion 2>&1); rc=$?
rc_is "F-exp-good: spike worked example + residual + empty-ok all validate" 0 "$rc"
out=$(python3 scripts/check_expansion.py tests/expansion-bad 2>&1); rc=$?
rc_is "F-exp-bad: three malformed records rejected" 1 "$rc"
has "F-exp-bad names the case missing its test field" "$out" 'cases[0] missing `test`'
has "F-exp-bad names the empty record without the flag (DS-9)" "$out" "without no_expansion_needed:true"
has "F-exp-bad names residual+unit as contradictory (DS-8)" "$out" "contradictory (DS-8)"
has "F-exp-bad names vb-less expanded record (mutation-duty lapse)" "$out" "expansion content without violating_behaviors"

echo "== reconciliation four legs (AC-5 / AC-6 / AC-11 leg) =="
REC="python3 scripts/reconcile.py --spec tests/reconcile/spec.yaml --tests-root tests/reconcile"
out=$($REC --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-ok: all-green fixture (checker null check)" 0 "$rc"
out=$($REC --records tests/reconcile/records-bad-testnode --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-testnode rc" 1 "$rc"; has "F-rec-testnode: leg1 names the missing node" "$out" "test node test_nope not defined"
out=$($REC --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-dangling.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-dangling rc" 1 "$rc"; has "F-rec-dangling: leg2 names the dangling id" "$out" "traces AC-9 — no expansion record"
out=$($REC --records tests/reconcile/records-bad-boundary --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-boundary rc" 1 "$rc"; has "F-rec-boundary: leg3 names the unreferenced boundary" "$out" "'11 (fail)' referenced by no case and no waiver"
out=$($REC --records tests/reconcile/records-bad-acid --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-acid rc" 1 "$rc"; has "F-rec-acid: leg3 names the spec-absent ac_id" "$out" "AC-99"
has "F-rec-acid message form" "$out" "not present in governing spec"
out=$($REC --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-notrace.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-notrace rc (AC-6)" 1 "$rc"; has "F-rec-notrace names the work order" "$out" "wo-notrace.md lacks its _Requirements: trace line"
out=$($REC --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-missing.md 2>&1); rc=$?
rc_is "F-rec-gate-omit rc (AC-11 fourth leg)" 1 "$rc"; has "F-rec-gate-omit flags incompleteness" "$out" "mutation list omits expanded AC AC-1"
out=$($REC --records tests/reconcile/records-ac11 --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-comment.md 2>&1); rc=$?
rc_is "F-rec-gate-comment rc" 1 "$rc"; has "F-rec-gate-comment: template comment cannot satisfy leg 4" "$out" "mutation list omits expanded AC AC-11"
out=$($REC --records tests/reconcile/records-bad-substr --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-substr rc" 1 "$rc"; has "F-rec-substr: 'n < 1' not covered by 'n < 10' (boundary match)" "$out" "'n < 1' referenced by no case"
out=$($REC --records tests/reconcile/records-bad-classpath --work-orders tests/reconcile/wo-notrace.md --gate tests/reconcile/gate-ok.md 2>&1) || true
has "F-rec-classpath: undefined class component in test node fails leg 1" "$out" "test node WrongClass not defined"
out=$($REC --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-tokenless.md 2>&1); rc=$?
rc_is "F-rec-gate-tokenless rc" 1 "$rc"; has "F-rec-gate-tokenless: naming the AC without its mutant tokens fails leg 4" "$out" "missing mutant token mut:AC-1:1"
out=$(python3 scripts/reconcile.py --spec tests/reconcile/spec-heading.md --tests-root tests/reconcile --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-heading-pos: markdown heading-form governing spec passes leg 3" 0 "$rc"
out=$(python3 scripts/reconcile.py --spec tests/reconcile/spec-prose.md --tests-root tests/reconcile --records tests/reconcile/records-ok --work-orders tests/reconcile/wo-ok.md --gate tests/reconcile/gate-ok.md 2>&1); rc=$?
rc_is "F-rec-heading-neg rc: prose-mention heading is not a titled AC" 1 "$rc"; has "F-rec-heading-neg names the absent ac_id" "$out" "not present in governing spec"

echo "== integration gate instantiation (AC-11) =="
out=$(python3 scripts/make_gate.py --records tests/gate/mod-a/records --out tests/_work/gate-a.md --scope-name mod-a 2>&1); rc=$?
rc_is "F-gate-a: gate with residuals renders" 0 "$rc"
sec=$(awk '/^## Cross-unit invariant checks/{f=1;next}/^## /{f=0}f' tests/_work/gate-a.md)
has "F-gate-a: residual AC-2 lands in invariant checks" "$sec" "AC-2"
has "F-gate-a: mutation list covers all expanded ACs" "$(cat tests/_work/gate-a.md)" "mut:AC-1:2"
out=$(python3 scripts/make_gate.py --records tests/gate/mod-b/records --out tests/_work/gate-b.md --scope-name mod-b 2>&1); rc=$?
rc_is "F-gate-b: zero-residual module still gets a gate (DS-10)" 0 "$rc"
sec=$(awk '/^## Cross-unit invariant checks/{f=1;next}/^## /{f=0}f' tests/_work/gate-b.md | grep -v '^<!--' | grep -v '^ *$' | grep -v '\-\->')
[ "$(printf '%s' "$sec" | tr -d '[:space:]')" = "none" ] && ok "F-gate-b: empty section is explicit none" || bad "F-gate-b: invariant section not explicit none: '$sec'"
has "F-gate-b: mutation entry present" "$(cat tests/_work/gate-b.md)" "mut:AC-3:1"
out=$($REC --records tests/gate/mod-b/records --work-orders tests/reconcile/wo-notrace.md --gate tests/_work/gate-b.md 2>&1) || true
has_not "F-gate-b roundtrip: generated gate passes leg 4" "$out" "leg4"
has "F-gate-b roundtrip ran (leg2 exercised, not vacuous)" "$out" "leg2"

echo "== report script (AC-12 fixture legs) =="
out=$(python3 scripts/report.py --ledger tests/report/ledger-ok.jsonl --records tests/report/records 2>&1); rc=$?
rc_is "F-report-ok rc" 0 "$rc"; has "F-report-ok: per-AC table complete" "$out" "| AC-1 | 2/2 |"
out=$(python3 scripts/report.py --ledger tests/report/ledger-missing.jsonl --records tests/report/records 2>&1); rc=$?
rc_is "F-report-missing rc" 1 "$rc"; has "F-report-missing names the gap" "$out" "missing mutant row mut:AC-1:2"
out=$(python3 scripts/report.py --ledger tests/report/ledger-dup.jsonl --records tests/report/records 2>&1); rc=$?
rc_is "F-report-dup rc" 1 "$rc"
has "F-report-dup: retried mutant rows all summed" "$out" "| AC-1 | 2/2 | 0.2700 |"
has "F-report-dup: orphan mutant row fails by name" "$out" "orphan mutant row mut:AC-9:1"

echo "== contract render (AC-1 / AC-2) =="
out=$(python3 scripts/dispatch.py render --config tests/engine/config-mock.json --unit u-render 2>&1); rc=$?
rc_is "F-render rc" 0 "$rc"
C=tests/_work/render/task-contract-u-render.md
for h in "## Target Interface" "## Dependency Contracts" "## Seam Convention" "## Caps" "Verbatim Check Command" "## Executor Write Protocol"; do
  grep -qF "$h" "$C" && ok "F-render section present: $h" || bad "F-render section missing: $h"
done
grep -qxF 'pytest tests/test_strip.py -q  # VERBATIM-SENTINEL-93f2' "$C" \
  && ok "F-render: check command byte-identical" || bad "F-render: check command not byte-identical"
has "F-render: cap states its reference + headroom (DS-1)" "$(cat "$C")" "cap 4 (reference 2, headroom 2.0x)"
has "F-render: EWP names checkboxes" "$(cat "$C")" "task checkboxes in § Tasks"
has "F-render: EWP names report block" "$(cat "$C")" "the body of § Report"
has "F-render-deps: in-scope callee signature rendered" "$(cat "$C")" "def rstrip_iter(it: Iterable[str]) -> Iterator[str]"
has_not "F-render-deps: interface-absent callee NOT rendered (nothing else)" "$(cat "$C")" "mystery_helper"
has_not "F-render-deps: in-interface but non-callee signature NOT leaked (nothing else)" "$(cat "$C")" "hello.txt — a file containing"
has "F-render-deps: seam cites the class-valid idiom id" "$(cat "$C")" 'idiom `stub-with-injectable-returns`'
out=$(python3 scripts/dispatch.py render --config tests/engine/config-mock.json --unit u-badcap 2>&1); rc=$?
rc_is "F-render-badcap refused rc" 2 "$rc"; has "F-render-badcap names DS-1" "$out" "headroom < 2x"
out=$(python3 scripts/dispatch.py render --config tests/engine/config-mock.json --unit u-badidiom 2>&1); rc=$?
rc_is "F-render-badidiom refused rc" 2 "$rc"; has "F-render-badidiom names the class mismatch" "$out" "task class"
out=$(python3 scripts/dispatch.py render --config tests/engine/config-mock.json --unit u-zeroref 2>&1); rc=$?
rc_is "F-render-zeroref refused rc" 2 "$rc"; has "F-render-zeroref: non-positive reference refused cleanly" "$out" "reference must be positive"
out=$(python3 scripts/dispatch.py render --config tests/engine/config-mock.json --unit u-badcallee 2>&1); rc=$?
rc_is "F-render-badcallee refused rc" 2 "$rc"; has "F-render-badcallee names the unruled callee" "$out" "mystery_helper"

echo "== executor write protocol (AC-19 / INV-2) =="
S=tests/_work/render/task-contract-u-render.sha.json
out=$(python3 scripts/check_scope.py verify --sidecar "$S" 2>&1); rc=$?
rc_is "F-scope-clean rc" 0 "$rc"
perl -0pi -e 's/^## Scope\n/## Scope\n- sneaky extra scope line\n/m' "$C"
out=$(python3 scripts/check_scope.py verify --sidecar "$S" 2>&1); rc=$?
rc_is "F-scope-violation rc" 1 "$rc"; has "F-scope-violation names the class" "$out" "scope violation: executor-modified artifact"
has "F-scope-violation names the file" "$out" "task-contract-u-render.md"
python3 scripts/dispatch.py render --config tests/engine/config-mock.json --unit u-render >/dev/null 2>&1  # restore
perl -0pi -e 's/- \[ \] implement strip_iter/- [x] implement strip_iter/' "$C"
printf 'ran the check; PASS; no low-confidence spots\n' >> "$C"   # § Report is the last section
out=$(python3 scripts/check_scope.py verify --sidecar "$S" 2>&1); rc=$?
rc_is "F-scope-ewp-ok: checkbox+report edits alone do not trigger (AC-19)" 0 "$rc"
cp tests/expansion/ac-5.json tests/_work/ac-5.bak
printf '\n' >> tests/expansion/ac-5.json
out=$(python3 scripts/check_scope.py verify --sidecar "$S" 2>&1); rc=$?
rc_is "F-scope-record rc" 1 "$rc"; has "F-scope-record names the expansion record" "$out" "tests/expansion/ac-5.json"
mv tests/_work/ac-5.bak tests/expansion/ac-5.json
cat > tests/_work/scopefx/contract.md <<'CONTRACT_EOF'
## Scope
- [ ] looks like a checkbox but is NOT an executor-writable field
## Tasks
- [ ] the real task
## Report
CONTRACT_EOF
python3 scripts/check_scope.py record --contract tests/_work/scopefx/contract.md --out tests/_work/scopefx/side.json >/dev/null
perl -0pi -e 's/- \[ \] looks like/- [x] looks like/' tests/_work/scopefx/contract.md
out=$(python3 scripts/check_scope.py verify --sidecar tests/_work/scopefx/side.json 2>&1); rc=$?
rc_is "F-scope-foreign-checkbox: ticking a non-Tasks checkbox IS a violation" 1 "$rc"
perl -0pi -e 's/- \[x\] looks like/- [ ] looks like/; s/- \[ \] the real task/- [x] the real task/' tests/_work/scopefx/contract.md
out=$(python3 scripts/check_scope.py verify --sidecar tests/_work/scopefx/side.json 2>&1); rc=$?
rc_is "F-scope-tasks-checkbox: ticking a Tasks checkbox is clean" 0 "$rc"

echo "== engine freeze gate (AC-16 refusal leg) =="
out=$(python3 scripts/dispatch.py run --config tests/engine/config-nofreeze.json --unit u-mock 2>&1); rc=$?
rc_is "F-freeze-absent rc" 3 "$rc"; has "F-freeze-absent message" "$out" "freeze manifest absent"
out=$(python3 scripts/dispatch.py run --config tests/engine/config-unaccepted.json --unit u-mock 2>&1); rc=$?
rc_is "F-freeze-unaccepted rc" 3 "$rc"; has "F-freeze-unaccepted message" "$out" "not human-accepted"
out=$(python3 scripts/dispatch.py run --config tests/engine/config-drift.json --unit u-mock 2>&1); rc=$?
rc_is "F-freeze-drift rc" 3 "$rc"; has "F-freeze-drift message" "$out" "drifted"
printf '{"ac_id":"ZZ-1"}' > tests/expansion/zz-added.json
out=$(python3 scripts/dispatch.py run --config tests/engine/config-mock.json --unit u-mock 2>&1); rc=$?
rm -f tests/expansion/zz-added.json
rc_is "F-freeze-addition rc (closed set: addition refused)" 3 "$rc"; has "F-freeze-addition message" "$out" "unfrozen expansion record present"
out=$(python3 scripts/dispatch.py run --config tests/engine/config-noiface.json --unit u-mock 2>&1); rc=$?
rc_is "F-freeze-noiface rc" 3 "$rc"; has "F-freeze-noiface: interface artifact must be frozen too" "$out" "interface artifact not covered"
out=$(python3 scripts/dispatch.py run --config tests/engine/config-noaux.json --unit u-mock 2>&1); rc=$?
rc_is "F-freeze-noaux rc (INV-4: the ruler-bearing units artifact must be frozen)" 3 "$rc"
has "F-freeze-noaux message" "$out" "units artifact"

echo "== engine dispatch rows (AC-7 crash leg, AC-8, AC-9, AC-20) =="
out=$(python3 scripts/dispatch.py run --config tests/engine/config-mock.json --unit u-mock 2>&1); rc=$?
rc_is "F-mock-pass rc" 0 "$rc"
python3 - <<'PY' && ok "F-mock-pass: row fields + resolvable pointers" || bad "F-mock-pass row check"
import hashlib, json, pathlib, sys
r = json.loads(pathlib.Path("tests/_work/ledger-mock.jsonl").read_text().splitlines()[-1])
assert r["verdict"] == "PASS" and r["terminal_reason"] == "completed" and r["attempt"] == 1
assert r["tier"] == "haiku" and r["escalated_from"] is None and r["cost_usd"] == 0.01
c = pathlib.Path(r["contract_ref"]["path"]); assert c.exists()
assert hashlib.sha256(c.read_bytes()).hexdigest() == r["contract_ref"]["sha256"]
assert pathlib.Path(r["artifacts"]["check"]).exists() and r["artifacts"]["session_id"].startswith("mock-pass")
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-kill.json --unit u-kill 2>&1); rc=$?
rc_is "F-crash: killed worker exhausts single-tier list" 1 "$rc"
python3 - <<'PY' && ok "F-crash: exactly one row, terminal_reason=error, cost null, verdict NONE (DS-6)" || bad "F-crash row check"
import json, pathlib
rows = [json.loads(l) for l in pathlib.Path("tests/_work/ledger-kill.jsonl").read_text().splitlines()]
assert len(rows) == 1, rows
r = rows[0]
assert r["terminal_reason"] == "error" and r["cost_usd"] is None and r["verdict"] == "NONE"
assert r["model_id"] == "mock-h" and r["artifacts"]["session_id"] is None
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-esc.json --unit u-esc 2>&1); rc=$?
rc_is "F-esc rc (tier list exhausted)" 1 "$rc"
has "F-esc: FAIL routes to the integration gate for human ruling (DS-2)" "$out" "routed to the integration gate for human ruling"
python3 - <<'PY' && ok "F-esc: chain in configured order, tie=budget_exhausted (AC-8/AC-9/DS-4)" || bad "F-esc chain check"
import json, pathlib
rows = [json.loads(l) for l in pathlib.Path("tests/_work/ledger-esc.jsonl").read_text().splitlines()]
assert [r["attempt"] for r in rows] == [1, 2]
assert rows[0]["tier"] == "haiku" and rows[1]["tier"] == "sonnet"        # tier-list order, no skip
assert rows[0]["escalated_from"] is None and rows[1]["escalated_from"] == 1
p1, p2 = rows[0]["contract_ref"]["path"], rows[1]["contract_ref"]["path"]
assert p1 != p2 and pathlib.Path(p1).exists() and pathlib.Path(p2).exists()   # per-attempt artifacts, audit chain intact
assert rows[0]["verdict"] == "FAIL" and rows[0]["terminal_reason"] == "budget_exhausted"  # the tie (DS-4)
assert rows[1]["verdict"] == "FAIL" and rows[1]["terminal_reason"] == "completed"
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-editc.json --unit u-editc 2>&1); rc=$?
rc_is "F-editc rc (report-writing worker passes)" 0 "$rc"
python3 - <<'PY' && ok "F-editc: contract_ref.sha256 is the AS-DISPATCHED hash, not the worker-edited file" || bad "F-editc sha check"
import hashlib, json, pathlib
r = json.loads(pathlib.Path("tests/_work/ledger-editc.jsonl").read_text().splitlines()[-1])
assert r["verdict"] == "PASS"
cur = hashlib.sha256(pathlib.Path(r["contract_ref"]["path"]).read_bytes()).hexdigest()
assert cur != r["contract_ref"]["sha256"], "row hash tracked the post-edit file"
PY
cp tests/expansion/ac-residual.json tests/_work/ac-residual.bak
out=$(python3 scripts/dispatch.py run --config tests/engine/config-tamper.json --unit u-tamper 2>&1); rc=$?
mv tests/_work/ac-residual.bak tests/expansion/ac-residual.json
rc_is "F-tamper rc (escalation refused on tampered inputs)" 3 "$rc"
has "F-tamper: per-attempt freeze gate catches the drift" "$out" "drifted"
python3 - <<'PY' && ok "F-tamper: attempt 1 FAILed on scope, no re-baselined attempt 2" || bad "F-tamper ledger check"
import json, pathlib
rows = [json.loads(l) for l in pathlib.Path("tests/_work/ledger-tamper.jsonl").read_text().splitlines()]
assert len(rows) == 1 and rows[0]["verdict"] == "FAIL"
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-overrun.json --unit u-overrun 2>&1); rc=$?
rc_is "F-pass-overrun rc (acceptance = the held-out check, fuse = stop-loss)" 0 "$rc"
python3 - <<'PY' && ok "F-pass-overrun: check-green unit returns success, row keeps the honest reason (design ruling)" || bad "F-pass-overrun row check"
import json, pathlib
r = json.loads(pathlib.Path("tests/_work/ledger-overrun.jsonl").read_text().splitlines()[-1])
assert r["verdict"] == "PASS" and r["terminal_reason"] == "budget_exhausted"
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-both.json --unit u-both 2>&1) ; rc=$?
rc_is "F-both rc (check green -> PASS per design ruling, tie still recorded)" 0 "$rc"
python3 - <<'PY' && ok "F-both: exhausted+errored in one attempt records budget_exhausted (DS-4 full precedence)" || bad "F-both row check"
import json, pathlib
r = json.loads(pathlib.Path("tests/_work/ledger-both.jsonl").read_text().splitlines()[-1])
assert r["terminal_reason"] == "budget_exhausted"
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-refuse.json --unit u-refuse 2>&1); rc=$?
rc_is "F-refuse rc (refusal text, check still green)" 0 "$rc"
python3 - <<'PY' && ok "F-refuse: refusal-shaped report flips worker_refusal true (DS-14 positive path)" || bad "F-refuse row check"
import json, pathlib
r = json.loads(pathlib.Path("tests/_work/ledger-refuse.jsonl").read_text().splitlines()[-1])
assert r["worker_refusal"] is True
PY
out=$(python3 scripts/dispatch.py run --config tests/engine/config-badreset.json --unit u-badreset 2>&1); rc=$?
rc_is "F-badreset rc (failed reset refuses before spawn)" 4 "$rc"
has "F-badreset message" "$out" "RESET FAILED"
[ ! -s tests/_work/ledger-badreset.jsonl ] && ok "F-badreset: no worker, no row" || bad "F-badreset: unexpected ledger rows"
out=$(cd tests && python3 ../scripts/dispatch.py render --config engine/config-mock.json --unit u-render 2>&1); rc=$?
rc_is "F-cwd: config works from a different cwd (base_dir resolution)" 0 "$rc"
out=$(python3 scripts/dispatch.py run --config tests/engine/config-hang.json --unit u-hang 2>&1); rc=$?
rc_is "F-hang rc" 1 "$rc"
python3 - <<'PY' && ok "F-hang: hung worker still gets its error row (timeout fuse)" || bad "F-hang ledger check"
import json, pathlib
rows = [json.loads(l) for l in pathlib.Path("tests/_work/ledger-hang.jsonl").read_text().splitlines()]
assert len(rows) == 1 and rows[0]["terminal_reason"] == "error" and rows[0]["verdict"] == "NONE"
PY
python3 scripts/dispatch.py run --config tests/engine/config-conc.json --unit u-c1 >/dev/null 2>&1 & P1=$!
python3 scripts/dispatch.py run --config tests/engine/config-conc.json --unit u-c2 >/dev/null 2>&1 & P2=$!
wait $P1; r1=$?; wait $P2; r2=$?
[ "$r1" -eq 0 ] && [ "$r2" -eq 0 ] && ok "F-conc: both concurrent dispatches PASS" || bad "F-conc rcs $r1/$r2"
python3 - <<'PY' && ok "F-conc: two intact uninterleaved rows (AC-20/DS-5)" || bad "F-conc ledger check"
import json, pathlib
lines = pathlib.Path("tests/_work/ledger-conc.jsonl").read_text().splitlines()
rows = [json.loads(l) for l in lines]           # any interleaving breaks json.loads
assert len(rows) == 2 and {r["unit"] for r in rows} == {"u-c1", "u-c2"}
PY

echo "== static greps (AC-10 / AC-13) =="
out=$(grep -RnEi "import anthropic|api\.anthropic|messages\.create" scripts/ || true)
[ -z "$out" ] && ok "F-grep-models: dispatch layer makes zero model calls (AC-10)" || bad "F-grep-models: $out"
# scanner excludes itself (it carries the banned-term list) and bytecode caches
out=$(grep -RnEli "touchstone|anvil|crucible|conductor|epic-driven-roadmap" --exclude-dir=_work --exclude-dir=__pycache__ --exclude=run-fixtures.sh . || true)
[ -z "$out" ] && ok "F-grep-standalone: zero consumer-repo paths/skill names (AC-13)" || bad "F-grep-standalone: $out"

echo
echo "SUITE: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
