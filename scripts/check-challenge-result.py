#!/usr/bin/env python3
"""Validate a challenge-result/v1 record against its spec. Fail closed."""
import json, subprocess, sys, os, re

ALLOWED_TOP = {"schema_version", "author_id", "challenger_id", "input_digest", "findings"}
ALLOWED_FINDING = {"id", "marker", "req"}
MARKER_RE = re.compile(r'\[NEEDS CLARIFICATION:[^\]]*\]')  # used with fullmatch

def fail(msg):
    print(f"BLOCK: {msg}"); sys.exit(1)

def run_extract(sub, spec):
    here = os.path.dirname(os.path.abspath(__file__))
    r = subprocess.run(["bash", os.path.join(here, "spec-extract.sh"), sub, spec],
                       capture_output=True, text=True)
    if r.returncode != 0:
        fail(f"spec-extract {sub} failed (fail closed): {r.stderr.strip()}")
    return r.stdout

def main():
    skip_fresh = "--skip-freshness" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--skip-freshness"]
    if len(args) != 2:
        print("usage: check-challenge-result.py [--skip-freshness] <spec> <challenge.json>"); sys.exit(2)
    spec, cr = args
    try:
        with open(cr, encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as e:
        fail(f"cannot parse challenge-result (fail closed): {e}")
    if not isinstance(data, dict): fail("record is not a JSON object")
    extra = set(data) - ALLOWED_TOP
    if extra: fail(f"extra top-level field(s): {sorted(extra)}")
    missing = ALLOWED_TOP - set(data)
    if missing: fail(f"missing required field(s): {sorted(missing)}")
    # types before values (bool is a subclass of int → reject schema_version is True)
    if not isinstance(data["schema_version"], int) or isinstance(data["schema_version"], bool):
        fail("schema_version must be an integer (type)")
    if data["schema_version"] != 1: fail("schema_version must be 1")
    for k in ("author_id", "challenger_id", "input_digest"):
        if not isinstance(data[k], str): fail(f"{k} must be a string (type)")
    if not isinstance(data["findings"], list): fail("findings must be a list (type)")
    if not data["author_id"] or not data["challenger_id"]: fail("empty author_id/challenger_id")
    if data["author_id"] == data["challenger_id"]: fail("author_id == challenger_id (not independent)")
    rs = set(run_extract("reqs", spec).split())
    seen = set()
    for f in data["findings"]:
        if not isinstance(f, dict): fail("finding is not an object (type)")
        e = set(f) - ALLOWED_FINDING
        if e: fail(f"finding has extra field(s): {sorted(e)}")
        m = ALLOWED_FINDING - set(f)
        if m: fail(f"finding missing field(s): {sorted(m)}")
        if not isinstance(f["marker"], str) or not MARKER_RE.fullmatch(f["marker"]):
            fail("finding marker is not a canonical [NEEDS CLARIFICATION: <q>] string")
        if not isinstance(f["id"], str) or not isinstance(f["req"], str):
            fail("finding id/req must be strings (type)")
        if f["id"] in seen: fail(f"duplicate finding id {f['id']}")
        seen.add(f["id"])
        if f["req"] not in rs: fail(f"finding references {f['req']} not in spec requirement set")
    if not skip_fresh:
        cur = run_extract("digest", spec).strip()
        if not cur: fail("could not compute spec digest (fail closed)")
        if data["input_digest"] != cur:
            fail("stale input_digest (spec changed after the challenge) — re-run the challenge-pass")
    print("ok: challenge-result/v1 valid")

if __name__ == "__main__":
    main()
