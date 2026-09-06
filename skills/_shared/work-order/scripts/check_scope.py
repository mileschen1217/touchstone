#!/usr/bin/env python3
"""Executor Write Protocol enforcement (INV-2 / AC-19).

  check_scope.py record --contract <path> --records <r1.json> [...] --out <sidecar.json>
  check_scope.py verify --sidecar <sidecar.json>

`record` runs at render time (called by the dispatch engine): stores the
sha256 of the NORMALIZED contract plus raw sha256 of every expansion record.
`verify` runs as part of the held-out check: re-normalizes and compares —
any drift outside the Executor Write Protocol fields is a scope violation
naming the edited artifact; edits to the protocol fields alone (task
checkboxes, § Report body) do not trigger it.

Normalization (= the writable surface, and nothing else):
  - a task checkbox mark `- [x]` / `- [X]` at line start reverts to `- [ ]`,
    ONLY inside the `## Tasks` section — a checkbox anywhere else is not an
    executor-writable field
  - the body of the `## Report` section (heading kept) is dropped up to the
    next `## ` heading or EOF
Exit 0 = clean; 1 = violation; 2 = usage/IO error.
"""
import hashlib, json, re, sys
from pathlib import Path


def normalize(text):
    lines = []
    in_report = in_tasks = False
    for line in text.splitlines():
        if re.match(r"^##\s+", line):
            in_report = bool(re.match(r"^##\s+Report\b", line))
            in_tasks = bool(re.match(r"^##\s+Tasks\b", line))
            lines.append(line)
            continue
        if in_report:
            continue
        if in_tasks:
            line = re.sub(r"^(\s*[-*]\s*)\[[xX]\]", r"\1[ ]", line)
        lines.append(line)
    return "\n".join(lines) + "\n"


def sha(b):
    return hashlib.sha256(b).hexdigest()


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    mode, args = argv[0], argv[1:]

    def opt(name, multi=False):
        if name not in args:
            return [] if multi else None
        i = args.index(name)
        if multi:
            vals = []
            for a in args[i + 1:]:
                if a.startswith("--"):
                    break
                vals.append(a)
            return vals
        return args[i + 1]

    if mode == "record":
        contract, out = opt("--contract"), opt("--out")
        records = opt("--records", multi=True)
        side = {"contract": {"path": contract,
                             "sha256_normalized": sha(normalize(Path(contract).read_text()).encode())},
                "expansion_records": {r: sha(Path(r).read_bytes()) for r in records}}
        Path(out).write_text(json.dumps(side, indent=1))
        print(f"recorded: {out}")
        return 0
    if mode == "verify":
        side = json.loads(Path(opt("--sidecar")).read_text())
        violations = []
        c = side["contract"]
        if not Path(c["path"]).exists():
            violations.append(c["path"] + " (missing)")
        elif sha(normalize(Path(c["path"]).read_text()).encode()) != c["sha256_normalized"]:
            violations.append(c["path"])
        for rpath, rsha in side["expansion_records"].items():
            if not Path(rpath).exists() or sha(Path(rpath).read_bytes()) != rsha:
                violations.append(rpath)
        for v in violations:
            print(f"FAIL scope violation: executor-modified artifact {v}")
        if not violations:
            print("scope: clean")
        return 1 if violations else 0
    print(f"unknown mode {mode}")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
