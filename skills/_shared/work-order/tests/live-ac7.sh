#!/usr/bin/env bash
# AC-7 live leg: ONE real engine dispatch of a fixture unit through the default
# headless worker path (cheap tier, tiny budget). Run once; keep the ledger row
# and artifacts as evidence. The crash leg lives in run-fixtures.sh (F-crash).
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
mkdir -p tests/_work/hello
[ -f tests/_work/freeze.json ] || python3 - <<'PY'
import glob, hashlib, json
sha = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
recs = {p: sha(p) for p in sorted(glob.glob("tests/expansion/*.json"))}
iface = {"path": "tests/engine/interface.json", "sha256": sha("tests/engine/interface.json")}
aux = {p: sha(p) for p in ("tests/engine/units.json", "templates/task-contract.md", "idiom-registry.json")}
json.dump({"accepted": True, "records": recs, "interface": iface, "aux": aux}, open("tests/_work/freeze.json", "w"))
PY
python3 scripts/dispatch.py run --config tests/engine/config-real.json --unit u-hello
rc=$?
echo "live-ac7 engine rc=$rc"
echo "--- ledger row ---"
tail -1 tests/_work/ledger-real.jsonl
exit $rc
