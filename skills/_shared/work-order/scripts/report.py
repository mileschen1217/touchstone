#!/usr/bin/env python3
"""Aggregate dispatch-ledger rows into the per-unit dispatch table and the
per-AC mutation cost table (DS-11 / AC-12). Reads the ledger and the expansion
records; makes zero model calls.

  report.py --ledger <ledger.jsonl> --records <dir>

Mutant rows are ledger rows whose unit id is mut:<ac_id>:<n> (n is 1-based,
mapping to that record's violating_behaviors — convention set by
templates/integration-gate.md § Per-AC mutation). Per AC the table reports:
distinct mutants found, generation cost (sum cost_usd over EVERY row, retries
included), run cost (sum check_cost_usd), and share of arm total. Two
failure classes (exit 1, each named): an expected mutant with no ledger row,
and an orphan mutant row matching no record entry.
"""
import argparse, json, re, sys
from pathlib import Path

MUT = re.compile(r"^mut:(?P<ac>.+):(?P<n>\d+)$")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ledger", required=True)
    ap.add_argument("--records", required=True)
    a = ap.parse_args()
    rows = [json.loads(l) for l in Path(a.ledger).read_text().splitlines() if l.strip()]
    recs = [json.loads(p.read_text()) for p in sorted(Path(a.records).glob("*.json"))]
    arm_total = sum((r.get("cost_usd") or 0) + (r.get("check_cost_usd") or 0) for r in rows)

    plain = [r for r in rows if not MUT.match(r["unit"])]
    units = {}
    for r in plain:
        units.setdefault(r["unit"], []).append(r)
    print("## Dispatch table (per unit)\n")
    print("| unit | attempts | tier chain | cost USD | final verdict |")
    print("|---|---|---|---|---|")
    for uid, rs in units.items():
        rs.sort(key=lambda r: r["attempt"])
        chain = "→".join(r["tier"] for r in rs)
        cost = sum(r.get("cost_usd") or 0 for r in rs)
        print(f"| {uid} | {len(rs)} | {chain} | {cost:.4f} | {rs[-1]['verdict']} |")

    muts = {}
    for r in rows:
        m = MUT.match(r["unit"])
        if m:
            muts.setdefault(m.group("ac"), {}).setdefault(int(m.group("n")), []).append(r)
    failures = []
    expected = {rec["ac_id"]: len(rec.get("violating_behaviors") or [])
                for rec in recs if rec.get("no_expansion_needed") is not True}
    for ac, by_n in sorted(muts.items()):       # orphan rows are accounting corruption, not noise
        for n in sorted(by_n):
            if ac not in expected or n < 1 or n > expected[ac]:
                failures.append(f"FAIL: orphan mutant row mut:{ac}:{n} — no matching "
                                f"violating_behaviors entry in the records")
    print("\n## Per-AC mutation table\n")
    print("| AC | mutants | generation cost USD | run cost USD | share of arm total |")
    print("|---|---|---|---|---|")
    for rec in recs:
        if rec.get("no_expansion_needed") is True:
            continue
        vb = rec.get("violating_behaviors") or []
        if not vb:
            continue
        ac = rec["ac_id"]
        got = muts.get(ac, {})
        missing = [i for i in range(1, len(vb) + 1) if i not in got]
        for i in missing:
            failures.append(f"FAIL: {ac} missing mutant row mut:{ac}:{i} "
                            f"(expected {len(vb)} mutants, ledger has {len(got)})")
        rows_ac = [r for rs in got.values() for r in rs]   # retries billed too: sum EVERY row
        gen = sum(r.get("cost_usd") or 0 for r in rows_ac)
        run = sum(r.get("check_cost_usd") or 0 for r in rows_ac)
        share = (gen + run) / arm_total if arm_total else 0
        print(f"| {ac} | {len(got)}/{len(vb)} | {gen:.4f} | {run:.4f} | {share:.1%} |")
    print()
    for f in failures:
        print(f)
    if not failures:
        print(f"OK ledger complete — arm total {arm_total:.4f} USD")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
