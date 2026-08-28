#!/usr/bin/env bash
# scripts/check-artifact.sh — validate a YAML stage artifact against its schema.
#
# Usage: check-artifact.sh <spec|review|deviation> <file> [--root <dir>]
#   exit 0 → valid (warnings, prefixed `warn:`, never change the exit code)
#   exit 1 → one line per violation: `<field-path>: <rule>`
#   exit 2 → usage / missing dependency (PyYAML: `pip install pyyaml`)
#
# Schemas: skills/_shared/schemas/<kind>.schema.yaml (single home of every field set and
# id family; the keyword legend is in spec.schema.yaml's header). Checks: required keys,
# enums, unknown keys, id uniqueness per family, in-file references (traces_to, edges),
# ledger references (basis / why_ref / consensus / rulings — an id resolves iff the ledger
# has a line starting `- <id>` or `| <id>`), field-path grammar on review findings and
# quiz anchors (resolved in the target spec when --root is given), path-free phase_map,
# degraded_reason when degraded, quiz answers naming a field id.
# --root <dir>: directory the ledger (spec `facts_source.record`) and a review's `target`
# resolve against; default = the artifact's own directory.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
kind="${1:-}"; file="${2:-}"; root=""
[ "${3:-}" = "--root" ] && root="${4:-}"
case "$kind" in spec|review|deviation) ;; *) echo "usage: check-artifact.sh <spec|review|deviation> <file> [--root <dir>]" >&2; exit 2 ;; esac
[ -f "$file" ] || { echo "check-artifact.sh: no such file: $file" >&2; exit 2; }
schema="$here/../skills/_shared/schemas/$kind.schema.yaml"
[ -f "$schema" ] || { echo "check-artifact.sh: schema missing: $schema" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "check-artifact.sh: python3 not found" >&2; exit 2; }
python3 -c 'import yaml' 2>/dev/null || { echo "check-artifact.sh: PyYAML not installed — run: python3 -m pip install pyyaml" >&2; exit 2; }

python3 - "$kind" "$file" "$schema" "$root" <<'PY'
import sys, os, re, yaml, datetime

kind, path, schema_path, root = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
root = os.path.abspath(root) if root else os.path.dirname(os.path.abspath(path))
schema = yaml.safe_load(open(schema_path, encoding='utf-8'))
try:
    doc = yaml.safe_load(open(path, encoding='utf-8'))
except yaml.YAMLError as e:
    print(f"(file): not parseable YAML — {e}"); sys.exit(1)
if not isinstance(doc, dict):
    print("(file): top level must be a mapping"); sys.exit(1)

errors, warns = [], []
ids = {}        # family -> {id: path}
refs = []       # (path, family, value)
ledger_refs = []  # (path, value)
field_paths = []  # (path, value)

def type_ok(v, t):
    return {'string': lambda: isinstance(v, (str, datetime.date)), 'integer': lambda: isinstance(v, int) and not isinstance(v, bool),
            'boolean': lambda: isinstance(v, bool), 'array': lambda: isinstance(v, list),
            'object': lambda: isinstance(v, dict)}.get(t, lambda: True)()

def walk(v, s, p):
    if 'oneOf' in s:
        for alt in s['oneOf']:
            n = len(errors); walk(v, alt, p)
            if len(errors) == n: return
            del errors[n:]
        errors.append(f"{p}: matches none of the allowed forms"); return
    t = s.get('type')
    if t and not type_ok(v, t):
        errors.append(f"{p}: expected {t}"); return
    if 'enum' in s and v not in s['enum']:
        errors.append(f"{p}: '{v}' not in {s['enum']}")
    fam = s.get('id')
    if fam and isinstance(v, str):
        if fam in ('US', 'REQ', 'AC', 'INV', 'F', 'D', 'QZ') and not re.fullmatch(fam + r'-\d+', v):
            errors.append(f"{p}: id must be {fam}-<n>")
        if v in ids.setdefault(fam, {}):
            errors.append(f"{p}: duplicate id {v} (first at {ids[fam][v]})")
        else:
            ids[fam][v] = p
    if s.get('ref'):
        for x in (v if isinstance(v, list) else [v]): refs.append((p, s['ref'], x))
    if s.get('ledger_ref'):
        for x in (v if isinstance(v, list) else [v]): ledger_refs.append((p, x))
    if s.get('field_path') and isinstance(v, str): field_paths.append((p, v))
    if s.get('path_free') and isinstance(v, str):
        m = re.search(r'\S+/\S+|\b\w+\.(md|sh|yaml|yml|json|py|js|html|txt|jsonl)\b', v)
        if m: errors.append(f"{p}: human-facing panel carries a path-like token '{m.group(0)}'")
    if t == 'object':
        props = s.get('properties', {})
        for k in s.get('required', []):
            if k not in v: errors.append(f"{p + '.' if p else ''}{k}: required")
        for k, x in v.items():
            if k in props: walk(x, props[k], f"{p}.{k}" if p else k)
            elif s.get('additionalProperties') is False: errors.append(f"{p + '.' if p else ''}{k}: unknown key")
    elif t == 'array' and 'items' in s:
        it = s['items']
        for i, x in enumerate(v):
            sel = x.get('id') if isinstance(x, dict) and isinstance(x.get('id'), str) else str(i)
            walk(x, it, f"{p}[{sel}]")

walk(doc, schema, '')

for p, fam, x in refs:
    if x not in ids.get(fam, {}): errors.append(f"{p}: '{x}' names no {fam} id defined in this file")

# ---- field-path grammar + resolution
PATH_RE = re.compile(r'^[A-Za-z_]\w*(\[[^\]]+\])?(\.[A-Za-z_]\w*(\[[^\]]+\])?)*$')
def resolve(node, fp):
    """Return True iff fp addresses something in node."""
    for seg in re.findall(r'([A-Za-z_]\w*)(?:\[([^\]]+)\])?', fp):
        key, sel = seg
        if not isinstance(node, dict) or key not in node: return False
        node = node[key]
        if sel:
            if not isinstance(node, list): return False
            if sel == '*': node = node[0] if node else None; continue
            if sel.isdigit():
                if int(sel) >= len(node): return False
                node = node[int(sel)]; continue
            hit = [e for e in node if isinstance(e, dict) and e.get('id') == sel]
            if not hit: return False
            node = hit[0]
    return True

target_doc = None
if kind == 'review':
    tp = os.path.join(root, doc.get('target', '') or '')
    if os.path.isfile(tp):
        try: target_doc = yaml.safe_load(open(tp, encoding='utf-8'))
        except yaml.YAMLError: target_doc = None
for p, fp in field_paths:
    if not PATH_RE.match(fp): errors.append(f"{p}: '{fp}' does not parse as a field path"); continue
    if kind == 'review' and target_doc is not None and not resolve(target_doc, fp):
        errors.append(f"{p}: '{fp}' resolves to nothing in the target spec")
    elif kind == 'review' and target_doc is None:
        warns.append(f"{p}: target spec not found under --root; field path unresolved")

# ---- ledger resolution
ledger = None
if kind == 'spec':
    rec = (doc.get('facts_source') or {}).get('record') if isinstance(doc.get('facts_source'), dict) else None
    if rec: ledger = os.path.join(root, rec)
elif kind == 'review' and isinstance(target_doc, dict):
    rec = (target_doc.get('facts_source') or {}).get('record')
    if rec: ledger = os.path.join(root, rec)
if ledger_refs:
    if ledger and os.path.isfile(ledger):
        lines = open(ledger, encoding='utf-8').read().splitlines()
        def resolves(i): return any(l.startswith(f"- {i}") and not l[len(i)+2:len(i)+3].isdigit()
                                    or l.startswith(f"| {i}") and not l[len(i)+2:len(i)+3].isdigit() for l in lines)
        for p, x in ledger_refs:
            if not resolves(str(x)): errors.append(f"{p}: '{x}' resolves to no ledger line ('- {x}' / '| {x}') in {os.path.basename(ledger)}")
    else:
        warns.append(f"ledger not found ({ledger or 'no facts_source.record'}); {len(ledger_refs)} ledger reference(s) unresolved")

# ---- per-kind rules
if kind == 'spec':
    for r in doc.get('requirements') or []:
        if not isinstance(r, dict): continue
        for a in r.get('acs') or []:
            if not isinstance(a, dict): continue
            then = str(a.get('then', ''))
            stripped = re.sub(r'\b[A-Z]+-\d+\b|\bexit \d+\b', '', then)
            if re.search(r'\b\d+\b', stripped) and not a.get('basis'):
                warns.append(f"requirements[{r.get('id')}].acs[{a.get('id')}].then: numeric literal with no basis — reviewer decides")
elif kind == 'review':
    if doc.get('degraded') is True and not doc.get('degraded_reason'):
        errors.append("degraded_reason: required when degraded is true")
elif kind == 'deviation':
    q = doc.get('quiz') or {}
    for it in (q.get('items') or []) if isinstance(q, dict) else []:
        if isinstance(it, dict) and not re.search(r'\b(US|REQ|AC|INV|F|D|QZ)-\d+\b|\w+\[[^\]]+\]', str(it.get('answer', ''))):
            errors.append(f"quiz.items[{it.get('id')}].answer: names no field id")

for w in warns: print(f"warn: {w}")
for e in errors: print(e)
sys.exit(1 if errors else 0)
PY
