#!/usr/bin/env python3
"""Shape validator for expansion-record-v1 (schemas/expansion-record.schema.json).

  check_expansion.py <record.json | dir-of-*.json> [...]

Enforced here (stdlib, no jsonschema dependency):
  - required fields present with the right JSON types
  - every cases[] entry carries non-empty `case` AND `test`        (AC-4)
  - residual:true with a `unit` binding is contradictory (DS-8)   (AC-3/AC-4)
  - all five expansion arrays empty without no_expansion_needed:true
    fails; with the flag it must carry no_expansion_reason (DS-9) (AC-4)
Cross-artifact rules (ac_id in governing spec, test nodes exist, item
reference/waiver) belong to scripts/reconcile.py, not here.
Exit 0 = all records valid; 1 = any invalid (each failure names the record
file, the ac_id when readable, and the offending entry); 2 = usage error.
"""
import json, sys
from pathlib import Path

EXPANSION_ARRAYS = ["partitions", "boundaries", "negatives", "invariants", "violating_behaviors"]
REQUIRED = {"ac_id": str, "partitions": list, "boundaries": list, "negatives": list,
            "invariants": list, "violating_behaviors": list, "cases": list, "residual": bool}


def validate(path):
    errs = []
    try:
        rec = json.loads(Path(path).read_text())
    except Exception as e:
        return [f"{path}: unreadable JSON ({e})"]
    if not isinstance(rec, dict):
        return [f"{path}: record is not a JSON object"]
    ac = rec.get("ac_id", "<no ac_id>")
    for field, typ in REQUIRED.items():
        if field not in rec:
            errs.append(f"{path} [{ac}]: missing required field `{field}`")
        elif not isinstance(rec[field], typ):
            errs.append(f"{path} [{ac}]: field `{field}` is not {typ.__name__}")
    if errs:
        return errs
    for arr in EXPANSION_ARRAYS:
        for i, item in enumerate(rec[arr]):
            if not isinstance(item, str) or not item.strip():
                errs.append(f"{path} [{ac}]: {arr}[{i}] is not a non-empty string")
    for i, c in enumerate(rec["cases"]):
        if not isinstance(c, dict):
            errs.append(f"{path} [{ac}]: cases[{i}] is not an object")
            continue
        for k in ("case", "test"):
            if not isinstance(c.get(k), str) or not c.get(k, "").strip():
                errs.append(f"{path} [{ac}]: cases[{i}] missing `{k}` (case={c.get('case', '<absent>')!r})")
    if rec["residual"] is True and rec.get("unit"):
        errs.append(f"{path} [{ac}]: residual:true with unit binding `{rec['unit']}` is contradictory (DS-8)")
    all_empty = all(not rec[a] for a in EXPANSION_ARRAYS)
    if all_empty:
        if rec.get("no_expansion_needed") is not True:
            errs.append(f"{path} [{ac}]: all expansion arrays empty without no_expansion_needed:true (DS-9)")
        elif not str(rec.get("no_expansion_reason", "")).strip():
            errs.append(f"{path} [{ac}]: no_expansion_needed:true without no_expansion_reason (DS-9)")
    elif rec.get("no_expansion_needed") is True:
        errs.append(f"{path} [{ac}]: no_expansion_needed:true but expansion arrays are non-empty")
    elif not rec["violating_behaviors"]:
        errs.append(f"{path} [{ac}]: expansion content without violating_behaviors — the AC would "
                    f"silently exit the gate's mutation duty; add violating_behaviors or declare "
                    f"no_expansion_needed (only such records are mutation-exempt)")
    return errs


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    files = []
    for a in argv:
        p = Path(a)
        files += sorted(p.glob("*.json")) if p.is_dir() else [p]
    failures = []
    for f in files:
        failures += validate(f)
    for e in failures:
        print(f"FAIL {e}")
    if not failures:
        print(f"OK {len(files)} record(s) valid")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
