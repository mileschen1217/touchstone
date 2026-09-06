#!/usr/bin/env python3
"""Instantiate the integration-gate work order from expansion records (DS-10).

  make_gate.py --records <dir> --out <gate.md> --scope-name <name>
               [--template <path>] [--bridges "a;b"] [--residual-units "u1;u2"]

Always produces a gate file, even when every section is empty — an empty
section renders the literal `none` (DS-10: absence and emptiness are
different states). The mutation list carries EVERY expanded AC (record with
non-empty violating_behaviors and no no_expansion_needed flag) — no
narrowing (AC-11); completeness is verified by scripts/reconcile.py leg 4.
"""
import argparse, datetime, json, sys
from pathlib import Path


def load_records(d):
    return [json.loads(p.read_text()) for p in sorted(Path(d).glob("*.json"))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--records", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--scope-name", required=True)
    ap.add_argument("--template", default=str(Path(__file__).resolve().parent.parent / "templates" / "integration-gate.md"))
    ap.add_argument("--bridges", default="")
    ap.add_argument("--residual-units", default="")
    a = ap.parse_args()
    recs = load_records(a.records)
    ac_ids = [r["ac_id"] for r in recs]

    inv_lines = []
    for r in recs:
        if r.get("residual") is True:
            body = "; ".join(r.get("invariants") or []) or "; ".join(c["case"] for c in r.get("cases", []))
            inv_lines.append(f"- [ ] {r['ac_id']}: {body or '(see expansion record)'}")
    mut_lines = []
    for r in recs:
        if r.get("no_expansion_needed") is True:
            continue
        vb = r.get("violating_behaviors") or []
        if not vb:
            continue
        muts = ", ".join(f"mut:{r['ac_id']}:{i + 1}" for i in range(len(vb)))
        mut_lines.append(f"- [ ] {r['ac_id']} — {muts}: " + " | ".join(vb))
    bridges = [f"- [ ] {b.strip()}" for b in a.bridges.split(";") if b.strip()]
    resid = [f"- {u.strip()}" for u in a.residual_units.split(";") if u.strip()]

    tmpl = Path(a.template).read_text()
    out = (tmpl.replace("{{SCOPE_NAME}}", a.scope_name)
               .replace("{{RENDERED_TS}}", datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
               .replace("{{AC_LIST}}", ", ".join(ac_ids) if ac_ids else "none")
               .replace("{{INVARIANT_CHECKS}}", "\n".join(inv_lines) or "none")
               .replace("{{BRIDGES}}", "\n".join(bridges) or "none")
               .replace("{{MUTATION_LIST}}", "\n".join(mut_lines) or "none")
               .replace("{{RESIDUAL_UNITS}}", "\n".join(resid) or "none")
               .replace("{{REPORT_SEED}}", "(pending)"))
    Path(a.out).write_text(out)
    print(f"gate written: {a.out} ({len(ac_ids)} ACs, {len(mut_lines)} mutation entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
