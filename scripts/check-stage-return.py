#!/usr/bin/env python3
"""Validate a stage-return/v1 artifact. Fail closed: print status=BLOCKED on ANY
malformedness, never raise, never upgrade. Output: a single line `status=<S>`."""
import json, sys

ALLOWED = {"schema", "stage", "status", "reason", "artifacts", "source"}
ENUM = {"DONE", "NEEDS_HUMAN", "BLOCKED"}
STAGES = {"entry-precondition", "plan-review", "final-review"}

def blocked():
    print("status=BLOCKED"); sys.exit(0)

def main():
    if len(sys.argv) != 2:
        print("usage: check-stage-return.py <file>", file=sys.stderr); sys.exit(2)
    try:
        with open(sys.argv[1], encoding="utf-8") as fh:
            d = json.load(fh)
    except Exception:
        blocked()
    if not isinstance(d, dict): blocked()
    if d.get("schema") != "stage-return/v1": blocked()
    if set(d) - ALLOWED: blocked()
    if d.get("stage") not in STAGES: blocked()              # stage required + in enum
    st = d.get("status")
    if st not in ENUM: blocked()
    reason = d.get("reason")
    arts = d.get("artifacts")
    if st == "DONE":
        if reason not in (None, "", []): blocked()          # DONE carries no reason
        if not isinstance(arts, list) or not arts: blocked()  # DONE MUST produce ≥1 artifact
        if not all(isinstance(a, str) and a for a in arts): blocked()
    else:  # NEEDS_HUMAN / BLOCKED
        if not isinstance(reason, str) or not reason.strip(): blocked()  # reason required
        if arts not in (None, []): blocked()                # non-DONE carries no artifacts
    print(f"status={st}")

if __name__ == "__main__":
    main()
