#!/usr/bin/env python3
"""Mechanical bidirectional trace check over the expansion layer — four legs
(REQ-3, DS-7). Zero model calls; exit 0 only when every leg is green.

  reconcile.py --records <dir> --spec <governing-spec> --work-orders <file|dir> [...]
               --gate <gate.md> [--tests-root <dir>]

Leg 1  every expansion case's test node exists: `path::node` — the file exists
       under --tests-root (default .) and defines the node (def/class).
Leg 2  every work-order trace id exists in the expansion records; a work order
       with NO `_Requirements:` trace line at all is itself a failure (AC-6).
Leg 3  expansion internals: every partition/boundary/negative is referenced by
       a case (its text appears verbatim, case-insensitively and with
       non-word boundaries on both sides, inside some cases[].case — verbatim
       reference IS the mechanical contract; paraphrase does not count) or is
       explicitly waived (covered_by waives the record's items;
       negatives_covered_by waives negatives); and every ac_id exists in the
       governing spec — as a yaml/json `id:` entry, or as a markdown heading
       whose title LEADS with the ac_id (`## AC-5 ...`; prose mentions don't count).
Leg 4  gate completeness: every expanded AC (violating_behaviors non-empty,
       not no_expansion_needed) appears in the gate's `## Per-AC mutation`
       section WITH every expected mutant token mut:<ac_id>:<n> — naming the
       AC alone does not discharge the duty; consumed by AC-11; no narrowing
       to load-bearing-only ACs. HTML comments are stripped before matching.
"""
import argparse, json, re, sys
from pathlib import Path

TRACE = re.compile(r"^_Requirements:\s*(.+)$", re.M)
AC_TOKEN = re.compile(r"\b[A-Za-z]+-\d+\b")


def item_referenced(blob, item):
    """Verbatim containment with non-word boundaries: 'n < 1' does NOT match
    inside 'n < 10' (bare-substring false greens are the failure this guards)."""
    pat = r"(?<![0-9A-Za-z_])" + re.escape(item.lower()) + r"(?![0-9A-Za-z_])"
    return re.search(pat, blob) is not None


def section(text, heading):
    m = re.search(rf"^##\s+{re.escape(heading)}\s*$(.*?)(?=^##\s|\Z)", text, re.M | re.S)
    return m.group(1) if m else ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--records", required=True)
    ap.add_argument("--spec", required=True)
    ap.add_argument("--work-orders", nargs="+", required=True)
    ap.add_argument("--gate", required=True)
    ap.add_argument("--tests-root", default=".")
    a = ap.parse_args()
    recs = [(p, json.loads(p.read_text())) for p in sorted(Path(a.records).glob("*.json"))]
    spec_text = Path(a.spec).read_text()
    known_acs = {r["ac_id"] for _, r in recs}
    fails = []

    # Leg 1 — case -> existing test node
    for p, r in recs:
        for c in r.get("cases", []):
            t = c.get("test", "")
            if "::" not in t:
                fails.append(f"leg1: {r['ac_id']} case {c.get('case')!r} test {t!r} is not path::node")
                continue
            fpath, node = t.split("::", 1)
            parts = [re.sub(r"\[.*\]$", "", x) for x in node.split("::")]
            f = Path(a.tests_root) / fpath
            if not f.exists():
                fails.append(f"leg1: {r['ac_id']} case {c['case']!r} test file {fpath} not found")
            else:
                src = f.read_text()
                for part in parts:   # every path component must be defined, not just the leaf
                    if not re.search(rf"^\s*(async\s+def|def|class)\s+{re.escape(part)}\b", src, re.M):
                        fails.append(f"leg1: {r['ac_id']} case {c['case']!r} test node {part} not defined in {fpath}")

    # Leg 2 — work-order trace -> expansion record
    wo_files = []
    for w in a.work_orders:
        p = Path(w)
        wo_files += sorted(p.glob("*.md")) if p.is_dir() else [p]
    for w in wo_files:
        traces = TRACE.findall(w.read_text())
        if not traces:
            fails.append(f"leg2: work order {w} lacks its _Requirements: trace line")
            continue
        for line in traces:
            for ac in AC_TOKEN.findall(line):
                if ac not in known_acs:
                    fails.append(f"leg2: work order {w} traces {ac} — no expansion record")

    # Leg 3 — internals: item referenced-or-waived; ac_id present in spec
    for p, r in recs:
        ac = r["ac_id"]
        id_form = rf"[\s{{'\"]id['\"]?\s*:\s*['\"]?{re.escape(ac)}['\"]?\b"
        heading_form = rf"^#{{1,6}}\s+{re.escape(ac)}(?![0-9A-Za-z_])"   # markdown governing specs title their ACs: id leads the heading
        if not (re.search(id_form, spec_text) or re.search(heading_form, spec_text, re.M)):
            fails.append(f"leg3: {ac} ({p.name}) not present in governing spec {a.spec}")
        case_blob = " || ".join(c.get("case", "") for c in r.get("cases", [])).lower()
        waived_all = bool(r.get("covered_by"))
        for arr, extra_waiver in (("partitions", False), ("boundaries", False), ("negatives", True)):
            waived = waived_all or (extra_waiver and bool(r.get("negatives_covered_by")))
            if waived:
                continue
            for item in r.get(arr, []):
                if not item_referenced(case_blob, item):
                    fails.append(f"leg3: {ac} {arr} item {item!r} referenced by no case and no waiver")

    # Leg 4 — gate mutation-list completeness
    gate_text = Path(a.gate).read_text()
    # comments stripped first: the gate TEMPLATE's own comment names AC ids and
    # would satisfy the search for every generated gate (vacuous-pass hazard)
    mut_section = re.sub(r"<!--.*?-->", "", section(gate_text, "Per-AC mutation"), flags=re.S)
    for p, r in recs:
        if r.get("no_expansion_needed") is True or not r.get("violating_behaviors"):
            continue
        if not re.search(rf"\b{re.escape(r['ac_id'])}\b", mut_section):
            fails.append(f"leg4: gate {a.gate} mutation list omits expanded AC {r['ac_id']} — incomplete")
            continue
        for i in range(1, len(r["violating_behaviors"]) + 1):   # naming the AC is not the duty; every mutant is
            tok = f"mut:{r['ac_id']}:{i}"
            if tok not in mut_section:
                fails.append(f"leg4: gate {a.gate} mutation list missing mutant token {tok}")

    for f in fails:
        print(f"FAIL {f}")
    if not fails:
        print(f"OK all four legs green ({len(recs)} records, {len(wo_files)} work orders)")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
