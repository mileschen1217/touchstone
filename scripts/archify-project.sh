#!/usr/bin/env bash
# scripts/archify-project.sh — project a spec.yaml's delta into archify architecture IR
# and (when archify is reachable) render the Before/Delta/After overlay.
#
# Usage: archify-project.sh <spec.yaml> <out-dir> [--as-is <ids-file>] [--archify <archify.mjs>]
#   writes <out-dir>/base.json (as-is blocks) and <out-dir>/head.json (as-is ⊕ delta);
#   with archify reachable (`--archify`, $ARCHIFY, or `archify` on PATH) also runs
#   `archify validate` on both and `archify compare architecture` →
#   <out-dir>/structure-overlay.html (the dossier inlines it on the Ship tab).
#   exit 0 → files written; exit 1 → spec unreadable / archify failed; exit 3 → archify absent
#            (base/head still written — the dossier falls back to its delta tables).
# The as-is block list is a trial input: default = the spec's delta blocks with op
# change|remove; --as-is <file> overrides it with one `id|kind|label` per line.
set -uo pipefail
spec="${1:-}"; out="${2:-}"; shift 2 2>/dev/null || { echo "usage: archify-project.sh <spec.yaml> <out-dir> [--as-is <file>] [--archify <archify.mjs>]" >&2; exit 1; }
asis=""; arch="${ARCHIFY:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --as-is) asis="$2"; shift 2 ;;
    --archify) arch="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done
[ -f "$spec" ] || { echo "archify-project.sh: no such spec: $spec" >&2; exit 1; }
mkdir -p "$out" || exit 1
python3 - "$spec" "$out" "$asis" <<'PY' || exit 1
import sys, os, json, yaml
spec, out, asis = sys.argv[1], sys.argv[2], sys.argv[3]
d = yaml.safe_load(open(spec, encoding='utf-8'))
delta = d.get('delta') or {}
blocks = [b for b in delta.get('blocks') or [] if isinstance(b, dict)]
edges = [e for e in delta.get('edges') or [] if isinstance(e, dict)]
KIND = {'component': 'backend', 'skill': 'frontend', 'fragment': 'messagebus', 'agent': 'external', 'command': 'frontend', 'schema': 'security', 'doc': 'cloud'}
if asis:
    base_blocks = []
    for line in open(asis, encoding='utf-8'):
        line = line.strip()
        if not line or line.startswith('#'): continue
        parts = line.split('|')
        base_blocks.append({'id': parts[0], 'kind': parts[1] if len(parts) > 1 else 'component', 'purpose': parts[2] if len(parts) > 2 else ''})
else:
    base_blocks = [b for b in blocks if b.get('op') in ('change', 'remove')]
head_blocks = [b for b in base_blocks if not any(x.get('id') == b.get('id') and x.get('op') == 'remove' for x in blocks)]
head_blocks += [b for b in blocks if b.get('op') == 'add']
# changed blocks carry the delta purpose in head
purpose_head = {b['id']: b for b in blocks if b.get('op') == 'change'}
def layered(bl, conns):
    """Layer by dependency depth (sources on top); one row per layer, wide spacing → edges never cross a node."""
    ids = [str(b['id']) for b in bl]
    outs = {i: [c['to'] for c in conns if c['from'] == i] for i in ids}
    depth = {}
    def dep(i, seen=()):
        if i in depth: return depth[i]
        if i in seen: return 0
        depth[i] = 1 + max([dep(t, seen + (i,)) for t in outs.get(i, []) if t in ids] or [-1])
        return depth[i]
    for i in ids: dep(i)
    rows = {}
    for i in ids: rows.setdefault(depth[i], []).append(i)
    pos = {}
    for r, (dv, members) in enumerate(sorted(rows.items(), key=lambda kv: -kv[0])):
        for c, i in enumerate(members): pos[i] = [60 + c * 260, 60 + r * 160]
    return pos
def comp(b, pos, changed=False):
    c = {'id': str(b['id']), 'type': KIND.get(str(b.get('kind')), 'backend'), 'label': str(b['id']),
         'pos': pos[str(b['id'])], 'size': [200, 60]}
    if changed: c['tag'] = 'changed'
    return c
def doc(title, bl, conns):
    pos = layered(bl, conns)
    return {'schema_version': 1, 'diagram_type': 'architecture',
            'meta': {'title': str(d.get('title', 'spec')), 'subtitle': title},
            'components': [comp(b, pos, changed=(title == 'after' and b['id'] in purpose_head)) for b in bl],
            'connections': [{'id': f"e-{c['from']}-to-{c['to']}", 'from': c['from'], 'to': c['to'], 'fromSide': 'bottom', 'toSide': 'top'} for c in conns]}
ids_base = {b['id'] for b in base_blocks}; ids_head = {b['id'] for b in head_blocks}
base_conns = [{'from': e['from'], 'to': e['to']} for e in edges
              if e.get('op') in ('remove', 'change') and e['from'] in ids_base and e['to'] in ids_base]
head_conns = [{'from': e['from'], 'to': e['to']} for e in edges
              if e.get('op') in ('add', 'change') and e['from'] in ids_head and e['to'] in ids_head]
json.dump(doc('before', base_blocks, base_conns), open(os.path.join(out, 'base.json'), 'w'), indent=1)
json.dump(doc('after', head_blocks, head_conns), open(os.path.join(out, 'head.json'), 'w'), indent=1)
print(f"base.json: {len(base_blocks)} blocks / {len(base_conns)} edges; head.json: {len(head_blocks)} blocks / {len(head_conns)} edges")
PY
if [ -z "$arch" ]; then command -v archify >/dev/null 2>&1 && arch="archify"; fi
[ -n "$arch" ] || { echo "archify not reachable — base/head written; dossier falls back to delta tables"; exit 3; }
run() { case "$arch" in *.mjs) node "$arch" "$@" ;; *) "$arch" "$@" ;; esac; }
run validate architecture "$out/base.json" || { echo "archify: base.json invalid" >&2; exit 1; }
run validate architecture "$out/head.json" || { echo "archify: head.json invalid" >&2; exit 1; }
run compare architecture "$out/base.json" "$out/head.json" "$out/structure-overlay.html" --receipt "$out/structure-overlay.receipt.json" || { echo "archify: compare failed" >&2; exit 1; }
echo "$out/structure-overlay.html"
